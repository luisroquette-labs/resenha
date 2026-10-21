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
