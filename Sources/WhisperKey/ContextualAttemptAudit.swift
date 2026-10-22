import Combine
import Foundation

enum ContextualAttemptStatus: String, Codable, Sendable {
    case requested
    case succeeded
    case failed
}

enum ContextualAttemptDisposition: String, Codable, Sendable {
    case appliedReplacement
    case keptOriginal
    case discarded
}

enum ContextualAttemptFailure: String, Codable, Sendable {
    case authorization
    case rejected
    case timeout
    case cancelled
    case transport
    case invalidResponse
    case unknown

    init(_ error: Error) {
        guard let error = error as? OpenRouterDecisionsError else {
            self = .unknown
            return
        }
        self = switch error {
        case .missingCredential, .authorizationInvalidated: .authorization
        case .invalidStatus: .rejected
        case .timedOut: .timeout
        case .cancelled: .cancelled
        case .transportUnavailable, .redirected, .invalidEndpoint: .transport
        case .malformedResponse, .responseTooLarge, .requestTooLarge: .invalidResponse
        }
    }
}

struct ContextualAttemptRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let startedAt: Date
    var completedAt: Date?
    var status: ContextualAttemptStatus
    var resolvedModel: String?
    var decisions: [ContextualDecisionChoice]
    var minimumConfidence: Double?
    var minimumProbability: Double?
    var latencyMilliseconds: Int?
    var inputTokens: Int?
    var outputTokens: Int?
    var costUSD: Decimal?
    var providerRequestID: String? = nil
    var disposition: ContextualAttemptDisposition? = nil
    var failure: ContextualAttemptFailure?

    var providerResponseConfirmed: Bool { status == .succeeded }
}

enum ContextualProviderAttemptEvent: Sendable {
    case requested(id: UUID, at: Date)
    case succeeded(
        id: UUID, startedAt: Date, completedAt: Date,
        latencyMilliseconds: Int, receipt: ContextualDecisionReceipt
    )
    case failed(
        id: UUID, startedAt: Date, completedAt: Date,
        latencyMilliseconds: Int, failure: ContextualAttemptFailure
    )
    case resolved(id: UUID, disposition: ContextualAttemptDisposition)
}

@MainActor
final class ContextualAttemptStore: ObservableObject {
    static let maximumRecords = 20
    static let maximumFileBytes = 256 * 1_024
    private struct Envelope: Codable { let schemaVersion: Int; let records: [ContextualAttemptRecord] }

    @Published private(set) var records: [ContextualAttemptRecord] = []
    @Published private(set) var storageAvailable = true
    private let fileURL: URL
    private let fileManager: FileManager
    private var pendingDispositions: [UUID: ContextualAttemptDisposition] = [:]

    var latest: ContextualAttemptRecord? { records.last }

    init(fileURL: URL = ContextualAttemptStore.defaultURL(), fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        load()
    }

    func consume(_ event: ContextualProviderAttemptEvent) {
        switch event {
        case .requested(let id, let at):
            guard !records.contains(where: { $0.id == id }) else { return }
            records.removeAll { $0.id == id }
            records.append(.init(
                id: id, startedAt: at, completedAt: nil, status: .requested,
                resolvedModel: nil, decisions: [], minimumConfidence: nil,
                minimumProbability: nil, latencyMilliseconds: nil, inputTokens: nil,
                outputTokens: nil, costUSD: nil, failure: nil
            ))
        case .succeeded(let id, let startedAt, let completedAt, let latency, let receipt):
            update(id: id, startedAt: startedAt, completedAt: completedAt) { record in
                record.status = .succeeded
                record.resolvedModel = String(receipt.resolvedModel.prefix(128))
                record.decisions = Array(receipt.decisions.prefix(3)).map(\.choice)
                record.minimumConfidence = Self.probability(receipt.decisions.map(\.confidence).min())
                record.minimumProbability = Self.probability(receipt.decisions.map(\.chosenProbability).min())
                record.latencyMilliseconds = max(0, latency)
                record.inputTokens = receipt.inputTokens.flatMap { $0 >= 0 ? $0 : nil }
                record.outputTokens = receipt.outputTokens.flatMap { $0 >= 0 ? $0 : nil }
                record.costUSD = Self.cost(receipt.costUSD)
                record.providerRequestID = receipt.providerRequestID.map { String($0.prefix(128)) }
                record.disposition = pendingDispositions.removeValue(forKey: id)
                record.failure = nil
            }
        case .failed(let id, let startedAt, let completedAt, let latency, let failure):
            update(id: id, startedAt: startedAt, completedAt: completedAt) { record in
                record.status = .failed
                record.latencyMilliseconds = max(0, latency)
                record.failure = failure
            }
        case .resolved(let id, let disposition):
            guard let index = records.lastIndex(where: { $0.id == id && $0.status == .succeeded }) else {
                if pendingDispositions.count >= Self.maximumRecords,
                   let oldest = pendingDispositions.keys.first {
                    pendingDispositions.removeValue(forKey: oldest)
                }
                pendingDispositions[id] = disposition
                return
            }
            records[index].disposition = disposition
        }
        if records.count > Self.maximumRecords {
            records.removeFirst(records.count - Self.maximumRecords)
        }
        persist()
    }

    func deleteAll() {
        records = []
        pendingDispositions = [:]
        do {
            if fileManager.fileExists(atPath: fileURL.path) { try fileManager.removeItem(at: fileURL) }
            storageAvailable = true
        } catch {
            storageAvailable = false
        }
    }

    nonisolated static func defaultURL(fileManager: FileManager = .default) -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return support
            .appendingPathComponent("Resenha/ContextualCorrections", isDirectory: true)
            .appendingPathComponent("jev-attempts-v1.json")
    }

    private func update(
        id: UUID,
        startedAt: Date,
        completedAt: Date,
        mutation: (inout ContextualAttemptRecord) -> Void
    ) {
        if !records.contains(where: { $0.id == id }) {
            records.append(.init(
                id: id, startedAt: startedAt, completedAt: nil, status: .requested,
                resolvedModel: nil, decisions: [], minimumConfidence: nil,
                minimumProbability: nil, latencyMilliseconds: nil, inputTokens: nil,
                outputTokens: nil, costUSD: nil, failure: nil
            ))
        }
        guard let index = records.lastIndex(where: { $0.id == id }) else { return }
        records[index].completedAt = completedAt
        mutation(&records[index])
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            guard let size = (attributes[.size] as? NSNumber)?.intValue,
                  size <= Self.maximumFileBytes else { throw CocoaError(.fileReadTooLarge) }
            let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: fileURL))
            guard envelope.schemaVersion == 1,
                  envelope.records.count <= Self.maximumRecords,
                  envelope.records.allSatisfy(Self.isValid) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            records = envelope.records
        } catch {
            records = []
            storageAvailable = false
        }
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(Envelope(schemaVersion: 1, records: records))
            guard data.count <= Self.maximumFileBytes else { throw CocoaError(.fileWriteOutOfSpace) }
            try data.write(to: fileURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            storageAvailable = true
        } catch {
            storageAvailable = false
        }
    }

    private static func probability(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...1).contains(value) else { return nil }
        return value
    }

    private static func cost(_ value: Decimal?) -> Decimal? {
        guard let value, value.isFinite, value >= 0, value <= 1 else { return nil }
        return value
    }

    private static func isValid(_ record: ContextualAttemptRecord) -> Bool {
        record.resolvedModel.map { !$0.isEmpty && $0.count <= 128 } ?? true
            && record.decisions.count <= 3
            && probability(record.minimumConfidence) == record.minimumConfidence
            && probability(record.minimumProbability) == record.minimumProbability
            && record.latencyMilliseconds.map { $0 >= 0 } ?? true
            && record.inputTokens.map { $0 >= 0 } ?? true
            && record.outputTokens.map { $0 >= 0 } ?? true
            && cost(record.costUSD) == record.costUSD
            && record.providerRequestID.map { !$0.isEmpty && $0.count <= 128 } ?? true
    }
}

