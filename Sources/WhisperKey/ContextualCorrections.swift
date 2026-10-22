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
    case multipleSentences
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

extension ContextualCorrectionSaveResult {
    var feedbackMessage: String {
        switch self {
        case .saved: "Correção contextual aprendida neste Mac"
        case .alreadyExists: "Correção contextual já existente"
        case .conflict: "Já existe outra correção para esta ocorrência"
        case .limitReached: "O limite de 100 correções contextuais foi atingido"
        case .invalid(.sentenceTooLong): "A frase confirmada ultrapassa 600 caracteres"
        case .invalid(.multipleSentences): "Confirme apenas a frase que contém a palavra corrigida"
        case .invalid(.occurrenceMissing): "A palavra ouvida não aparece na frase confirmada"
        case .invalid(.occurrenceAmbiguous): "Selecione a ocorrência exata antes de salvar"
        case .invalid: "Confira a palavra ouvida, a correção e a frase confirmada"
        case .storageFailure(false): "Não foi possível salvar a correção contextual"
        case .storageFailure(true): "Recarregue as correções contextuais antes de tentar novamente"
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
        guard ContextualSentenceBoundary.ranges(in: sentence).count == 1 else { return .multipleSentences }
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

enum ContextualSentenceBoundary {
    static func ranges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        text.enumerateSubstrings(
            in: text.startIndex..<text.endIndex,
            options: [.bySentences, .substringNotRequired]
        ) { _, range, _, _ in
            ranges.append(range)
        }
        return ranges
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

enum PersonalRemoteReleaseDecision: String, CaseIterable, Equatable, Sendable {
    case personalRemoteAvailable

    static let current = PersonalRemoteReleaseDecision.personalRemoteAvailable
}

enum ContextualPolicyInvalidationReason: Sendable {
    case optedOut
    case credentialDeleted
    case storeMutated
    case appTerminated
    case authorityChanged
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
    let revisionIdentity: ContextualRevisionWindowIdentity?

    init(
        attemptID: UUID,
        text: String,
        language: String,
        policyToken: ContextualPolicyToken,
        storeGenerationAtStart: UInt64,
        revisionIdentity: ContextualRevisionWindowIdentity? = nil
    ) {
        self.attemptID = attemptID
        self.text = text
        self.language = language
        self.policyToken = policyToken
        self.storeGenerationAtStart = storeGenerationAtStart
        self.revisionIdentity = revisionIdentity
    }
}

struct ContextualRevisionWindowIdentity: Equatable, Sendable {
    let attemptID: UUID
    let revision: UInt64
    let snapshotID: UInt64
    let sampleRange: Range<Int64>
    let mutableSourceCharacterRange: Range<Int>
    let generationIDs: ContinuousContextGenerationIDs
    let policyGeneration: UInt64
    let storeGeneration: UInt64
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
    let revisionIdentity: ContextualRevisionWindowIdentity?

    init(
        text: String,
        outcome: ValidatedContextualOutcome,
        revisionIdentity: ContextualRevisionWindowIdentity? = nil
    ) {
        self.text = text
        self.outcome = outcome
        self.revisionIdentity = revisionIdentity
    }
}

struct RevisionBoundContextualResult: Equatable, Sendable {
    let identity: ContextualRevisionWindowIdentity
    let originalText: String
    let text: String
    let outcome: ValidatedContextualOutcome
}

struct RevisionBoundContextualRequest: Sendable {
    let identity: ContextualRevisionWindowIdentity
    let originalText: String
    let sentence: String
    let language: String
    let occurrences: [ContextualCorrectionOccurrence]
    let deadline: ContextualInstant
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
    nonisolated static func matchCandidates(
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
    private let onProviderError: @MainActor @Sendable (Error) -> Void

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
        onProviderError = { _ in }
        validator = .init()
    }

    init(
        store: ContextualCorrectionStore,
        policy: ContextualCorrectionPolicy,
        provider: any ContextualDecisionProvider,
        storeGeneration: @escaping @MainActor @Sendable () -> UInt64,
        time: any ContextualMonotonicTime,
        onProviderError: @escaping @MainActor @Sendable (Error) -> Void
    ) {
        self.store = store
        self.policy = policy
        self.provider = provider
        self.storeGeneration = storeGeneration
        self.candidateMatcher = { examples, text, language in
            ContextualCorrectionResolver.matchCandidates(
                examples: examples, text: text, language: language
            )
        }
        self.time = time
        self.onProviderError = onProviderError
        validator = .init()
    }

    func resolve(_ request: ContextualResolutionRequest) async -> String {
        await resolveWithTrace(request).text
    }

    func resolveWithTrace(_ request: ContextualResolutionRequest) async -> ContextualResolutionResult {
        let storeSnapshot = store.snapshot
        let original = ContextualResolutionResult(
            text: request.text,
            outcome: .init(category: .abstained, decisions: []),
            revisionIdentity: request.revisionIdentity
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
        guard case .success(let receipt) = raced else {
            if case .failure(let error) = raced { onProviderError(error) }
            return original
        }
        let currentSnapshot = store.snapshot
        guard currentSnapshot.health == .healthy,
              currentSnapshot.generation == storeSnapshot.generation,
              request.storeGenerationAtStart == storeGeneration(),
              policy.isCurrent(request.policyToken),
              time.now() < deadline else { return original }

        let outcome = validator.validate(receipt: receipt, occurrences: occurrences)
        guard outcome.category != .abstained else { return original }
        guard outcome.category == .replaced else {
            return .init(text: request.text, outcome: outcome, revisionIdentity: request.revisionIdentity)
        }
        var resolved = request.text
        let replacements = zip(occurrences, receipt.decisions)
            .filter { $0.1.choice == .replace }
            .sorted { $0.0.range.lowerBound > $1.0.range.lowerBound }
        for (occurrence, _) in replacements {
            resolved.replaceSubrange(occurrence.range, with: occurrence.canonical)
        }
        return .init(text: resolved, outcome: outcome, revisionIdentity: request.revisionIdentity)
    }

    nonisolated static func matchCandidates(
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

    nonisolated static func validatedDecisionInput(
        examples: [ContextualCorrectionExample],
        text: String,
        language: String
    ) -> (occurrences: [ContextualCorrectionOccurrence], sentence: String)? {
        let occurrences = matchCandidates(examples: examples, text: text, language: language)
        guard (1...3).contains(occurrences.count),
              areValid(occurrences, in: text),
              let sentence = decisionSentence(in: text, occurrences: occurrences),
              sentence.count <= 600,
              preservesProtectedSemantics(occurrences) else { return nil }
        return (occurrences, sentence)
    }

    nonisolated static func applying(
        receipt: ContextualDecisionReceipt,
        occurrences: [ContextualCorrectionOccurrence],
        to original: String
    ) -> String? {
        guard receipt.decisions.count == occurrences.count,
              receipt.decisions.map(\.questionID) == occurrences.map(\.questionID),
              areValid(occurrences, in: original) else { return nil }
        var resolved = original
        let replacements = zip(occurrences, receipt.decisions)
            .filter { $0.1.choice == .replace }
            .sorted { $0.0.range.lowerBound > $1.0.range.lowerBound }
        for (occurrence, _) in replacements {
            resolved.replaceSubrange(occurrence.range, with: occurrence.canonical)
        }
        return resolved
    }

    nonisolated private static func decisionSentence(
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

    nonisolated private static func areValid(
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

    nonisolated private static func wholeTermRanges(_ term: String, in text: String) -> [Range<String.Index>] {
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

    nonisolated private static func preservesProtectedSemantics(
        _ occurrences: [ContextualCorrectionOccurrence]
    ) -> Bool {
        let negations = Set(["não", "nao", "nunca", "jamais", "sem"])
        return occurrences.allSatisfy { occurrence in
            let heardDigits = occurrence.heard.filter(\.isNumber)
            let canonicalDigits = occurrence.canonical.filter(\.isNumber)
            guard heardDigits == canonicalDigits else { return false }
            let heardWords = Set(occurrence.heard.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            let canonicalWords = Set(occurrence.canonical.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            guard heardWords.intersection(negations) == canonicalWords.intersection(negations) else { return false }
            let protected = CharacterSet(charactersIn: "@:/\\")
            let heardProtected = occurrence.heard.unicodeScalars.filter { protected.contains($0) }
            let canonicalProtected = occurrence.canonical.unicodeScalars.filter { protected.contains($0) }
            return heardProtected.elementsEqual(canonicalProtected)
        }
    }

    private func isProviderEligible(_ scope: ContextualTransportScope) -> Bool {
        scope == .personalDictation || scope == .syntheticDiagnostic || scope == .testDouble
    }
}

struct DecisionsRequestDTO: Encodable, Equatable, Sendable {
    struct State: Encodable, Equatable, Sendable {
        struct Occurrence: Encodable, Equatable, Sendable {
            let heard: String
            let canonical: String
            let ordinal: Int
        }

        let language: String
        let text: String
        let occurrences: [Occurrence]
    }

    struct Question: Encodable, Equatable, Sendable {
        let type: String
        let instructions: String
        let criteria: [String: String]
    }

    let model: String
    let state: State
    let questions: [String: Question]
}

struct DecisionsResponseDTO: Decodable, Equatable, Sendable {
    struct Answer: Decodable, Equatable, Sendable {
        let type: String
        let choice: String
        let probabilities: [String: Double]
        let confidence: Double
    }

    struct Usage: Decodable, Equatable, Sendable {
        let cost: Decimal?
        let inputTokens: Int?
        let outputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case cost
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    let model: String
    let answers: [String: Answer]
    let usage: Usage?
}

struct DecisionsResponseStream: @unchecked Sendable {
    let response: HTTPURLResponse
    let nextChunk: @Sendable () async throws -> Data?
    let cancel: @Sendable () -> Void
}

protocol DecisionsStreamingTransport: Sendable {
    func open(
        _ request: URLRequest,
        maximumResponseBytes: Int,
        deadline: ContextualInstant
    ) async throws -> DecisionsResponseStream
}

protocol URLSessionDecisionsStreamingTransportContract: DecisionsStreamingTransport {
    init(time: any ContextualMonotonicTime)
}

protocol SyntheticDiagnosticDecisionProvider: Sendable {
    func decideSynthetic(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant,
        beforeTransportOpen: @escaping @Sendable () async -> Bool
    ) async throws -> ContextualDecisionReceipt
}

enum OpenRouterDecisionsError: Error, Equatable, Sendable {
    case invalidEndpoint
    case missingCredential
    case authorizationInvalidated
    case invalidStatus(Int)
    case redirected
    case malformedResponse
    case responseTooLarge
    case requestTooLarge
    case timedOut
    case transportUnavailable
    case cancelled
}

struct DecisionsDelegateSnapshot: Equatable, Sendable {
    let acceptedBytes: Int
    let queuedChunkCount: Int
    let cancelCount: Int
}

protocol DecisionsDelegateStateContract: Sendable {
    init(maximumResponseBytes: Int, cancelTask: @escaping @Sendable () -> Void)
    func receive(_ data: Data)
    func nextChunk() async throws -> Data?
    func finish(_ error: Error?)
    func cancel()
}

final class DecisionsDelegateState: DecisionsDelegateStateContract, @unchecked Sendable {
    private enum Terminal {
        case success
        case failure(Error)
    }

    private let lock = NSLock()
    private let maximumResponseBytes: Int
    private let cancelTask: @Sendable () -> Void
    private var acceptedBytes = 0
    private var chunks: [Data] = []
    private var waiters: [CheckedContinuation<Data?, Error>] = []
    private var terminal: Terminal?
    private var cancelCount = 0

    init(maximumResponseBytes: Int, cancelTask: @escaping @Sendable () -> Void) {
        self.maximumResponseBytes = maximumResponseBytes
        self.cancelTask = cancelTask
    }

    func receive(_ data: Data) {
        var waiter: CheckedContinuation<Data?, Error>?
        var overflowWaiters: [CheckedContinuation<Data?, Error>] = []
        var shouldCancel = false
        lock.withLock {
            guard terminal == nil else { return }
            guard acceptedBytes <= maximumResponseBytes - data.count else {
                terminal = .failure(OpenRouterDecisionsError.responseTooLarge)
                overflowWaiters = waiters
                waiters.removeAll()
                cancelCount += 1
                shouldCancel = true
                return
            }
            acceptedBytes += data.count
            if !waiters.isEmpty { waiter = waiters.removeFirst() }
            else { chunks.append(data) }
        }
        if shouldCancel {
            cancelTask()
            overflowWaiters.forEach { $0.resume(throwing: OpenRouterDecisionsError.responseTooLarge) }
        } else {
            waiter?.resume(returning: data)
        }
    }

    func nextChunk() async throws -> Data? {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var chunk: Data?
                var completion: Terminal?
                lock.withLock {
                    if !chunks.isEmpty { chunk = chunks.removeFirst() }
                    else if let terminal { completion = terminal }
                    else { waiters.append(continuation) }
                }
                if let chunk { continuation.resume(returning: chunk) }
                else if let completion {
                    switch completion {
                    case .success: continuation.resume(returning: nil)
                    case .failure(let error): continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: { [weak self] in self?.cancel() }
    }

    func finish(_ error: Error?) {
        var pending: [CheckedContinuation<Data?, Error>] = []
        var resolved: Terminal?
        lock.withLock {
            guard terminal == nil else { return }
            resolved = error.map(Terminal.failure) ?? .success
            terminal = resolved
            pending = waiters
            waiters.removeAll()
        }
        guard let resolved else { return }
        pending.forEach {
            switch resolved {
            case .success: $0.resume(returning: nil)
            case .failure(let error): $0.resume(throwing: error)
            }
        }
    }

    func fail(_ error: Error) {
        var pending: [CheckedContinuation<Data?, Error>] = []
        var shouldCancel = false
        lock.withLock {
            guard terminal == nil else { return }
            terminal = .failure(error)
            pending = waiters
            waiters.removeAll()
            cancelCount += 1
            shouldCancel = true
        }
        if shouldCancel {
            cancelTask()
            pending.forEach { $0.resume(throwing: error) }
        }
    }

    func cancel() {
        var pending: [CheckedContinuation<Data?, Error>] = []
        var shouldCancel = false
        lock.withLock {
            guard terminal == nil else { return }
            terminal = .failure(CancellationError())
            pending = waiters
            waiters.removeAll()
            cancelCount += 1
            shouldCancel = true
        }
        if shouldCancel {
            cancelTask()
            pending.forEach { $0.resume(throwing: CancellationError()) }
        }
    }

    func snapshot() -> DecisionsDelegateSnapshot {
        lock.withLock {
            .init(
                acceptedBytes: acceptedBytes,
                queuedChunkCount: chunks.count,
                cancelCount: cancelCount
            )
        }
    }
}

struct DecisionsTransportTaskIdentity: Hashable, Sendable {
    private let session: ObjectIdentifier
    let taskIdentifier: Int

    init(session: AnyObject, taskIdentifier: Int) {
        self.session = ObjectIdentifier(session)
        self.taskIdentifier = taskIdentifier
    }
}

final class DecisionsTransportContextRegistry<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [DecisionsTransportTaskIdentity: Value] = [:]

    func insert(_ value: Value, session: AnyObject, taskIdentifier: Int) {
        lock.withLock { values[.init(session: session, taskIdentifier: taskIdentifier)] = value }
    }

    func lookup(session: AnyObject, taskIdentifier: Int) -> Value? {
        lock.withLock { values[.init(session: session, taskIdentifier: taskIdentifier)] }
    }

    func remove(session: AnyObject, taskIdentifier: Int) -> Value? {
        lock.withLock { values.removeValue(forKey: .init(session: session, taskIdentifier: taskIdentifier)) }
    }

    func withValue<Result>(
        session: AnyObject,
        taskIdentifier: Int,
        _ body: (Value) -> Result
    ) -> Result? {
        lock.withLock {
            guard let value = values[.init(session: session, taskIdentifier: taskIdentifier)] else {
                return nil
            }
            return body(value)
        }
    }
}

final class URLSessionDecisionsStreamingTransport: NSObject, URLSessionDecisionsStreamingTransportContract,
    URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private final class TaskCanceller: @unchecked Sendable {
        weak var task: URLSessionTask?
        func cancel() { task?.cancel() }
    }

    private final class RequestContext: @unchecked Sendable {
        let state: DecisionsDelegateState
        let session: URLSession
        var responseContinuation: CheckedContinuation<DecisionsResponseStream, Error>?
        var deadlineTask: Task<Void, Never>?
        var completionError: Error?

        init(state: DecisionsDelegateState, session: URLSession) {
            self.state = state
            self.session = session
        }
    }

    private let time: any ContextualMonotonicTime
    private let contexts = DecisionsTransportContextRegistry<RequestContext>()

    init(time: any ContextualMonotonicTime) { self.time = time }

    func open(
        _ request: URLRequest,
        maximumResponseBytes: Int,
        deadline: ContextualInstant
    ) async throws -> DecisionsResponseStream {
        guard deadline > time.now() else { throw OpenRouterDecisionsError.timedOut }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.httpShouldSetCookies = false
        let remaining = max(0.001, seconds(deadline.offset - time.now().offset))
        configuration.timeoutIntervalForRequest = remaining
        configuration.timeoutIntervalForResource = remaining
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let canceller = TaskCanceller()
        let state = DecisionsDelegateState(maximumResponseBytes: maximumResponseBytes) {
            canceller.cancel()
        }
        let task = session.dataTask(with: request)
        canceller.task = task
        let context = RequestContext(state: state, session: session)
        contexts.insert(context, session: session, taskIdentifier: task.taskIdentifier)
        context.deadlineTask = Task { [weak self, weak state, time] in
            do {
                try await time.sleep(until: deadline)
                self?.contexts.withValue(session: session, taskIdentifier: task.taskIdentifier) {
                    $0.completionError = OpenRouterDecisionsError.timedOut
                }
                state?.fail(OpenRouterDecisionsError.timedOut)
            } catch { }
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                context.responseContinuation = continuation
                task.resume()
            }
        } onCancel: { state.cancel() }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        var continuation: CheckedContinuation<DecisionsResponseStream, Error>?
        let context = contexts.withValue(session: session, taskIdentifier: dataTask.taskIdentifier) { context in
            continuation = context.responseContinuation
            context.responseContinuation = nil
            return context
        }
        guard let context, let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            continuation?.resume(throwing: OpenRouterDecisionsError.transportUnavailable)
            return
        }
        let state = context.state
        continuation?.resume(returning: .init(
            response: http,
            nextChunk: { try await state.nextChunk() },
            cancel: { state.cancel() }
        ))
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        contexts.lookup(session: session, taskIdentifier: dataTask.taskIdentifier)?.state.receive(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let context = contexts.remove(session: session, taskIdentifier: task.taskIdentifier)
        context?.deadlineTask?.cancel()
        if let continuation = context?.responseContinuation {
            context?.responseContinuation = nil
            continuation.resume(throwing:
                context?.completionError ?? error ?? OpenRouterDecisionsError.transportUnavailable
            )
        }
        context?.state.finish(context?.completionError ?? error)
        session.finishTasksAndInvalidate()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        let context = contexts.withValue(session: session, taskIdentifier: task.taskIdentifier) { context in
            context.completionError = OpenRouterDecisionsError.redirected
            return context
        }
        context?.state.fail(OpenRouterDecisionsError.redirected)
        completionHandler(nil)
    }

    private func seconds(_ duration: Duration) -> TimeInterval {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

protocol OpenRouterDecisionsClientContract:
    ContextualDecisionProvider, SyntheticDiagnosticDecisionProvider {
    init(
        transport: any DecisionsStreamingTransport,
        credential: @escaping @Sendable () throws -> String
    )
}

actor OpenRouterDecisionsClient: OpenRouterDecisionsClientContract {
    static let endpoint = URL(string: "https://openrouter.ai/api/alpha/decisions")!
    static let model = "typesafe/jev-1.14"
    static let maximumResponseBytes = 64 * 1_024
    static let maximumRequestBytes = 4_096

    private let transport: any DecisionsStreamingTransport
    private let credential: @Sendable () throws -> String
    private let beforeTransportOpen: @Sendable () async -> Bool
    private let onFailure: @Sendable (Error) async -> Void

    init(
        transport: any DecisionsStreamingTransport,
        credential: @escaping @Sendable () throws -> String
    ) {
        self.transport = transport
        self.credential = credential
        beforeTransportOpen = { true }
        onFailure = { _ in }
    }

    init(
        transport: any DecisionsStreamingTransport,
        credential: @escaping @Sendable () throws -> String,
        beforeTransportOpen: @escaping @Sendable () async -> Bool,
        onFailure: @escaping @Sendable (Error) async -> Void = { _ in }
    ) {
        self.transport = transport
        self.credential = credential
        self.beforeTransportOpen = beforeTransportOpen
        self.onFailure = onFailure
    }

    func decide(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant
    ) async throws -> ContextualDecisionReceipt {
        do {
            return try await perform(
                sentence: sentence,
                language: language,
                occurrences: occurrences,
                deadline: deadline,
                beforeTransportOpen: beforeTransportOpen
            )
        } catch {
            await onFailure(error)
            throw error
        }
    }

    func decideSynthetic(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant,
        beforeTransportOpen: @escaping @Sendable () async -> Bool
    ) async throws -> ContextualDecisionReceipt {
        try await perform(
            sentence: sentence,
            language: language,
            occurrences: occurrences,
            deadline: deadline,
            beforeTransportOpen: beforeTransportOpen
        )
    }

    private func perform(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence],
        deadline: ContextualInstant,
        beforeTransportOpen: @escaping @Sendable () async -> Bool
    ) async throws -> ContextualDecisionReceipt {
        let key = try credential()
        guard !key.isEmpty else { throw OpenRouterDecisionsError.missingCredential }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.requestBody(
            sentence: sentence,
            language: language,
            occurrences: occurrences
        )
        guard await beforeTransportOpen() else {
            throw OpenRouterDecisionsError.authorizationInvalidated
        }
        let stream: DecisionsResponseStream
        do {
            stream = try await transport.open(
                request,
                maximumResponseBytes: Self.maximumResponseBytes,
                deadline: deadline
            )
        } catch is CancellationError {
            throw OpenRouterDecisionsError.cancelled
        } catch let error as OpenRouterDecisionsError {
            throw error
        } catch {
            throw OpenRouterDecisionsError.transportUnavailable
        }
        guard stream.response.statusCode == 200 else {
            stream.cancel()
            if (300..<400).contains(stream.response.statusCode) {
                throw OpenRouterDecisionsError.redirected
            }
            throw OpenRouterDecisionsError.invalidStatus(stream.response.statusCode)
        }
        var body = Data()
        do {
            try await withTaskCancellationHandler {
                while let chunk = try await stream.nextChunk() {
                    guard body.count <= Self.maximumResponseBytes - chunk.count else {
                        stream.cancel()
                        throw OpenRouterDecisionsError.responseTooLarge
                    }
                    body.append(chunk)
                }
            } onCancel: { stream.cancel() }
        } catch is CancellationError {
            throw OpenRouterDecisionsError.cancelled
        } catch let error as OpenRouterDecisionsError {
            throw error
        } catch {
            throw OpenRouterDecisionsError.transportUnavailable
        }
        return try Self.receipt(from: body, occurrences: occurrences)
    }

    static func requestDTO(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence]
    ) -> DecisionsRequestDTO {
        let stateOccurrences = occurrences.map {
            DecisionsRequestDTO.State.Occurrence(
                heard: $0.heard,
                canonical: $0.canonical,
                ordinal: $0.ordinal
            )
        }
        let questions = Dictionary(uniqueKeysWithValues: occurrences.map { occurrence in
            (occurrence.questionID, DecisionsRequestDTO.Question(
                type: "choice",
                instructions: "Escolha a forma correta para a ocorrência \(occurrence.ordinal) no contexto.",
                criteria: [
                    ContextualDecisionChoice.keepOriginal.rawValue: "Manter exatamente a forma ouvida no contexto.",
                    ContextualDecisionChoice.replace.rawValue: "Aplicar somente a correção local confirmada."
                ]
            ))
        })
        return .init(
            model: model,
            state: .init(language: language, text: sentence, occurrences: stateOccurrences),
            questions: questions
        )
    }

    static func requestBody(
        sentence: String,
        language: String,
        occurrences: [ContextualCorrectionOccurrence]
    ) throws -> Data {
        let body = try JSONEncoder().encode(requestDTO(
            sentence: sentence,
            language: language,
            occurrences: occurrences
        ))
        guard body.count <= maximumRequestBytes else {
            throw OpenRouterDecisionsError.requestTooLarge
        }
        return body
    }

    static func receipt(
        from data: Data,
        occurrences: [ContextualCorrectionOccurrence]
    ) throws -> ContextualDecisionReceipt {
        let response: DecisionsResponseDTO
        do { response = try JSONDecoder().decode(DecisionsResponseDTO.self, from: data) }
        catch { throw OpenRouterDecisionsError.malformedResponse }
        guard response.model == model || response.model.hasPrefix("\(model)-"),
              Set(response.answers.keys) == Set(occurrences.map(\.questionID)) else {
            throw OpenRouterDecisionsError.malformedResponse
        }
        var decisions: [ContextualDecision] = []
        for occurrence in occurrences {
            guard let answer = response.answers[occurrence.questionID],
                  answer.type == "choice",
                  let choice = ContextualDecisionChoice(rawValue: answer.choice),
                  Set(answer.probabilities.keys) == Set([
                    ContextualDecisionChoice.keepOriginal.rawValue,
                    ContextualDecisionChoice.replace.rawValue
                  ]),
                  let selected = answer.probabilities[choice.rawValue],
                  let runnerUp = answer.probabilities.first(where: { $0.key != choice.rawValue })?.value else {
                throw OpenRouterDecisionsError.malformedResponse
            }
            decisions.append(.init(
                questionID: occurrence.questionID,
                choice: choice,
                confidence: answer.confidence,
                chosenProbability: selected,
                runnerUpProbability: runnerUp
            ))
        }
        return .init(
            decisions: decisions,
            resolvedModel: response.model,
            inputTokens: response.usage?.inputTokens,
            outputTokens: response.usage?.outputTokens,
            costUSD: response.usage?.cost
        )
    }
}

protocol ContextualCredentialStore: Sendable {
    func save(_ value: String) throws
    func load() throws -> String?
    func delete() throws
}

enum KeychainContextualCredentialConstants {
    static let service = "br.com.luisroquette.Resenha.contextual-corrections"
    static let syntheticAccount = "openrouter-synthetic-diagnostic"
    static let personalAccount = "openrouter-personal-context"
}

enum ContextualCredentialError: Error, Equatable, Sendable {
    case invalidValue
    case keychainStatus(OSStatus)
}

struct KeychainContextualCredentialStore: ContextualCredentialStore {
    let account: String

    init(account: String = KeychainContextualCredentialConstants.syntheticAccount) {
        self.account = account
    }

    func save(_ value: String) throws {
        guard !value.isEmpty, let data = value.data(using: .utf8) else {
            throw ContextualCredentialError.invalidValue
        }
        let query = baseQuery
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else {
            throw ContextualCredentialError.keychainStatus(update)
        }
        var insert = query
        insert[kSecValueData] = data
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ContextualCredentialError.keychainStatus(status)
        }
    }

    func load() throws -> String? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            throw status == errSecSuccess
                ? ContextualCredentialError.invalidValue
                : ContextualCredentialError.keychainStatus(status)
        }
        return value
    }

    func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ContextualCredentialError.keychainStatus(status)
        }
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: KeychainContextualCredentialConstants.service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false
        ]
    }
}

enum SyntheticDiagnosticGuardState: String, Codable, Sendable {
    case available
    case consumed
}

enum SyntheticDiagnosticGuardHealth: Equatable, Sendable {
    case ready(SyntheticDiagnosticGuardState)
    case blocked
}

enum SyntheticDiagnosticGuardError: Error, Equatable, Sendable {
    case unavailable
    case blocked
    case consumed
    case corrupt
    case oversized
    case unsupportedVersion
    case uncertainWrite
}

protocol SyntheticDiagnosticGuardStore: Sendable {
    func validateForAuthorization() async throws
    func provisionAuthorizedCall() async throws
    func consume() async throws
    func currentState() async -> SyntheticDiagnosticGuardHealth
}

protocol ContextualFileOperating: Sendable {
    func fileExists(at url: URL) -> Bool
    func createDirectory(at url: URL) throws
    func read(_ url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
    func setPermissions(_ permissions: Int, at url: URL) throws
    func replace(_ destination: URL, with source: URL) throws
    func remove(_ url: URL) throws
}

struct ContextualFileOperations: ContextualFileOperating {
    func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    func read(_ url: URL) throws -> Data { try Data(contentsOf: url, options: [.mappedIfSafe]) }
    func write(_ data: Data, to url: URL) throws { try data.write(to: url, options: .atomic) }
    func setPermissions(_ permissions: Int, at url: URL) throws {
        try FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
    }
    func replace(_ destination: URL, with source: URL) throws {
        _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
    }
    func remove(_ url: URL) throws { try FileManager.default.removeItem(at: url) }
}

actor SyntheticDiagnosticGuard: SyntheticDiagnosticGuardStore {
    private struct MarkerEnvelope: Codable, Equatable {
        let schemaVersion: Int
        let provisioned: Bool
    }

    private struct StateEnvelope: Codable, Equatable {
        let schemaVersion: Int
        let state: SyntheticDiagnosticGuardState
    }

    private enum Inspection {
        case absent
        case ready(SyntheticDiagnosticGuardState)
        case blocked
    }

    static let schemaVersion = 1
    static let maximumFileBytes = 64 * 1_024

    private let directoryURL: URL
    private let files: any ContextualFileOperating
    private var permanentlyBlocked = false

    init(
        directoryURL: URL = SyntheticDiagnosticGuard.defaultDirectoryURL(),
        files: any ContextualFileOperating = ContextualFileOperations()
    ) {
        self.directoryURL = directoryURL
        self.files = files
    }

    nonisolated static func defaultDirectoryURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Resenha", isDirectory: true)
            .appendingPathComponent("ContextualCorrections", isDirectory: true)
    }

    func validateForAuthorization() throws {
        switch try inspect() {
        case .absent, .ready(.available): return
        case .ready(.consumed): throw SyntheticDiagnosticGuardError.consumed
        case .blocked: throw SyntheticDiagnosticGuardError.blocked
        }
    }

    func provisionAuthorizedCall() throws {
        switch try inspect() {
        case .ready(.available): return
        case .ready(.consumed): throw SyntheticDiagnosticGuardError.consumed
        case .blocked: throw SyntheticDiagnosticGuardError.blocked
        case .absent:
            do {
                try prepareDirectory()
                try verifiedWrite(
                    MarkerEnvelope(schemaVersion: Self.schemaVersion, provisioned: true),
                    to: markerURL
                )
                try verifiedWrite(
                    StateEnvelope(schemaVersion: Self.schemaVersion, state: .available),
                    to: stateURL
                )
                guard case .ready(.available) = try inspect() else {
                    throw SyntheticDiagnosticGuardError.uncertainWrite
                }
            } catch {
                permanentlyBlocked = true
                throw error
            }
        }
    }

    func consume() throws {
        guard case .ready(.available) = try inspect() else {
            throw SyntheticDiagnosticGuardError.blocked
        }
        let transaction = directoryURL.appendingPathComponent(
            ".diagnostic-consumed-\(UUID().uuidString).tmp"
        )
        do {
            let envelope = StateEnvelope(schemaVersion: Self.schemaVersion, state: .consumed)
            let data = try JSONEncoder().encode(envelope)
            try files.write(data, to: transaction)
            try files.setPermissions(0o600, at: transaction)
            guard try decodeState(try boundedRead(transaction)) == envelope else {
                throw SyntheticDiagnosticGuardError.uncertainWrite
            }
            try files.replace(stateURL, with: transaction)
            try files.setPermissions(0o600, at: stateURL)
            guard try decodeState(try boundedRead(stateURL)) == envelope else {
                throw SyntheticDiagnosticGuardError.uncertainWrite
            }
        } catch {
            permanentlyBlocked = true
            try? files.remove(transaction)
            throw error
        }
    }

    func currentState() -> SyntheticDiagnosticGuardHealth {
        guard !permanentlyBlocked else { return .blocked }
        do {
            switch try inspect() {
            case .ready(let state): return .ready(state)
            case .absent, .blocked: return .blocked
            }
        } catch {
            permanentlyBlocked = true
            return .blocked
        }
    }

    private var markerURL: URL {
        directoryURL.appendingPathComponent("diagnostic-authorization-provisioned-v1.json")
    }

    private var stateURL: URL {
        directoryURL.appendingPathComponent("diagnostic-authorization-v1.json")
    }

    private func inspect() throws -> Inspection {
        if permanentlyBlocked { return .blocked }
        let markerExists = files.fileExists(at: markerURL)
        let stateExists = files.fileExists(at: stateURL)
        guard markerExists || stateExists else { return .absent }
        guard markerExists && stateExists else { return .blocked }
        do {
            let marker = try JSONDecoder().decode(
                MarkerEnvelope.self,
                from: boundedRead(markerURL)
            )
            guard marker.schemaVersion == Self.schemaVersion, marker.provisioned else {
                return .blocked
            }
            let state = try decodeState(boundedRead(stateURL))
            guard state.schemaVersion == Self.schemaVersion else { return .blocked }
            return .ready(state.state)
        } catch {
            permanentlyBlocked = true
            throw error
        }
    }

    private func prepareDirectory() throws {
        do {
            try files.createDirectory(at: directoryURL)
            try files.setPermissions(0o700, at: directoryURL)
        } catch { throw SyntheticDiagnosticGuardError.unavailable }
    }

    private func verifiedWrite<Value: Codable & Equatable>(_ value: Value, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        guard data.count <= Self.maximumFileBytes else { throw SyntheticDiagnosticGuardError.oversized }
        try files.write(data, to: url)
        try files.setPermissions(0o600, at: url)
        let decoded = try JSONDecoder().decode(Value.self, from: boundedRead(url))
        guard decoded == value else { throw SyntheticDiagnosticGuardError.uncertainWrite }
    }

    private func boundedRead(_ url: URL) throws -> Data {
        let data: Data
        do { data = try files.read(url) }
        catch { throw SyntheticDiagnosticGuardError.unavailable }
        guard data.count <= Self.maximumFileBytes else { throw SyntheticDiagnosticGuardError.oversized }
        return data
    }

    private func decodeState(_ data: Data) throws -> StateEnvelope {
        do { return try JSONDecoder().decode(StateEnvelope.self, from: data) }
        catch { throw SyntheticDiagnosticGuardError.corrupt }
    }
}

@MainActor
protocol ContextualOptInStore: AnyObject {
    var contextualCorrectionsEnabled: Bool { get }
    func persistContextualCorrectionsEnabled(_ enabled: Bool) throws
}

@MainActor
protocol PersonalRemoteOptInStore: AnyObject {
    var contextualCorrectionsEnabled: Bool { get }
    var personalRemoteEnabled: Bool { get }
    func persistPersonalRemoteEnabled(_ enabled: Bool) throws
}

@MainActor
protocol PersonalRemoteAuthorizationStateStore: AnyObject {
    func loadAuthorizedEpoch() throws -> UUID?
    func persistAuthorizedEpoch(_ epoch: UUID) throws
    func persistRevoked() throws
}

@MainActor
final class UserDefaultsPersonalRemoteAuthorizationStateStore:
    PersonalRemoteAuthorizationStateStore
{
    private static let key = "resenha.personalRemoteAuthorizationState"
    private static let revoked = "revoked"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadAuthorizedEpoch() throws -> UUID? {
        guard let value = defaults.object(forKey: Self.key) else { return nil }
        guard let value = value as? String else {
            throw PersonalRemoteAuthorizationError.durableStateUnavailable
        }
        if value == Self.revoked { return nil }
        guard value.hasPrefix("authorized:"),
              let epoch = UUID(uuidString: String(value.dropFirst("authorized:".count))) else {
            throw PersonalRemoteAuthorizationError.durableStateUnavailable
        }
        return epoch
    }

    func persistAuthorizedEpoch(_ epoch: UUID) throws {
        try persistAndVerify("authorized:\(epoch.uuidString)")
    }

    func persistRevoked() throws {
        try persistAndVerify(Self.revoked)
    }

    private func persistAndVerify(_ value: String) throws {
        defaults.set(value, forKey: Self.key)
        guard defaults.object(forKey: Self.key) as? String == value else {
            throw PersonalRemoteAuthorizationError.durableStateUnavailable
        }
    }
}

struct PersonalRemoteAuthorizationHealth: Equatable, Sendable {
    let releaseDecision: PersonalRemoteReleaseDecision
    let enabled: Bool
    let credentialPresent: Bool
    let locallyEligible: Bool
    let durablyAuthorized: Bool
    let revokedInProcess: Bool

    var canDispatch: Bool {
        releaseDecision == .personalRemoteAvailable
            && enabled && credentialPresent && locallyEligible && durablyAuthorized
            && !revokedInProcess
    }
}

enum PersonalRemoteAuthorizationError: Error, Equatable, Sendable {
    case consentRequired
    case credentialUnverified
    case durableStateUnavailable
    case locallyIneligible
    case releaseUnavailable
}

@MainActor
protocol PersonalRemoteAuthorizationManaging: AnyObject {
    func authorizePersonalRemote(explicitConsent: Bool, credential: String) throws
    func revokePersonalRemote() throws
    func personalRemoteHealth() -> PersonalRemoteAuthorizationHealth
}

@MainActor
final class PersonalRemoteAuthorizationOwner: PersonalRemoteAuthorizationManaging {
    private let optInStore: any PersonalRemoteOptInStore
    private let credentialStore: any ContextualCredentialStore
    private let authorizationStateStore: any PersonalRemoteAuthorizationStateStore
    private let policy: ContextualCorrectionPolicy
    private let storeSnapshot: @MainActor @Sendable () -> ContextualCorrectionStoreSnapshot
    private var revokedInProcess = false

    init(
        optInStore: any PersonalRemoteOptInStore,
        credentialStore: any ContextualCredentialStore,
        authorizationStateStore: any PersonalRemoteAuthorizationStateStore,
        policy: ContextualCorrectionPolicy,
        storeSnapshot: @escaping @MainActor @Sendable () -> ContextualCorrectionStoreSnapshot
    ) {
        self.optInStore = optInStore
        self.credentialStore = credentialStore
        self.authorizationStateStore = authorizationStateStore
        self.policy = policy
        self.storeSnapshot = storeSnapshot
    }

    func authorizePersonalRemote(explicitConsent: Bool, credential: String) throws {
        guard PersonalRemoteReleaseDecision.current == .personalRemoteAvailable else {
            throw PersonalRemoteAuthorizationError.releaseUnavailable
        }
        guard explicitConsent else { throw PersonalRemoteAuthorizationError.consentRequired }
        guard isLocallyEligible else { throw PersonalRemoteAuthorizationError.locallyIneligible }
        revokedInProcess = true
        policy.invalidate(.authorityChanged)
        do {
            try authorizationStateStore.persistRevoked()
            try credentialStore.save(credential)
            guard try credentialStore.load() == credential else {
                throw PersonalRemoteAuthorizationError.credentialUnverified
            }
            try optInStore.persistPersonalRemoteEnabled(true)
            guard optInStore.personalRemoteEnabled else {
                throw PersonalRemoteAuthorizationError.credentialUnverified
            }
            let epoch = UUID()
            try authorizationStateStore.persistAuthorizedEpoch(epoch)
            guard try authorizationStateStore.loadAuthorizedEpoch() == epoch else {
                throw PersonalRemoteAuthorizationError.durableStateUnavailable
            }
            revokedInProcess = false
            policy.invalidate(.authorityChanged)
        } catch {
            revokedInProcess = true
            try? authorizationStateStore.persistRevoked()
            try? optInStore.persistPersonalRemoteEnabled(false)
            try? credentialStore.delete()
            policy.invalidate(.authorityChanged)
            throw error
        }
    }

    func revokePersonalRemote() throws {
        revokedInProcess = true
        policy.invalidate(.authorityChanged)
        var firstError: Error?
        do { try authorizationStateStore.persistRevoked() }
        catch { firstError = error }
        do { try optInStore.persistPersonalRemoteEnabled(false) }
        catch { if firstError == nil { firstError = error } }
        do { try credentialStore.delete() }
        catch { if firstError == nil { firstError = error } }
        let credentialStillPresent: Bool
        do { credentialStillPresent = try credentialStore.load() != nil }
        catch {
            credentialStillPresent = true
            if firstError == nil { firstError = error }
        }
        let durableStillAuthorized: Bool
        do { durableStillAuthorized = try authorizationStateStore.loadAuthorizedEpoch() != nil }
        catch {
            durableStillAuthorized = true
            if firstError == nil { firstError = error }
        }
        guard !optInStore.personalRemoteEnabled, !credentialStillPresent,
              !durableStillAuthorized, firstError == nil else {
            throw firstError ?? PersonalRemoteAuthorizationError.credentialUnverified
        }
    }

    func personalRemoteHealth() -> PersonalRemoteAuthorizationHealth {
        let credential = (try? credentialStore.load()) ?? nil
        let durablyAuthorized: Bool
        do { durablyAuthorized = try authorizationStateStore.loadAuthorizedEpoch() != nil }
        catch { durablyAuthorized = false }
        return .init(
            releaseDecision: .current,
            enabled: optInStore.personalRemoteEnabled,
            credentialPresent: credential?.isEmpty == false,
            locallyEligible: isLocallyEligible,
            durablyAuthorized: durablyAuthorized,
            revokedInProcess: revokedInProcess
        )
    }

    func issueToken() -> ContextualPolicyToken {
        policy.issueToken(scope: personalRemoteHealth().canDispatch ? .personalDictation : .disabled)
    }

    func handleProviderError(_ error: Error) {
        guard case OpenRouterDecisionsError.invalidStatus(let status) = error,
              [401, 402, 403, 429].contains(status) else { return }
        try? revokePersonalRemote()
    }

    private var isLocallyEligible: Bool {
        let snapshot = storeSnapshot()
        return optInStore.contextualCorrectionsEnabled
            && snapshot.health == .healthy && !snapshot.examples.isEmpty
    }
}

struct SyntheticDiagnosticAuthorizationHealth: Equatable, Sendable {
    let localBetaEnabled: Bool
    let diagnosticArmed: Bool
    let guardHealth: SyntheticDiagnosticGuardHealth
}

@MainActor
protocol SyntheticDiagnosticAuthorizationChecking: AnyObject {
    func consumeForDispatch(token: ContextualPolicyToken) async throws
    func currentHealth() async -> SyntheticDiagnosticAuthorizationHealth
}

@MainActor
protocol SyntheticDiagnosticAuthorizationManaging: AnyObject {
    func setLocalBetaEnabled(_ enabled: Bool) async throws
    func authorizeSyntheticDiagnostic(explicitConsent: Bool, credential: String) async throws
    func removeSyntheticDiagnosticCredential() async throws
}

@MainActor
protocol SyntheticDiagnosticAuthorizationOwnerContract:
    SyntheticDiagnosticAuthorizationManaging, SyntheticDiagnosticAuthorizationChecking {
    init(
        optInStore: any ContextualOptInStore,
        credentialStore: any ContextualCredentialStore,
        guardStore: any SyntheticDiagnosticGuardStore,
        policy: ContextualCorrectionPolicy
    )
}

enum SyntheticDiagnosticAuthorizationError: Error, Equatable, Sendable {
    case consentRequired
    case credentialUnverified
    case guardUnavailable
    case stalePolicy
    case diagnosticNotArmed
    case localBetaDisabled
}

@MainActor
final class SyntheticDiagnosticAuthorizationOwner: SyntheticDiagnosticAuthorizationOwnerContract {
    private let optInStore: any ContextualOptInStore
    private let credentialStore: any ContextualCredentialStore
    private let guardStore: any SyntheticDiagnosticGuardStore
    private let policy: ContextualCorrectionPolicy
    private(set) var diagnosticArmed = false

    init(
        optInStore: any ContextualOptInStore,
        credentialStore: any ContextualCredentialStore,
        guardStore: any SyntheticDiagnosticGuardStore,
        policy: ContextualCorrectionPolicy
    ) {
        self.optInStore = optInStore
        self.credentialStore = credentialStore
        self.guardStore = guardStore
        self.policy = policy
    }

    func setLocalBetaEnabled(_ enabled: Bool) async throws {
        try optInStore.persistContextualCorrectionsEnabled(enabled)
        guard optInStore.contextualCorrectionsEnabled == enabled else {
            throw SyntheticDiagnosticAuthorizationError.localBetaDisabled
        }
        if !enabled {
            diagnosticArmed = false
            policy.invalidate(.optedOut)
        }
    }

    func authorizeSyntheticDiagnostic(explicitConsent: Bool, credential: String) async throws {
        guard explicitConsent else { throw SyntheticDiagnosticAuthorizationError.consentRequired }
        do {
            try await guardStore.validateForAuthorization()
            try credentialStore.save(credential)
            guard try credentialStore.load() == credential else {
                throw SyntheticDiagnosticAuthorizationError.credentialUnverified
            }
            try await guardStore.provisionAuthorizedCall()
            guard await guardStore.currentState() == .ready(.available) else {
                throw SyntheticDiagnosticAuthorizationError.guardUnavailable
            }
            diagnosticArmed = true
        } catch {
            diagnosticArmed = false
            policy.invalidate(.credentialDeleted)
            try? credentialStore.delete()
            throw error
        }
    }

    func removeSyntheticDiagnosticCredential() async throws {
        diagnosticArmed = false
        policy.invalidate(.credentialDeleted)
        try credentialStore.delete()
        guard try credentialStore.load() == nil else {
            throw SyntheticDiagnosticAuthorizationError.credentialUnverified
        }
    }

    func consumeForDispatch(token: ContextualPolicyToken) async throws {
        guard token.scope == .syntheticDiagnostic,
              policy.isCurrent(token),
              diagnosticArmed else {
            throw SyntheticDiagnosticAuthorizationError.diagnosticNotArmed
        }
        diagnosticArmed = false
        guard optInStore.contextualCorrectionsEnabled,
              let credential = try credentialStore.load(),
              !credential.isEmpty,
              policy.isCurrent(token) else {
            throw SyntheticDiagnosticAuthorizationError.credentialUnverified
        }
        try await guardStore.consume()
        guard policy.isCurrent(token) else {
            throw SyntheticDiagnosticAuthorizationError.stalePolicy
        }
    }

    func currentHealth() async -> SyntheticDiagnosticAuthorizationHealth {
        .init(
            localBetaEnabled: optInStore.contextualCorrectionsEnabled,
            diagnosticArmed: diagnosticArmed,
            guardHealth: await guardStore.currentState()
        )
    }
}

struct SyntheticDiagnosticFixture: Decodable, Equatable, Sendable {
    static let id = "pt-rosto-hostel-diagnostic-001"

    let id: String
    let pairID: String
    let learningExampleIDs: [String]
    let language: String
    let input: String
    let heard: String
    let canonical: String
    let ordinal: Int
    let expected: String

    static func load(from bundle: Bundle = .main) throws -> Self {
        struct Envelope: Decodable {
            let schemaVersion: Int
            let diagnosticFixture: SyntheticDiagnosticFixture
        }
        guard bundle.bundleIdentifier == "br.com.luisroquette.Resenha",
              let url = bundle.url(forResource: "contextual-corrections", withExtension: "json") else {
            throw SyntheticDiagnosticError.invalidResponse
        }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url)) }
        catch { throw SyntheticDiagnosticError.invalidResponse }
        guard envelope.schemaVersion == 1, envelope.diagnosticFixture.id == id else {
            throw SyntheticDiagnosticError.invalidResponse
        }
        return envelope.diagnosticFixture
    }
}

enum SyntheticDiagnosticError: Error, Equatable, Sendable {
    case authorizationUnavailable
    case timedOut
    case providerRejected
    case transportUnavailable
    case invalidResponse
    case cancelled
}

struct SyntheticDiagnosticResult: Equatable, Sendable {
    let outcome: ValidatedContextualOutcome
    let receipt: ContextualDecisionReceipt
    let durationMilliseconds: Int
    let callCount: Int
}

@MainActor
private final class ContextualCancellableTaskBox {
    var task: Task<ContextualDecisionReceipt, Error>?
    private(set) var cancelled = false

    func install(_ task: Task<ContextualDecisionReceipt, Error>) {
        self.task = task
        if cancelled { task.cancel() }
    }

    func cancel() {
        cancelled = true
        task?.cancel()
    }
}

@MainActor
protocol SyntheticDiagnosticControllerContract: ObservableObject {
    init(
        policy: ContextualCorrectionPolicy,
        authorization: any SyntheticDiagnosticAuthorizationChecking,
        client: any SyntheticDiagnosticDecisionProvider,
        validator: ContextualDecisionValidator,
        fixture: SyntheticDiagnosticFixture,
        time: any ContextualMonotonicTime
    )
    func run() async throws -> SyntheticDiagnosticResult
}

@MainActor
final class SyntheticDiagnosticController: SyntheticDiagnosticControllerContract {
    private let policy: ContextualCorrectionPolicy
    private let authorization: any SyntheticDiagnosticAuthorizationChecking
    private let client: any SyntheticDiagnosticDecisionProvider
    private let validator: ContextualDecisionValidator
    private let fixture: SyntheticDiagnosticFixture
    private let time: any ContextualMonotonicTime

    init(
        policy: ContextualCorrectionPolicy,
        authorization: any SyntheticDiagnosticAuthorizationChecking,
        client: any SyntheticDiagnosticDecisionProvider,
        validator: ContextualDecisionValidator,
        fixture: SyntheticDiagnosticFixture,
        time: any ContextualMonotonicTime
    ) {
        self.policy = policy
        self.authorization = authorization
        self.client = client
        self.validator = validator
        self.fixture = fixture
        self.time = time
    }

    func run() async throws -> SyntheticDiagnosticResult {
        let started = time.now()
        let deadline = ContextualInstant(offset: started.offset + .milliseconds(900))
        let token = policy.issueToken(scope: .syntheticDiagnostic)
        let taskBox = ContextualCancellableTaskBox()
        guard policy.register(token, cancel: { taskBox.cancel() }) else {
            throw SyntheticDiagnosticError.authorizationUnavailable
        }
        defer { policy.finish(token) }
        do {
            try await authorization.consumeForDispatch(token: token)
            guard policy.isCurrent(token), time.now() < deadline else {
                throw SyntheticDiagnosticError.authorizationUnavailable
            }
            let occurrences = try makeOccurrences()
            let policy = policy
            let client = client
            let task = Task {
                try await client.decideSynthetic(
                    sentence: fixture.input,
                    language: fixture.language,
                    occurrences: occurrences,
                    deadline: deadline,
                    beforeTransportOpen: {
                        await MainActor.run { policy.isCurrent(token) }
                    }
                )
            }
            taskBox.install(task)
            let receipt = try await task.value
            guard policy.isCurrent(token), time.now() < deadline else {
                throw SyntheticDiagnosticError.timedOut
            }
            let outcome = validator.validate(receipt: receipt, occurrences: occurrences)
            guard outcome.category != .abstained else {
                throw SyntheticDiagnosticError.invalidResponse
            }
            return .init(
                outcome: outcome,
                receipt: receipt,
                durationMilliseconds: Self.milliseconds(started.offset, time.now().offset),
                callCount: 1
            )
        } catch let error as SyntheticDiagnosticError {
            throw error
        } catch is CancellationError {
            throw SyntheticDiagnosticError.cancelled
        } catch let error as OpenRouterDecisionsError {
            switch error {
            case .timedOut: throw SyntheticDiagnosticError.timedOut
            case .invalidStatus(let status) where status == 401 || status == 402
                || status == 403 || status == 429 || status >= 500:
                throw SyntheticDiagnosticError.providerRejected
            case .transportUnavailable: throw SyntheticDiagnosticError.transportUnavailable
            case .cancelled: throw SyntheticDiagnosticError.cancelled
            case .malformedResponse, .responseTooLarge, .requestTooLarge:
                throw SyntheticDiagnosticError.invalidResponse
            default: throw SyntheticDiagnosticError.authorizationUnavailable
            }
        } catch is SyntheticDiagnosticAuthorizationError {
            throw SyntheticDiagnosticError.authorizationUnavailable
        } catch is SyntheticDiagnosticGuardError {
            throw SyntheticDiagnosticError.authorizationUnavailable
        } catch is ContextualCredentialError {
            throw SyntheticDiagnosticError.authorizationUnavailable
        } catch {
            throw SyntheticDiagnosticError.transportUnavailable
        }
    }

    private func makeOccurrences() throws -> [ContextualCorrectionOccurrence] {
        let escaped = NSRegularExpression.escapedPattern(for: fixture.heard)
        guard let regex = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive]
        ) else { throw SyntheticDiagnosticError.invalidResponse }
        let matches = regex.matches(
            in: fixture.input,
            range: NSRange(fixture.input.startIndex..<fixture.input.endIndex, in: fixture.input)
        )
        guard fixture.ordinal > 0, fixture.ordinal <= matches.count,
              let range = Range(matches[fixture.ordinal - 1].range, in: fixture.input) else {
            throw SyntheticDiagnosticError.invalidResponse
        }
        return [.init(
            questionID: "o1",
            heard: fixture.heard,
            canonical: fixture.canonical,
            ordinal: fixture.ordinal,
            range: range
        )]
    }

    private static func milliseconds(_ start: Duration, _ end: Duration) -> Int {
        let components = (end - start).components
        return Int(components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000)
    }
}
