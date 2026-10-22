import Foundation

protocol ContinuousContextRollingEvent: Sendable {
    var snapshotID: UInt64 { get }
    var sampleRange: Range<Int64> { get }
    var capturedAt: TimeInterval { get }
    var candidateAt: TimeInterval { get }
    var text: String { get }
    var isStale: Bool { get }
    var isFinal: Bool { get }
}

extension RollingWhisperHypothesis: ContinuousContextRollingEvent {
    var isFinal: Bool { false }
}

enum ContinuousContextSessionState: Equatable, Sendable {
    case idle
    case capturing
    case finalizing
    case committed
    case cancelled
    case failed

    fileprivate func canTransition(to next: Self) -> Bool {
        switch (self, next) {
        case (.idle, .capturing),
             (.capturing, .finalizing),
             (.capturing, .cancelled),
             (.capturing, .failed),
             (.finalizing, .committed),
             (.finalizing, .cancelled),
             (.finalizing, .failed):
            true
        default:
            false
        }
    }
}

enum ContinuousContextRevisionKind: Equatable, Sendable {
    case provisional
    case final
}

struct ContinuousContextGenerationIDs: Equatable, Sendable {
    let session: UInt64
    let work: UInt64
}

struct ContinuousContextRevision: Equatable, Sendable {
    let attemptID: UUID
    let revision: UInt64
    let snapshotID: UInt64
    let sampleRange: Range<Int64>
    let sourceText: String
    let language: String
    let kind: ContinuousContextRevisionKind
    let generationIDs: ContinuousContextGenerationIDs
    let capturedAt: TimeInterval
    let candidateAt: TimeInterval
    let emittedAt: TimeInterval
    let stablePrefixCharacterCount: Int
    let mutableSourceCharacterRange: Range<Int>
    let mutableSuffix: String
}

struct ContinuousContextWork: Equatable, Sendable {
    let id: UInt64
    let attemptID: UUID
    let revision: UInt64
    let snapshotID: UInt64
    let sourceText: String
    let mutableSuffix: String
    let stablePrefixCharacterCount: Int
    let generationIDs: ContinuousContextGenerationIDs
    let expiresAt: TimeInterval
}

struct ContinuousContextFinalCandidate: Equatable, Sendable {
    let attemptID: UUID
    let revision: UInt64
    let sourceText: String
    let language: String
    let generationIDs: ContinuousContextGenerationIDs
}

final class ContinuousContextSession: @unchecked Sendable {
    struct Configuration: Equatable, Sendable {
        static let standard = Configuration()

        let maximumContextAge: TimeInterval
        let maximumContextCharacters: Int
        let maximumWorkAge: TimeInterval
        let sampleRate: Int

        init(
            maximumContextAge: TimeInterval = 30,
            maximumContextCharacters: Int = 600,
            maximumWorkAge: TimeInterval = 0.2,
            sampleRate: Int = 16_000
        ) {
            precondition(maximumContextAge > 0 && maximumContextAge <= 30)
            precondition(maximumContextCharacters > 0 && maximumContextCharacters <= 600)
            precondition(maximumWorkAge > 0 && maximumWorkAge <= 0.2)
            precondition(sampleRate > 0)
            self.maximumContextAge = maximumContextAge
            self.maximumContextCharacters = maximumContextCharacters
            self.maximumWorkAge = maximumWorkAge
            self.sampleRate = sampleRate
        }

        var maximumRetainedSamples: Int {
            Int(maximumContextAge * Double(sampleRate))
        }
    }

    private struct Storage {
        var state: ContinuousContextSessionState = .idle
        var attemptID: UUID?
        var language = ""
        var sessionGeneration: UInt64 = 0
        var workGeneration: UInt64 = 0
        var nextRevision: UInt64 = 1
        var nextWorkID: UInt64 = 1
        var lastSnapshotID: UInt64 = 0
        var lastSampleUpperBound: Int64 = 0
        var lastSourceText = ""
        var latestRevision: ContinuousContextRevision?
        var retainedContext = ""
        var retainedAudio: [Float] = []
        var retainedAudioRange: Range<Int64>?
        var activeWork: ContinuousContextWork?
        var pendingWork: ContinuousContextWork?
        var finalCandidate: ContinuousContextFinalCandidate?
    }

    private let configuration: Configuration
    private let now: @Sendable () -> TimeInterval
    private let lock = NSLock()
    private var storage = Storage()

    init(
        configuration: Configuration = .standard,
        now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.configuration = configuration
        self.now = now
    }

    @discardableResult
    func start(attemptID: UUID, language: String) -> Bool {
        lock.withLock {
            guard storage.state.canTransition(to: .capturing) else { return false }
            storage = Storage()
            storage.state = .capturing
            storage.attemptID = attemptID
            storage.language = language
            storage.sessionGeneration = 1
            return true
        }
    }

    @discardableResult
    func ingest(_ event: some ContinuousContextRollingEvent) -> ContinuousContextRevision? {
        lock.withLock {
            guard storage.state == .capturing,
                  !event.isStale,
                  !event.text.isEmpty,
                  event.snapshotID > storage.lastSnapshotID,
                  event.sampleRange.lowerBound >= 0,
                  event.sampleRange.upperBound > storage.lastSampleUpperBound,
                  event.capturedAt.isFinite,
                  event.candidateAt.isFinite,
                  event.candidateAt >= event.capturedAt,
                  let attemptID = storage.attemptID else { return nil }

            storage.lastSnapshotID = event.snapshotID
            storage.lastSampleUpperBound = event.sampleRange.upperBound
            guard event.isFinal || event.text != storage.lastSourceText else { return nil }

            let stableCount = Self.commonPrefixCharacterCount(storage.lastSourceText, event.text)
            let mutableSuffix = Self.suffix(event.text, droppingCharacters: stableCount)
            let generations = ContinuousContextGenerationIDs(
                session: storage.sessionGeneration,
                work: storage.workGeneration &+ 1
            )
            storage.workGeneration = generations.work
            let revision = ContinuousContextRevision(
                attemptID: attemptID,
                revision: storage.nextRevision,
                snapshotID: event.snapshotID,
                sampleRange: event.sampleRange,
                sourceText: event.text,
                language: storage.language,
                kind: event.isFinal ? .final : .provisional,
                generationIDs: generations,
                capturedAt: event.capturedAt,
                candidateAt: event.candidateAt,
                emittedAt: now(),
                stablePrefixCharacterCount: stableCount,
                mutableSourceCharacterRange: stableCount..<event.text.count,
                mutableSuffix: mutableSuffix
            )
            storage.nextRevision &+= 1
            storage.lastSourceText = event.text
            storage.latestRevision = revision
            storage.retainedContext = String(event.text.suffix(configuration.maximumContextCharacters))

            if event.isFinal {
                guard storage.state.canTransition(to: .finalizing) else { return nil }
                storage.state = .finalizing
                storage.finalCandidate = ContinuousContextFinalCandidate(
                    attemptID: attemptID,
                    revision: revision.revision,
                    sourceText: event.text,
                    language: storage.language,
                    generationIDs: generations
                )
                invalidateWorkAndBuffers(keepingFinalCandidate: true)
            } else {
                storage.pendingWork = ContinuousContextWork(
                    id: storage.nextWorkID,
                    attemptID: attemptID,
                    revision: revision.revision,
                    snapshotID: revision.snapshotID,
                    sourceText: revision.sourceText,
                    mutableSuffix: revision.mutableSuffix,
                    stablePrefixCharacterCount: revision.stablePrefixCharacterCount,
                    generationIDs: generations,
                    expiresAt: revision.emittedAt + configuration.maximumWorkAge
                )
                storage.nextWorkID &+= 1
            }
            return revision
        }
    }

    func retainAudio(_ snapshot: AudioSampleSnapshot) {
        lock.withLock {
            guard storage.state == .capturing,
                  snapshot.sampleRange.lowerBound >= 0,
                  snapshot.sampleRange.count == snapshot.samples.count,
                  snapshot.sampleRange.upperBound >= (storage.retainedAudioRange?.upperBound ?? 0) else { return }
            let maximum = configuration.maximumRetainedSamples
            storage.retainedAudio = Array(snapshot.samples.suffix(maximum))
            let retainedStart = snapshot.sampleRange.upperBound - Int64(storage.retainedAudio.count)
            storage.retainedAudioRange = retainedStart..<snapshot.sampleRange.upperBound
        }
    }

    func takeNextWork() -> ContinuousContextWork? {
        lock.withLock {
            guard storage.state == .capturing, storage.activeWork == nil else { return nil }
            storage.activeWork = storage.pendingWork
            storage.pendingWork = nil
            return storage.activeWork
        }
    }

    @discardableResult
    func completeWork(_ work: ContinuousContextWork) -> Bool {
        lock.withLock {
            guard storage.state == .capturing,
                  storage.activeWork?.id == work.id else { return false }
            storage.activeWork = nil
            return work.attemptID == storage.attemptID
                && work.generationIDs.session == storage.sessionGeneration
                && work.revision == storage.latestRevision?.revision
                && now() < work.expiresAt
        }
    }

    func commitFinalCandidate() -> ContinuousContextFinalCandidate? {
        lock.withLock {
            guard storage.state.canTransition(to: .committed),
                  let candidate = storage.finalCandidate else { return nil }
            storage.state = .committed
            clearSensitiveState()
            return candidate
        }
    }

    func cancel() {
        terminate(as: .cancelled)
    }

    func fail() {
        terminate(as: .failed)
    }

    var state: ContinuousContextSessionState { lock.withLock { storage.state } }
    var latestRevision: ContinuousContextRevision? { lock.withLock { storage.latestRevision } }
    var finalCandidate: ContinuousContextFinalCandidate? { lock.withLock { storage.finalCandidate } }
    var retainedContext: String { lock.withLock { storage.retainedContext } }
    var retainedContextCharacterCount: Int { lock.withLock { storage.retainedContext.count } }
    var retainedAudioSampleCount: Int { lock.withLock { storage.retainedAudio.count } }
    var scheduledWorkCount: Int {
        lock.withLock { (storage.activeWork == nil ? 0 : 1) + (storage.pendingWork == nil ? 0 : 1) }
    }

    private func terminate(as terminal: ContinuousContextSessionState) {
        lock.withLock {
            guard storage.state.canTransition(to: terminal) else { return }
            storage.state = terminal
            clearSensitiveState()
        }
    }

    private func invalidateWorkAndBuffers(keepingFinalCandidate: Bool) {
        storage.sessionGeneration &+= 1
        storage.activeWork = nil
        storage.pendingWork = nil
        storage.retainedAudio.removeAll(keepingCapacity: false)
        storage.retainedAudioRange = nil
        storage.retainedContext = ""
        if !keepingFinalCandidate { storage.finalCandidate = nil }
    }

    private func clearSensitiveState() {
        invalidateWorkAndBuffers(keepingFinalCandidate: false)
        storage.lastSourceText = ""
        storage.latestRevision = nil
        storage.attemptID = nil
        storage.language = ""
    }

    private static func commonPrefixCharacterCount(_ lhs: String, _ rhs: String) -> Int {
        zip(lhs, rhs).prefix(while: ==).count
    }

    private static func suffix(_ value: String, droppingCharacters count: Int) -> String {
        let index = value.index(value.startIndex, offsetBy: min(count, value.count))
        return String(value[index...])
    }
}
