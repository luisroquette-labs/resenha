import Combine
import Foundation
import Security

struct ContextualCorrectionExample: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let language: String
    let heard: String
    let canonical: String
    let sentence: String
    let occurrenceOrdinal: Int
}

enum ContextualCorrectionValidationError: Equatable, Sendable {
    case empty
    case identical
    case invalidCharacters
    case sentenceTooLong
    case occurrenceMissing
    case occurrenceAmbiguous
}

enum ContextualCorrectionSaveResult: Equatable, Sendable {
    case saved(UUID)
    case alreadyExists(UUID)
    case conflict(UUID)
    case limitReached
    case invalid(ContextualCorrectionValidationError)
    case storageFailure(recoveryRequired: Bool)

    var isSuccess: Bool {
        switch self {
        case .saved, .alreadyExists: true
        default: false
        }
    }
}

enum ContextualCorrectionStoreError: Error, Equatable, Sendable {
    case unavailable
    case oversized
    case corrupt
    case unsupportedVersion(Int)
    case writeFailed
    case rollbackFailed
}

enum ContextualCorrectionStoreHealth: Equatable, Sendable {
    case healthy
    case unhealthy(ContextualCorrectionStoreError)
}

struct ContextualCorrectionStoreSnapshot: Equatable, Sendable {
    let examples: [ContextualCorrectionExample]
    let generation: UInt64
    let health: ContextualCorrectionStoreHealth
}

@MainActor
protocol ContextualCorrectionStoreContract: AnyObject {
    var examples: [ContextualCorrectionExample] { get }
    var error: ContextualCorrectionStoreError? { get }
    var generation: UInt64 { get }
    var snapshot: ContextualCorrectionStoreSnapshot { get }
    func save(_ example: ContextualCorrectionExample) -> ContextualCorrectionSaveResult
    func delete(id: UUID) -> Bool
    func deleteAll() -> Bool
    func reload() -> Bool
}

@MainActor
final class ContextualCorrectionStore: ObservableObject, ContextualCorrectionStoreContract {
    static let schemaVersion = 1
    static let maximumExamples = 100
    static let maximumSentenceCharacters = 600
    static let maximumFileBytes = 2 * 1_024 * 1_024

    private struct Envelope: Codable, Equatable {
        let schemaVersion: Int
        let examples: [ContextualCorrectionExample]
    }

    private let fileURL: URL
    private let fileManager: FileManager
    @Published private(set) var examples: [ContextualCorrectionExample] = []
    @Published private(set) var error: ContextualCorrectionStoreError?
    private(set) var generation: UInt64 = 0
    var onMutation: (@MainActor () -> Void)?

    var snapshot: ContextualCorrectionStoreSnapshot {
        .init(
            examples: examples,
            generation: generation,
            health: error.map(ContextualCorrectionStoreHealth.unhealthy) ?? .healthy
        )
    }

    init(fileURL: URL = ContextualCorrectionStore.defaultURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        guard fileManager.fileExists(atPath: fileURL.path) else {
            do { try prepareDirectory() }
            catch { self.error = .unavailable }
            return
        }
        do {
            examples = try readEnvelope().examples
        } catch let storeError as ContextualCorrectionStoreError {
            self.error = storeError
        } catch {
            self.error = .unavailable
        }
    }

    func save(_ example: ContextualCorrectionExample) -> ContextualCorrectionSaveResult {
        guard error == nil else { return .storageFailure(recoveryRequired: true) }
        if let validation = validate(example) { return .invalid(validation) }
        if let existing = examples.first(where: { $0.id == example.id }) {
            return existing == example ? .alreadyExists(existing.id) : .conflict(existing.id)
        }
        if let existing = examples.first(where: { identity(of: $0) == identity(of: example) }) {
            return existing.canonical == example.canonical && existing.heard == example.heard
                ? .alreadyExists(existing.id)
                : .conflict(existing.id)
        }
        guard examples.count < Self.maximumExamples else { return .limitReached }
        return persist(examples + [example]) ? .saved(example.id) : .storageFailure(recoveryRequired: error != nil)
    }

    func delete(id: UUID) -> Bool {
        guard error == nil, examples.contains(where: { $0.id == id }) else { return false }
        return persist(examples.filter { $0.id != id })
    }

    func deleteAll() -> Bool {
        guard error == nil else { return false }
        if examples.isEmpty, !fileManager.fileExists(atPath: fileURL.path) { return true }
        return persist([])
    }

    func reload() -> Bool {
        do {
            let loaded: [ContextualCorrectionExample]
            if fileManager.fileExists(atPath: fileURL.path) {
                loaded = try readEnvelope().examples
            } else {
                try prepareDirectory()
                loaded = []
            }
            examples = loaded
            error = nil
            generation &+= 1
            return true
        } catch let storeError as ContextualCorrectionStoreError {
            error = storeError
            return false
        } catch {
            self.error = .unavailable
            return false
        }
    }

    nonisolated static func defaultURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Resenha", isDirectory: true)
            .appendingPathComponent("ContextualCorrections", isDirectory: true)
            .appendingPathComponent("v1.json")
    }

    private func validate(_ example: ContextualCorrectionExample) -> ContextualCorrectionValidationError? {
        guard !example.heard.contains(where: { $0.isNewline || $0 == "=" }),
              !example.canonical.contains(where: { $0.isNewline || $0 == "=" }),
              !example.sentence.contains(where: \.isNewline) else {
            return .invalidCharacters
        }
        let heard = example.heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonical = example.canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentence = example.sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty, !canonical.isEmpty, !sentence.isEmpty else { return .empty }
        guard heard.caseInsensitiveCompare(canonical) != .orderedSame else { return .identical }
        guard TranscriptionLanguage(rawValue: example.language) != nil else { return .invalidCharacters }
        guard sentence.count <= Self.maximumSentenceCharacters else { return .sentenceTooLong }
        guard example.occurrenceOrdinal > 0 else { return .occurrenceAmbiguous }
        let matches = Self.wholeTermRanges(heard, in: sentence)
        guard !matches.isEmpty else { return .occurrenceMissing }
        guard example.occurrenceOrdinal <= matches.count else { return .occurrenceAmbiguous }
        return nil
    }

    private func identity(of example: ContextualCorrectionExample) -> String {
        [example.language, example.sentence, example.heard.lowercased(), String(example.occurrenceOrdinal)]
            .joined(separator: "\u{1f}")
    }

    private static func wholeTermRanges(_ term: String, in text: String) -> [Range<String.Index>] {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        guard let regex = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])", options: [.caseInsensitive]) else {
            return []
        }
        let full = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: full).compactMap { Range($0.range, in: text) }
    }

    private func persist(_ candidate: [ContextualCorrectionExample]) -> Bool {
        let priorExamples = examples
        let priorBytes = try? Data(contentsOf: fileURL)
        let temporaryURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent(".v1-\(UUID().uuidString).tmp")
        do {
            try prepareDirectory()
            let envelope = Envelope(schemaVersion: Self.schemaVersion, examples: candidate)
            let data = try JSONEncoder().encode(envelope)
            guard data.count <= Self.maximumFileBytes else { throw ContextualCorrectionStoreError.oversized }
            try data.write(to: temporaryURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporaryURL.path)
            let checked = try decode(try boundedData(at: temporaryURL))
            guard checked == envelope else { throw ContextualCorrectionStoreError.writeFailed }
            try data.write(to: fileURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            guard try readEnvelope() == envelope else { throw ContextualCorrectionStoreError.writeFailed }
            try? fileManager.removeItem(at: temporaryURL)
            examples = candidate
            generation &+= 1
            onMutation?()
            return true
        } catch let storeError as ContextualCorrectionStoreError {
            try? fileManager.removeItem(at: temporaryURL)
            return failTransaction(storeError, priorBytes: priorBytes, priorExamples: priorExamples)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            return failTransaction(.writeFailed, priorBytes: priorBytes, priorExamples: priorExamples)
        }
    }

    private func failTransaction(
        _ failure: ContextualCorrectionStoreError,
        priorBytes: Data?,
        priorExamples: [ContextualCorrectionExample]
    ) -> Bool {
        examples = priorExamples
        guard let priorBytes else {
            error = failure
            return false
        }
        do {
            try priorBytes.write(to: fileURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            _ = try readEnvelope()
            error = failure
        } catch {
            self.error = .rollbackFailed
        }
        return false
    }

    private func readEnvelope() throws -> Envelope {
        try decode(boundedData(at: fileURL))
    }

    private func boundedData(at url: URL) throws -> Data {
        let size: Int
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard let fileSize = attributes[.size] as? NSNumber else {
                throw ContextualCorrectionStoreError.unavailable
            }
            size = fileSize.intValue
        }
        catch { throw ContextualCorrectionStoreError.unavailable }
        guard size <= Self.maximumFileBytes else {
            throw ContextualCorrectionStoreError.oversized
        }
        do { return try Data(contentsOf: url, options: [.mappedIfSafe]) }
        catch { throw ContextualCorrectionStoreError.unavailable }
    }

    private func decode(_ data: Data) throws -> Envelope {
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw ContextualCorrectionStoreError.corrupt }
        guard envelope.schemaVersion == Self.schemaVersion else {
            throw ContextualCorrectionStoreError.unsupportedVersion(envelope.schemaVersion)
        }
        guard envelope.examples.count <= Self.maximumExamples,
              envelope.examples.allSatisfy({ validate($0) == nil }),
              Set(envelope.examples.map(\.id)).count == envelope.examples.count else {
            throw ContextualCorrectionStoreError.corrupt
        }
        return envelope
    }

    private func prepareDirectory() throws {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        } catch {
            throw ContextualCorrectionStoreError.unavailable
        }
    }
}

struct ContextualCorrectionOccurrence: Equatable, Sendable {
    let questionID: String
    let heard: String
    let canonical: String
    let ordinal: Int
    let range: Range<String.Index>
}

enum ContextualDecisionChoice: String, Codable, Sendable {
    case keepOriginal = "keep_original"
    case replace = "replace_1"
}

struct ContextualDecision: Equatable, Sendable {
    let questionID: String
    let choice: ContextualDecisionChoice
    let confidence: Double
    let chosenProbability: Double
    let runnerUpProbability: Double
}

struct ContextualDecisionReceipt: Equatable, Sendable {
    let decisions: [ContextualDecision]
    let resolvedModel: String
    let inputTokens: Int?
    let outputTokens: Int?
    let costUSD: Decimal?
}

protocol ContextualDecisionProvider: Sendable {
    func decide(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant
    ) async throws -> ContextualDecisionReceipt
}

struct ContextualInstant: Comparable, Sendable {
    let offset: Duration
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.offset < rhs.offset }
}

protocol ContextualMonotonicTime: AnyObject, Sendable {
    func now() -> ContextualInstant
    func sleep(until deadline: ContextualInstant) async throws
}

final class ContinuousContextualTime: ContextualMonotonicTime, @unchecked Sendable {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    init() { origin = clock.now }

    func now() -> ContextualInstant { .init(offset: origin.duration(to: clock.now)) }

    func sleep(until deadline: ContextualInstant) async throws {
        try await clock.sleep(until: origin.advanced(by: deadline.offset))
    }
}

enum ContextualTimeCompositionError: Error, Equatable {
    case mismatchedOrigins
}

struct ContextualTimeComposition {
    let shared: any ContextualMonotonicTime

    init(
        resolver: any ContextualMonotonicTime,
        diagnostic: any ContextualMonotonicTime,
        transport: any ContextualMonotonicTime
    ) throws {
        guard resolver === diagnostic, diagnostic === transport else {
            throw ContextualTimeCompositionError.mismatchedOrigins
        }
        shared = resolver
    }
}

enum ContextualTransportScope: Equatable, Sendable {
    case disabled
    case personalDictation
    case testDouble
    case syntheticDiagnostic
}

enum ContextualPolicyInvalidationReason: Sendable {
    case optedOut
    case credentialDeleted
    case storeMutated
    case appTerminated
}

struct ContextualPolicyToken: Equatable, Sendable {
    let requestID: UUID
    let generation: UInt64
    let scope: ContextualTransportScope
}

@MainActor
protocol ContextualCorrectionPolicyContract: AnyObject {
    var generation: UInt64 { get }
    func issueToken(scope: ContextualTransportScope) -> ContextualPolicyToken
    func register(
        _ token: ContextualPolicyToken,
        cancel: @escaping @MainActor @Sendable () -> Void
    ) -> Bool
    func finish(_ token: ContextualPolicyToken)
    func isCurrent(_ token: ContextualPolicyToken) -> Bool
    func invalidate(_ reason: ContextualPolicyInvalidationReason)
}

@MainActor
final class ContextualCorrectionPolicy: ContextualCorrectionPolicyContract {
    private(set) var generation: UInt64 = 0
    private var cancellations: [UUID: @MainActor @Sendable () -> Void] = [:]

    func issueToken(scope: ContextualTransportScope) -> ContextualPolicyToken {
        .init(requestID: UUID(), generation: generation, scope: scope)
    }

    func register(
        _ token: ContextualPolicyToken,
        cancel: @escaping @MainActor @Sendable () -> Void
    ) -> Bool {
        guard isCurrent(token) else {
            cancel()
            return false
        }
        cancellations[token.requestID] = cancel
        return true
    }

    func finish(_ token: ContextualPolicyToken) {
        cancellations.removeValue(forKey: token.requestID)
    }

    func isCurrent(_ token: ContextualPolicyToken) -> Bool {
        token.generation == generation
    }

    func invalidate(_ reason: ContextualPolicyInvalidationReason) {
        generation &+= 1
        let pending = Array(cancellations.values)
        cancellations.removeAll()
        pending.forEach { $0() }
    }
}

struct ContextualResolutionRequest: Sendable {
    let attemptID: UUID
    let text: String
    let language: String
    let policyToken: ContextualPolicyToken
    let storeGenerationAtStart: UInt64
}

struct ContextualDecisionTrace: Equatable, Sendable {
    let questionID: String
    let choice: ContextualDecisionChoice
    let selectedProbability: Double
    let runnerUpProbability: Double
    var margin: Double { selectedProbability - runnerUpProbability }
}

struct ValidatedContextualOutcome: Equatable, Sendable {
    enum Category: String, Codable, Sendable { case kept, replaced, abstained }
    let category: Category
    let decisions: [ContextualDecisionTrace]
}

struct ContextualResolutionResult: Equatable, Sendable {
    let text: String
    let outcome: ValidatedContextualOutcome
}

protocol ContextualDecisionValidating: Sendable {
    func validate(
        receipt: ContextualDecisionReceipt,
        occurrences: [ContextualCorrectionOccurrence]
    ) -> ValidatedContextualOutcome
}

struct ContextualDecisionValidator: ContextualDecisionValidating {
    func validate(
        receipt: ContextualDecisionReceipt,
        occurrences: [ContextualCorrectionOccurrence]
    ) -> ValidatedContextualOutcome {
        let expectedIDs = occurrences.map(\.questionID)
        guard receipt.decisions.count == expectedIDs.count,
              receipt.decisions.map(\.questionID) == expectedIDs else {
            return .init(category: .abstained, decisions: [])
        }
        var traces: [ContextualDecisionTrace] = []
        for decision in receipt.decisions {
            let values = [decision.confidence, decision.chosenProbability, decision.runnerUpProbability]
            guard values.allSatisfy({ $0.isFinite && (0...1).contains($0) }),
                  abs(decision.chosenProbability + decision.runnerUpProbability - 1) <= 0.000_001,
                  decision.chosenProbability > decision.runnerUpProbability,
                  decision.confidence >= 0.90,
                  decision.chosenProbability >= 0.90 else {
                return .init(category: .abstained, decisions: [])
            }
            traces.append(.init(
                questionID: decision.questionID,
                choice: decision.choice,
                selectedProbability: decision.chosenProbability,
                runnerUpProbability: decision.runnerUpProbability
            ))
        }
        return .init(
            category: traces.contains(where: { $0.choice == .replace }) ? .replaced : .kept,
            decisions: traces
        )
    }
}

@MainActor
protocol ContextualResolving: AnyObject {
    func resolve(_ request: ContextualResolutionRequest) async -> String
}

@MainActor
protocol ContextualCorrectionResolverContract: ContextualResolving {
    init(
        store: ContextualCorrectionStore,
        policy: ContextualCorrectionPolicy,
        provider: any ContextualDecisionProvider,
        storeGeneration: @escaping @MainActor @Sendable () -> UInt64,
        candidateMatcher: @escaping @MainActor @Sendable (
            _ examples: [ContextualCorrectionExample], _ text: String, _ language: String
        ) -> [ContextualCorrectionOccurrence],
        time: any ContextualMonotonicTime
    )
    static func matchCandidates(
        examples: [ContextualCorrectionExample],
        text: String,
        language: String
    ) -> [ContextualCorrectionOccurrence]
    func resolveWithTrace(_ request: ContextualResolutionRequest) async -> ContextualResolutionResult
}

private actor ContextualDecisionRace {
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
final class ContextualCorrectionResolver: ContextualCorrectionResolverContract {
    typealias CandidateMatcher = @MainActor @Sendable (
        _ examples: [ContextualCorrectionExample], _ text: String, _ language: String
    ) -> [ContextualCorrectionOccurrence]

    private let store: ContextualCorrectionStore
    private let policy: ContextualCorrectionPolicy
    private let provider: any ContextualDecisionProvider
    private let storeGeneration: @MainActor @Sendable () -> UInt64
    private let candidateMatcher: CandidateMatcher
    private let time: any ContextualMonotonicTime
    private let validator: ContextualDecisionValidator

    init(
        store: ContextualCorrectionStore,
        policy: ContextualCorrectionPolicy,
        provider: any ContextualDecisionProvider,
        storeGeneration: @escaping @MainActor @Sendable () -> UInt64,
        candidateMatcher: @escaping CandidateMatcher = { examples, text, language in
            ContextualCorrectionResolver.matchCandidates(
                examples: examples,
                text: text,
                language: language
            )
        },
        time: any ContextualMonotonicTime
    ) {
        self.store = store
        self.policy = policy
        self.provider = provider
        self.storeGeneration = storeGeneration
        self.candidateMatcher = candidateMatcher
        self.time = time
        validator = .init()
    }

    func resolve(_ request: ContextualResolutionRequest) async -> String {
        await resolveWithTrace(request).text
    }

    func resolveWithTrace(_ request: ContextualResolutionRequest) async -> ContextualResolutionResult {
        let storeSnapshot = store.snapshot
        let original = ContextualResolutionResult(
            text: request.text,
            outcome: .init(category: .abstained, decisions: [])
        )
        let deadline = ContextualInstant(offset: time.now().offset + .milliseconds(900))
        guard storeSnapshot.health == .healthy,
              request.storeGenerationAtStart == storeSnapshot.generation,
              request.storeGenerationAtStart == storeGeneration(),
              policy.isCurrent(request.policyToken),
              isProviderEligible(request.policyToken.scope) else { return original }

        let occurrences = candidateMatcher(storeSnapshot.examples, request.text, request.language)
        guard (1...3).contains(occurrences.count),
              Self.areValid(occurrences, in: request.text),
              let sentence = Self.decisionSentence(in: request.text, occurrences: occurrences),
              sentence.count <= ContextualCorrectionStore.maximumSentenceCharacters else { return original }

        let provider = provider
        let race = ContextualDecisionRace()
        let providerTask = Task {
            do {
                let receipt = try await provider.decide(
                    sentence: sentence,
                    language: request.language,
                    occurrences: occurrences,
                    deadline: deadline
                )
                await race.finish(.success(receipt))
            } catch {
                await race.finish(.failure(error))
            }
        }
        guard policy.register(request.policyToken, cancel: { providerTask.cancel() }) else {
            return original
        }
        defer { policy.finish(request.policyToken) }

        let timeoutTask = Task { [time] in
            do {
                try await time.sleep(until: deadline)
                await race.finish(nil)
            } catch { }
        }
        let raced = await withCheckedContinuation { continuation in
            Task { await race.install(continuation) }
        }
        timeoutTask.cancel()
        guard let raced else {
            providerTask.cancel()
            return original
        }
        guard case .success(let receipt) = raced else { return original }
        let currentSnapshot = store.snapshot
        guard currentSnapshot.health == .healthy,
              currentSnapshot.generation == storeSnapshot.generation,
              request.storeGenerationAtStart == storeGeneration(),
              policy.isCurrent(request.policyToken),
              time.now() < deadline else { return original }

        let outcome = validator.validate(receipt: receipt, occurrences: occurrences)
        guard outcome.category != .abstained else { return original }
        guard outcome.category == .replaced else {
            return .init(text: request.text, outcome: outcome)
        }
        var resolved = request.text
        let replacements = zip(occurrences, receipt.decisions)
            .filter { $0.1.choice == .replace }
            .sorted { $0.0.range.lowerBound > $1.0.range.lowerBound }
        for (occurrence, _) in replacements {
            resolved.replaceSubrange(occurrence.range, with: occurrence.canonical)
        }
        return .init(text: resolved, outcome: outcome)
    }

    static func matchCandidates(
        examples: [ContextualCorrectionExample],
        text: String,
        language: String
    ) -> [ContextualCorrectionOccurrence] {
        let relevant = examples.filter { $0.language == language }
        let grouped = Dictionary(grouping: relevant) { $0.heard.lowercased() }
        var candidates: [(heard: String, canonical: String, ordinal: Int, range: Range<String.Index>)] = []
        for group in grouped.values {
            let destinations = Set(group.map { $0.canonical })
            guard destinations.count == 1, let example = group.first else { return [] }
            let escaped = NSRegularExpression.escapedPattern(for: example.heard)
            guard let regex = try? NSRegularExpression(
                pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) else { return [] }
            let matches = regex.matches(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
            )
            for (index, match) in matches.enumerated() {
                guard let range = Range(match.range, in: text) else { return [] }
                candidates.append((example.heard, example.canonical, index + 1, range))
            }
        }
        candidates.sort { $0.range.lowerBound < $1.range.lowerBound }
        for adjacent in zip(candidates, candidates.dropFirst()) {
            guard adjacent.0.range.upperBound <= adjacent.1.range.lowerBound else { return [] }
        }
        return candidates.enumerated().map { index, candidate in
            .init(
                questionID: "o\(index + 1)",
                heard: candidate.heard,
                canonical: candidate.canonical,
                ordinal: candidate.ordinal,
                range: candidate.range
            )
        }
    }

    private static func decisionSentence(
        in text: String,
        occurrences: [ContextualCorrectionOccurrence]
    ) -> String? {
        var containingRanges: [Range<String.Index>] = []
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.bySentences, .substringNotRequired]
        ) { _, range, _, _ in
            if occurrences.contains(where: {
                range.lowerBound <= $0.range.lowerBound && $0.range.upperBound <= range.upperBound
            }) {
                containingRanges.append(range)
            }
        }
        guard containingRanges.count == 1,
              occurrences.allSatisfy({ occurrence in
                  containingRanges[0].lowerBound <= occurrence.range.lowerBound
                      && occurrence.range.upperBound <= containingRanges[0].upperBound
              }) else { return nil }
        return String(text[containingRanges[0]])
    }

    private static func areValid(
        _ occurrences: [ContextualCorrectionOccurrence],
        in text: String
    ) -> Bool {
        var previousUpperBound: String.Index?
        for (index, occurrence) in occurrences.enumerated() {
            guard occurrence.questionID == "o\(index + 1)",
                  !occurrence.heard.isEmpty,
                  !occurrence.canonical.isEmpty,
                  occurrence.ordinal > 0,
                  occurrence.range.lowerBound.samePosition(in: text.utf16) != nil,
                  occurrence.range.upperBound.samePosition(in: text.utf16) != nil,
                  text[occurrence.range].compare(
                      occurrence.heard,
                      options: [.caseInsensitive]
                  ) == .orderedSame else { return false }
            if let previousUpperBound, previousUpperBound > occurrence.range.lowerBound {
                return false
            }
            let matchingRanges = wholeTermRanges(occurrence.heard, in: text)
            guard occurrence.ordinal <= matchingRanges.count,
                  matchingRanges[occurrence.ordinal - 1] == occurrence.range else { return false }
            previousUpperBound = occurrence.range.upperBound
        }
        return true
    }

    private static func wholeTermRanges(_ term: String, in text: String) -> [Range<String.Index>] {
        let escaped = NSRegularExpression.escapedPattern(for: term)
        guard let regex = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive]
        ) else { return [] }
        return regex.matches(
            in: text,
            range: NSRange(text.startIndex..<text.endIndex, in: text)
        ).compactMap { Range($0.range, in: text) }
    }

    private func isProviderEligible(_ scope: ContextualTransportScope) -> Bool {
        scope == .syntheticDiagnostic || scope == .testDouble
    }
}
