import Foundation

protocol ContinuousContextRollingEvent: Sendable {
    var snapshotID: UInt64 { get }
    var sampleRange: Range<Int64> { get }
    var capturedAt: TimeInterval { get }
    var candidateAt: TimeInterval { get }
    var text: String { get }
    var tokenEvidence: [WhisperTokenEvidence] { get }
    var isStale: Bool { get }
}

extension ContinuousContextRollingEvent {
    var tokenEvidence: [WhisperTokenEvidence] { [] }
}

extension RollingWhisperHypothesis: ContinuousContextRollingEvent {}

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
    let tokenEvidence: [WhisperTokenEvidence]

    init(
        attemptID: UUID,
        revision: UInt64,
        snapshotID: UInt64,
        sampleRange: Range<Int64>,
        sourceText: String,
        language: String,
        kind: ContinuousContextRevisionKind,
        generationIDs: ContinuousContextGenerationIDs,
        capturedAt: TimeInterval,
        candidateAt: TimeInterval,
        emittedAt: TimeInterval,
        stablePrefixCharacterCount: Int,
        mutableSourceCharacterRange: Range<Int>,
        mutableSuffix: String,
        tokenEvidence: [WhisperTokenEvidence] = []
    ) {
        self.attemptID = attemptID
        self.revision = revision
        self.snapshotID = snapshotID
        self.sampleRange = sampleRange
        self.sourceText = sourceText
        self.language = language
        self.kind = kind
        self.generationIDs = generationIDs
        self.capturedAt = capturedAt
        self.candidateAt = candidateAt
        self.emittedAt = emittedAt
        self.stablePrefixCharacterCount = stablePrefixCharacterCount
        self.mutableSourceCharacterRange = mutableSourceCharacterRange
        self.mutableSuffix = mutableSuffix
        self.tokenEvidence = tokenEvidence
    }
}

struct ContinuousContextWork: Equatable, Sendable {
    let id: UInt64
    let attemptID: UUID
    let revision: UInt64
    let snapshotID: UInt64
    let sampleRange: Range<Int64>
    let sourceText: String
    let language: String
    let mutableSuffix: String
    let stablePrefixCharacterCount: Int
    let mutableSourceCharacterRange: Range<Int>
    let generationIDs: ContinuousContextGenerationIDs
    let eligibleAt: TimeInterval
    let expiresAt: TimeInterval
    let tokenEvidence: [WhisperTokenEvidence]

    init(
        id: UInt64,
        attemptID: UUID,
        revision: UInt64,
        snapshotID: UInt64,
        sampleRange: Range<Int64>,
        sourceText: String,
        language: String,
        mutableSuffix: String,
        stablePrefixCharacterCount: Int,
        mutableSourceCharacterRange: Range<Int>,
        generationIDs: ContinuousContextGenerationIDs,
        eligibleAt: TimeInterval,
        expiresAt: TimeInterval,
        tokenEvidence: [WhisperTokenEvidence] = []
    ) {
        self.id = id
        self.attemptID = attemptID
        self.revision = revision
        self.snapshotID = snapshotID
        self.sampleRange = sampleRange
        self.sourceText = sourceText
        self.language = language
        self.mutableSuffix = mutableSuffix
        self.stablePrefixCharacterCount = stablePrefixCharacterCount
        self.mutableSourceCharacterRange = mutableSourceCharacterRange
        self.generationIDs = generationIDs
        self.eligibleAt = eligibleAt
        self.expiresAt = expiresAt
        self.tokenEvidence = tokenEvidence
    }
}

struct ContinuousContextFinalCandidate: Equatable, Sendable {
    let attemptID: UUID
    let revision: UInt64
    let sourceText: String
    let language: String
    let generationIDs: ContinuousContextGenerationIDs
}

enum ContinuousContextApplication: Equatable, Sendable {
    case direct(String)
    case rebased(String)
}

final class ContinuousContextSession: @unchecked Sendable {
    struct Configuration: Equatable, Sendable {
        static let standard = Configuration()

        let maximumContextAge: TimeInterval
        let maximumContextCharacters: Int
        let maximumWorkAge: TimeInterval
        let minimumWorkInterval: TimeInterval
        let sampleRate: Int

        init(
            maximumContextAge: TimeInterval = 30,
            maximumContextCharacters: Int = 600,
            maximumWorkAge: TimeInterval = 0.2,
            minimumWorkInterval: TimeInterval = 0.5,
            sampleRate: Int = 16_000
        ) {
            precondition(maximumContextAge > 0 && maximumContextAge <= 30)
            precondition(maximumContextCharacters > 0 && maximumContextCharacters <= 600)
            precondition(maximumWorkAge > 0 && maximumWorkAge <= 0.2)
            precondition(minimumWorkInterval >= 0.5)
            precondition(sampleRate > 0)
            self.maximumContextAge = maximumContextAge
            self.maximumContextCharacters = maximumContextCharacters
            self.maximumWorkAge = maximumWorkAge
            self.minimumWorkInterval = minimumWorkInterval
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
        var lastSampleRange: Range<Int64>?
        var lastSourceText = ""
        var latestRevision: ContinuousContextRevision?
        var retainedContext = ""
        var retainedAudio: [Float] = []
        var retainedAudioRange: Range<Int64>?
        var activeWork: ContinuousContextWork?
        var activeWorkCancellation: (@Sendable () -> Void)?
        var pendingWork: ContinuousContextWork?
        var lastWorkDispatchedAt: TimeInterval?
        var contextualPreviewText: String?
        var finalCandidate: ContinuousContextFinalCandidate?
        var proactiveSignature: ProactiveCandidateSignature?
        var proactiveSignatureCount = 0
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
        ingest(event, kind: .provisional, finalAttemptID: nil)
    }

    @discardableResult
    func finalize(
        _ event: some ContinuousContextRollingEvent,
        attemptID: UUID
    ) -> ContinuousContextRevision? {
        ingest(event, kind: .final, finalAttemptID: attemptID)
    }

    private func ingest(
        _ event: some ContinuousContextRollingEvent,
        kind: ContinuousContextRevisionKind,
        finalAttemptID: UUID?
    ) -> ContinuousContextRevision? {
        var cancellation: (@Sendable () -> Void)?
        let revision: ContinuousContextRevision? = lock.withLock {
            guard storage.state == .capturing,
                  !event.isStale,
                  !event.text.isEmpty,
                  event.sampleRange.lowerBound >= 0,
                  event.capturedAt.isFinite,
                  event.candidateAt.isFinite,
                  event.candidateAt >= event.capturedAt,
                  let attemptID = storage.attemptID else { return nil }

            let isNewerSnapshot = event.snapshotID > storage.lastSnapshotID
                && event.sampleRange.upperBound > storage.lastSampleUpperBound
            let matchesLatestFrames = kind == .final
                && finalAttemptID == attemptID
                && event.snapshotID >= storage.lastSnapshotID
                && event.sampleRange == storage.lastSampleRange
            guard isNewerSnapshot || matchesLatestFrames,
                  kind != .final || finalAttemptID == attemptID else { return nil }

            storage.lastSnapshotID = event.snapshotID
            storage.lastSampleUpperBound = event.sampleRange.upperBound
            storage.lastSampleRange = event.sampleRange
            guard kind == .final || event.text != storage.lastSourceText else { return nil }

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
                kind: kind,
                generationIDs: generations,
                capturedAt: event.capturedAt,
                candidateAt: event.candidateAt,
                emittedAt: now(),
                stablePrefixCharacterCount: stableCount,
                mutableSourceCharacterRange: stableCount..<event.text.count,
                mutableSuffix: mutableSuffix,
                tokenEvidence: event.tokenEvidence
            )
            storage.nextRevision &+= 1
            storage.lastSourceText = event.text
            storage.latestRevision = revision
            storage.contextualPreviewText = nil
            storage.retainedContext = String(event.text.suffix(configuration.maximumContextCharacters))

            if kind == .final {
                guard storage.state.canTransition(to: .finalizing) else { return nil }
                storage.state = .finalizing
                storage.finalCandidate = ContinuousContextFinalCandidate(
                    attemptID: attemptID,
                    revision: revision.revision,
                    sourceText: event.text,
                    language: storage.language,
                    generationIDs: generations
                )
                cancellation = invalidateWorkAndBuffers(keepingFinalCandidate: true)
            } else {
                let eligibleAt = max(
                    revision.emittedAt,
                    (storage.lastWorkDispatchedAt ?? -Double.infinity) + configuration.minimumWorkInterval
                )
                storage.pendingWork = ContinuousContextWork(
                    id: storage.nextWorkID,
                    attemptID: attemptID,
                    revision: revision.revision,
                    snapshotID: revision.snapshotID,
                    sampleRange: revision.sampleRange,
                    sourceText: revision.sourceText,
                    language: revision.language,
                    mutableSuffix: revision.mutableSuffix,
                    stablePrefixCharacterCount: revision.stablePrefixCharacterCount,
                    mutableSourceCharacterRange: revision.mutableSourceCharacterRange,
                    generationIDs: generations,
                    eligibleAt: eligibleAt,
                    expiresAt: eligibleAt + configuration.maximumWorkAge,
                    tokenEvidence: revision.tokenEvidence
                )
                storage.nextWorkID &+= 1
            }
            return revision
        }
        cancellation?()
        return revision
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
            guard storage.state == .capturing,
                  storage.activeWork == nil,
                  let pending = storage.pendingWork else { return nil }
            guard now() < pending.expiresAt else {
                storage.pendingWork = nil
                return nil
            }
            guard now() >= pending.eligibleAt else { return nil }
            storage.activeWork = storage.pendingWork
            storage.pendingWork = nil
            storage.lastWorkDispatchedAt = now()
            return storage.activeWork
        }
    }

    func isStableForDispatch(_ occurrence: ContextualCorrectionOccurrence) -> Bool {
        lock.withLock {
            if occurrence.alternatives.allSatisfy({ $0.source == .learned }) { return true }
            let signature = ProactiveCandidateSignature(occurrence)
            if storage.proactiveSignature == signature {
                storage.proactiveSignatureCount += 1
            } else {
                storage.proactiveSignature = signature
                storage.proactiveSignatureCount = 1
            }
            return storage.proactiveSignatureCount >= 2
        }
    }

    func resetProactiveStability() {
        lock.withLock {
            storage.proactiveSignature = nil
            storage.proactiveSignatureCount = 0
        }
    }

    @discardableResult
    func registerCancellation(
        for work: ContinuousContextWork,
        cancellation: @escaping @Sendable () -> Void
    ) -> Bool {
        lock.withLock {
            guard storage.state == .capturing,
                  storage.activeWork?.id == work.id,
                  storage.activeWorkCancellation == nil else { return false }
            storage.activeWorkCancellation = cancellation
            return true
        }
    }

    func unregisterCancellation(for work: ContinuousContextWork) {
        lock.withLock {
            guard storage.activeWork?.id == work.id else { return }
            storage.activeWorkCancellation = nil
        }
    }

    @discardableResult
    func completeWork(_ work: ContinuousContextWork) -> Bool {
        lock.withLock {
            guard storage.state == .capturing,
                  storage.activeWork?.id == work.id else { return false }
            storage.activeWork = nil
            storage.activeWorkCancellation = nil
            return work.attemptID == storage.attemptID
                && work.generationIDs.session == storage.sessionGeneration
                && work.revision == storage.latestRevision?.revision
                && now() < work.expiresAt
        }
    }

    @discardableResult
    func applyContextualResult(_ result: RevisionBoundContextualResult, for work: ContinuousContextWork) -> Bool {
        applyContextualResult(result, occurrence: nil, for: work) != nil
    }

    @discardableResult
    func applyContextualResult(
        _ result: RevisionBoundContextualResult,
        occurrence: ContextualCorrectionOccurrence?,
        for work: ContinuousContextWork
    ) -> ContinuousContextApplication? {
        lock.withLock {
            guard storage.state == .capturing,
                  storage.activeWork?.id == work.id,
                  work.identity(
                    policyGeneration: result.identity.policyGeneration,
                    storeGeneration: result.identity.storeGeneration
                  ) == result.identity else { return nil }
            storage.activeWork = nil
            storage.activeWorkCancellation = nil
            guard work.attemptID == storage.attemptID,
                  work.generationIDs.session == storage.sessionGeneration,
                  now() < work.expiresAt,
                  result.originalText == work.sourceText,
                  let latest = storage.latestRevision else { return nil }
            let application: ContinuousContextApplication
            if work.revision == latest.revision, work.sourceText == latest.sourceText {
                application = .direct(result.text)
            } else if let occurrence,
                      let rebased = ContextualRevisionRebase.apply(
                        result: result,
                        evaluatedSource: work.sourceText,
                        occurrence: occurrence,
                        to: latest.sourceText
                      ) {
                application = .rebased(rebased)
            } else {
                return nil
            }
            let text = switch application {
            case .direct(let text), .rebased(let text): text
            }
            storage.contextualPreviewText = text
            return application
        }
    }

    func commitFinalCandidate() -> ContinuousContextFinalCandidate? {
        var cancellation: (@Sendable () -> Void)?
        let candidate: ContinuousContextFinalCandidate? = lock.withLock {
            guard storage.state.canTransition(to: .committed),
                  let candidate = storage.finalCandidate else { return nil }
            storage.state = .committed
            cancellation = clearSensitiveState()
            return candidate
        }
        cancellation?()
        return candidate
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
    var contextualPreviewText: String? { lock.withLock { storage.contextualPreviewText } }
    var retainedContext: String { lock.withLock { storage.retainedContext } }
    var retainedContextCharacterCount: Int { lock.withLock { storage.retainedContext.count } }
    var retainedAudioSampleCount: Int { lock.withLock { storage.retainedAudio.count } }
    var scheduledWorkCount: Int {
        lock.withLock { (storage.activeWork == nil ? 0 : 1) + (storage.pendingWork == nil ? 0 : 1) }
    }

    func nextWorkDelay() -> TimeInterval? {
        lock.withLock {
            guard storage.state == .capturing, let pending = storage.pendingWork else { return nil }
            return max(0, pending.eligibleAt - now())
        }
    }

    private func terminate(as terminal: ContinuousContextSessionState) {
        var cancellation: (@Sendable () -> Void)?
        lock.withLock {
            guard storage.state.canTransition(to: terminal) else { return }
            storage.state = terminal
            cancellation = clearSensitiveState()
        }
        cancellation?()
    }

    private func invalidateWorkAndBuffers(
        keepingFinalCandidate: Bool
    ) -> (@Sendable () -> Void)? {
        let cancellation = storage.activeWorkCancellation
        storage.sessionGeneration &+= 1
        storage.activeWork = nil
        storage.activeWorkCancellation = nil
        storage.pendingWork = nil
        storage.retainedAudio.removeAll(keepingCapacity: false)
        storage.retainedAudioRange = nil
        storage.retainedContext = ""
        storage.contextualPreviewText = nil
        storage.proactiveSignature = nil
        storage.proactiveSignatureCount = 0
        if !keepingFinalCandidate { storage.finalCandidate = nil }
        return cancellation
    }

    private func clearSensitiveState() -> (@Sendable () -> Void)? {
        let cancellation = invalidateWorkAndBuffers(keepingFinalCandidate: false)
        storage.lastSourceText = ""
        storage.latestRevision = nil
        storage.attemptID = nil
        storage.language = ""
        return cancellation
    }

    private static func commonPrefixCharacterCount(_ lhs: String, _ rhs: String) -> Int {
        zip(lhs, rhs).prefix(while: ==).count
    }

    private static func suffix(_ value: String, droppingCharacters count: Int) -> String {
        let index = value.index(value.startIndex, offsetBy: min(count, value.count))
        return String(value[index...])
    }
}

extension ContinuousContextWork {
    func identity(policyGeneration: UInt64, storeGeneration: UInt64) -> ContextualRevisionWindowIdentity {
        .init(
            attemptID: attemptID,
            revision: revision,
            snapshotID: snapshotID,
            sampleRange: sampleRange,
            mutableSourceCharacterRange: mutableSourceCharacterRange,
            generationIDs: generationIDs,
            policyGeneration: policyGeneration,
            storeGeneration: storeGeneration
        )
    }
}

private actor RevisionBoundDecisionRace {
    typealias Output = Result<ContextualDecisionReceipt, Error>
    private var continuation: CheckedContinuation<Output?, Never>?
    private var pending: Output??
    private var finished = false

    func install(_ continuation: CheckedContinuation<Output?, Never>) {
        if let pending {
            self.pending = nil
            continuation.resume(returning: pending)
        } else {
            self.continuation = continuation
        }
    }

    func finish(_ output: Output?) {
        guard !finished else { return }
        finished = true
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: output)
        } else {
            pending = output
        }
    }
}

@MainActor
private final class RevisionBoundTaskCancellation {
    private var cancellation: (@Sendable () -> Void)?
    private var cancelled = false

    func install(_ cancellation: @escaping @Sendable () -> Void) {
        guard !cancelled else {
            cancellation()
            return
        }
        self.cancellation = cancellation
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        let cancellation = cancellation
        self.cancellation = nil
        cancellation?()
    }
}

@MainActor
final class RevisionBoundJevLoop {
    private let session: ContinuousContextSession
    private let provider: any ContextualDecisionProvider
    private let time: any ContextualMonotonicTime
    private let storeSnapshot: @MainActor @Sendable () -> ContextualCorrectionStoreSnapshot
    private let policyGeneration: @MainActor @Sendable () -> UInt64
    private let policy: ContextualCorrectionPolicy?
    private let dispatchBudget: ContextualDispatchBudget
    private let glossaryTerms: @MainActor @Sendable () -> [String]
    private let thresholds: ProactiveCandidateThresholds
    private let onAttemptDisposition: @MainActor @Sendable (
        UUID, ContextualAttemptDisposition
    ) -> Void
    private let validator = ContextualDecisionValidator()

    init(
        session: ContinuousContextSession,
        provider: any ContextualDecisionProvider,
        time: any ContextualMonotonicTime,
        storeSnapshot: @escaping @MainActor @Sendable () -> ContextualCorrectionStoreSnapshot,
        policyGeneration: @escaping @MainActor @Sendable () -> UInt64,
        policy: ContextualCorrectionPolicy? = nil,
        dispatchBudget: ContextualDispatchBudget = ContextualDispatchBudget(),
        glossaryTerms: @escaping @MainActor @Sendable () -> [String] = { [] },
        thresholds: ProactiveCandidateThresholds = .frozen,
        onAttemptDisposition: @escaping @MainActor @Sendable (
            UUID, ContextualAttemptDisposition
        ) -> Void = { _, _ in }
    ) {
        self.session = session
        self.provider = provider
        self.time = time
        self.storeSnapshot = storeSnapshot
        self.policyGeneration = policyGeneration
        self.policy = policy
        self.dispatchBudget = dispatchBudget
        self.glossaryTerms = glossaryTerms
        self.thresholds = thresholds
        self.onAttemptDisposition = onAttemptDisposition
    }

    @discardableResult
    func evaluateNext(
        scope: ContextualTransportScope,
        policyToken: ContextualPolicyToken? = nil
    ) async -> RevisionBoundContextualResult? {
        guard let work = session.takeNextWork() else { return nil }
        let snapshot = storeSnapshot()
        let policyAtStart = policyGeneration()
        let identity = work.identity(
            policyGeneration: policyAtStart,
            storeGeneration: snapshot.generation
        )
        let abstained = RevisionBoundContextualResult(
            identity: identity,
            originalText: work.sourceText,
            text: work.sourceText,
            outcome: .init(category: .abstained, decisions: [])
        )

        if let policyToken,
           policyToken.scope != scope || policy?.isCurrent(policyToken) != true {
            _ = session.applyContextualResult(abstained, for: work)
            return abstained
        }
        guard (scope == .testDouble || (scope == .personalDictation && policyToken != nil)),
              snapshot.health == .healthy else {
            _ = session.applyContextualResult(abstained, for: work)
            return abstained
        }
        let learned = ContextualCorrectionResolver.matchCandidates(
            examples: snapshot.examples,
            text: work.sourceText,
            language: work.language
        )
        let occurrences: [ContextualCorrectionOccurrence]
        if !learned.isEmpty {
            occurrences = learned
        } else if let proactive = ProactiveContextualCandidateGenerator.candidate(
            text: work.sourceText,
            language: work.language,
            tokenEvidence: work.tokenEvidence,
            glossaryTerms: glossaryTerms(),
            examples: [],
            thresholds: thresholds
        ) {
            guard session.isStableForDispatch(proactive) else {
                _ = session.applyContextualResult(abstained, for: work)
                return abstained
            }
            occurrences = [proactive]
        } else {
            session.resetProactiveStability()
            _ = session.applyContextualResult(abstained, for: work)
            return abstained
        }
        guard let input = ContextualCorrectionResolver.validatedDecisionInput(
                occurrences: occurrences,
                text: work.sourceText
              ),
              (try? OpenRouterDecisionsClient.requestBody(
                sentence: input.sentence,
                language: work.language,
                occurrences: input.occurrences
              )) != nil else {
            _ = session.applyContextualResult(abstained, for: work)
            return abstained
        }

        let request = RevisionBoundContextualRequest(
            identity: identity,
            originalText: work.sourceText,
            sentence: input.sentence,
            language: work.language,
            occurrences: input.occurrences,
            deadline: .init(offset: time.now().offset + .milliseconds(1_200))
        )
        let race = RevisionBoundDecisionRace()
        let policyCancellation = RevisionBoundTaskCancellation()
        if let policyToken {
            guard let policy,
                  policy.register(policyToken, cancel: { policyCancellation.cancel() }) else {
                _ = session.applyContextualResult(abstained, for: work)
                return abstained
            }
        }
        defer {
            if let policyToken { policy?.finish(policyToken) }
        }
        guard dispatchBudget.consume() else {
            _ = session.applyContextualResult(abstained, for: work)
            return abstained
        }
        let provider = provider
        let providerTask = Task { [time] in
            do {
                let receipt = try await provider.decide(
                    sentence: request.sentence,
                    language: request.language,
                    occurrences: request.occurrences,
                    deadline: request.deadline
                )
                await race.finish(time.now() < request.deadline ? .success(receipt) : nil)
            } catch {
                await race.finish(.failure(error))
            }
        }
        let timeoutTask = Task { [time] in
            do {
                try await time.sleep(until: request.deadline)
                await race.finish(nil)
            } catch { }
        }
        let cancelWork: @Sendable () -> Void = {
            providerTask.cancel()
            timeoutTask.cancel()
            Task { await race.finish(nil) }
        }
        policyCancellation.install(cancelWork)
        let ownsWork = session.registerCancellation(for: work, cancellation: cancelWork)
        defer { session.unregisterCancellation(for: work) }
        if !ownsWork { cancelWork() }
        let raced = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                Task { await race.install(continuation) }
            }
        } onCancel: {
            cancelWork()
        }
        timeoutTask.cancel()

        guard let raced,
              case .success(let receipt) = raced,
              policyGeneration() == policyAtStart else {
            providerTask.cancel()
            _ = session.applyContextualResult(abstained, for: work)
            return abstained
        }
        let currentSnapshot = storeSnapshot()
        guard currentSnapshot.health == .healthy,
              currentSnapshot.generation == snapshot.generation else {
            report(receipt, .discarded)
            _ = session.applyContextualResult(abstained, for: work)
            return abstained
        }
        let outcome = validator.validate(receipt: receipt, occurrences: request.occurrences)
        guard outcome.category != .abstained,
              let resolved = ContextualCorrectionResolver.applying(
                receipt: receipt,
                occurrences: request.occurrences,
                to: request.originalText
              ) else {
            report(receipt, .discarded)
            _ = session.applyContextualResult(abstained, for: work)
            return abstained
        }
        let result = RevisionBoundContextualResult(
            identity: identity,
            originalText: request.originalText,
            text: resolved,
            outcome: outcome
        )
        let rebaseOccurrence = request.occurrences.count == 1 ? request.occurrences[0] : nil
        guard let application = session.applyContextualResult(
            result,
            occurrence: rebaseOccurrence,
            for: work
        ) else {
            report(receipt, .discarded)
            return abstained
        }
        report(receipt, outcome.category == .replaced ? .appliedReplacement : .keptOriginal)
        let appliedText = switch application {
        case .direct(let text), .rebased(let text): text
        }
        return RevisionBoundContextualResult(
            identity: identity,
            originalText: request.originalText,
            text: appliedText,
            outcome: outcome
        )
    }

    private func report(
        _ receipt: ContextualDecisionReceipt,
        _ disposition: ContextualAttemptDisposition
    ) {
        guard let attemptID = receipt.localAttemptID else { return }
        onAttemptDisposition(attemptID, disposition)
    }
}
