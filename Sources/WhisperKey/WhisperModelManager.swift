import CryptoKit
import Combine
import Foundation

struct WhisperModelDescriptor: Equatable, Sendable {
    let filename: String
    let displayName: String
    let downloadURL: URL
    let byteCount: Int64
    let sha256: String

    static let starter = WhisperModelDescriptor(
        filename: "ggml-small-q5_1.bin",
        displayName: "Whisper Small · otimizado",
        downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin")!,
        byteCount: 190_085_487,
        sha256: "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb"
    )
}

enum ModelDownloadError: Error {
    case invalidSize
    case invalidChecksum
    case missingTemporaryFile
    case cancelled(Data?)
}

struct ModelRollbackError: LocalizedError {
    let replacementError: Error
    let rollbackError: Error
    let preservedBackupURL: URL

    var errorDescription: String? {
        "Model replacement and rollback failed; valid backup preserved at \(preservedBackupURL.path)"
    }
}

protocol ModelDownloadClientProtocol: AnyObject {
    func download(from url: URL, resumeData: Data?) async throws
    func cancel()
}

struct ModelIntegrityVerifier {
    struct Fingerprint: Equatable {
        let byteCount: Int64
        let sha256: String
    }

    static func validate(_ url: URL, descriptor: WhisperModelDescriptor) throws {
        let fingerprint = try fingerprint(of: url)
        guard fingerprint.byteCount == descriptor.byteCount else {
            throw ModelDownloadError.invalidSize
        }
        guard fingerprint.sha256 == descriptor.sha256 else {
            throw ModelDownloadError.invalidChecksum
        }
    }

    static func fingerprint(of url: URL) throws -> Fingerprint {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? -1
        return Fingerprint(byteCount: byteCount, sha256: try sha256(of: url))
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 4 * 1_024 * 1_024) ?? Data()
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

struct AtomicModelInstaller {
    typealias Replacement = (_ destination: URL, _ staged: URL, _ backupName: String) throws -> Void
    typealias Restoration = (_ backup: URL, _ destination: URL) throws -> Void

    static func install(
        staged: URL,
        destination: URL,
        descriptor: WhisperModelDescriptor,
        fileManager: FileManager = .default,
        replacement: Replacement? = nil,
        restoration: Restoration? = nil
    ) throws {
        try ModelIntegrityVerifier.validate(staged, descriptor: descriptor)
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: staged.path)

        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.moveItem(at: staged, to: destination)
            return
        }
        let previousFingerprint = try ModelIntegrityVerifier.fingerprint(of: destination)

        let backupName = ".\(destination.lastPathComponent).backup-\(UUID().uuidString)"
        let backupURL = directory.appendingPathComponent(backupName)
        let performReplacement = replacement ?? { destination, staged, backupName in
            _ = try fileManager.replaceItemAt(
                destination,
                withItemAt: staged,
                backupItemName: backupName,
                options: []
            )
        }

        do {
            try performReplacement(destination, staged, backupName)
            guard fileManager.fileExists(atPath: destination.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            try? fileManager.removeItem(at: backupURL)
        } catch {
            let replacementError = error
            if fileManager.fileExists(atPath: backupURL.path) {
                do {
                    if let restoration {
                        try restoration(backupURL, destination)
                    } else {
                        guard try ModelIntegrityVerifier.fingerprint(of: backupURL) == previousFingerprint else {
                            throw ModelDownloadError.invalidChecksum
                        }
                        if fileManager.fileExists(atPath: destination.path) {
                            try fileManager.removeItem(at: destination)
                        }
                        try fileManager.copyItem(at: backupURL, to: destination)
                        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
                    }
                    guard try ModelIntegrityVerifier.fingerprint(of: destination) == previousFingerprint else {
                        throw ModelDownloadError.invalidChecksum
                    }
                    try fileManager.removeItem(at: backupURL)
                } catch {
                    throw ModelRollbackError(
                        replacementError: replacementError,
                        rollbackError: error,
                        preservedBackupURL: backupURL
                    )
                }
            }
            throw replacementError
        }
    }
}

struct ModelBackupRecovery {
    static func backupURLs(
        for destination: URL,
        fileManager: FileManager = .default
    ) throws -> [URL] {
        let directory = destination.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        let prefix = ".\(destination.lastPathComponent).backup-"
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        )
        .filter { $0.lastPathComponent.hasPrefix(prefix) }
        .sorted {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left > right
        }
    }

    static func validateOrRecover(
        destination: URL,
        descriptor: WhisperModelDescriptor,
        fileManager: FileManager = .default
    ) throws -> Bool {
        let backups = try backupURLs(for: destination, fileManager: fileManager)
        let hadCanonical = fileManager.fileExists(atPath: destination.path)
        var canonicalError: Error?

        if hadCanonical {
            do {
                try ModelIntegrityVerifier.validate(destination, descriptor: descriptor)
                cleanup(backups, fileManager: fileManager)
                return true
            } catch {
                canonicalError = error
            }
        }

        for backup in backups {
            guard (try? ModelIntegrityVerifier.validate(backup, descriptor: descriptor)) != nil else {
                try? fileManager.removeItem(at: backup)
                continue
            }
            do {
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.copyItem(at: backup, to: destination)
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
                try ModelIntegrityVerifier.validate(destination, descriptor: descriptor)
                cleanup(backups, fileManager: fileManager)
                return true
            } catch {
                throw ModelRollbackError(
                    replacementError: canonicalError ?? CocoaError(.fileNoSuchFile),
                    rollbackError: error,
                    preservedBackupURL: backup
                )
            }
        }

        if fileManager.fileExists(atPath: destination.path) {
            try? fileManager.removeItem(at: destination)
        }
        if let canonicalError { throw canonicalError }
        return false
    }

    private static func cleanup(_ backups: [URL], fileManager: FileManager) {
        for backup in backups where fileManager.fileExists(atPath: backup.path) {
            try? fileManager.removeItem(at: backup)
        }
    }
}

@MainActor
final class WhisperModelManager: ObservableObject {
    enum State: Equatable {
        case missing
        case downloading(Double)
        case verifying
        case ready(URL)
        case failed(String)
    }

    typealias ClientFactory = (_ destination: URL, _ progress: @escaping @Sendable (Double) -> Void) -> ModelDownloadClientProtocol

    static let shared = WhisperModelManager()
    @Published private(set) var state: State = .missing
    @Published private(set) var hasResumableDownload = false
    let model: WhisperModelDescriptor
    private let resolvedModelURL: URL
    private let fileManager: FileManager
    private let clientFactory: ClientFactory
    private var task: Task<Void, Never>?
    private var client: ModelDownloadClientProtocol?
    private var cancellationRequested = false

    var modelURL: URL { resolvedModelURL }
    var verifiedModelURL: URL? {
        guard case .ready(let url) = state else { return nil }
        return url
    }
    var stagedURL: URL { modelURL.deletingLastPathComponent().appendingPathComponent(".\(model.filename).download") }
    var resumeDataURL: URL { modelURL.deletingLastPathComponent().appendingPathComponent(".\(model.filename).resume-data") }

    convenience init() {
        let model = WhisperModelDescriptor.starter
        self.init(
            model: model,
            modelURL: WhisperPaths.modelDirectory.appendingPathComponent(model.filename)
        )
    }

    init(
        model: WhisperModelDescriptor,
        modelURL: URL,
        fileManager: FileManager = .default,
        autoRefresh: Bool = true,
        clientFactory: @escaping ClientFactory = { destination, progress in
            ModelDownloadClient(destination: destination, progress: progress)
        }
    ) {
        self.model = model
        self.resolvedModelURL = modelURL
        self.fileManager = fileManager
        self.clientFactory = clientFactory
        removeIfPresent(stagedURL)
        hasResumableDownload = fileManager.fileExists(atPath: resumeDataURL.path)
        if autoRefresh { refresh() }
    }

    func refresh() {
        guard task == nil else { return }
        removeIfPresent(stagedURL)
        hasResumableDownload = fileManager.fileExists(atPath: resumeDataURL.path)
        let hasCanonical = fileManager.fileExists(atPath: modelURL.path)
        let hasBackups = ((try? ModelBackupRecovery.backupURLs(
            for: modelURL,
            fileManager: fileManager
        )) ?? []).isEmpty == false
        guard hasCanonical || hasBackups else {
            state = .missing
            return
        }

        state = .verifying
        let url = modelURL
        let descriptor = model
        let fileManager = self.fileManager
        task = Task { [weak self] in
            do {
                let recovered = try await Task.detached(priority: .utility) {
                    try ModelBackupRecovery.validateOrRecover(
                        destination: url,
                        descriptor: descriptor,
                        fileManager: fileManager
                    )
                }.value
                guard !Task.isCancelled else { return }
                self?.state = recovered ? .ready(url) : .missing
            } catch {
                self?.removeIfPresent(url)
                self?.state = .failed(Self.message(for: error))
            }
            self?.task = nil
        }
    }

    func download() {
        guard task == nil else { return }
        cancellationRequested = false
        state = .downloading(0)
        task = Task { [weak self] in
            guard let self else { return }
            let directory = self.modelURL.deletingLastPathComponent()
            do {
                try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                self.removeIfPresent(self.stagedURL)
                let resumeData = try? Data(contentsOf: self.resumeDataURL)
                try await self.performDownload(resumeData: resumeData)
                self.state = .verifying
                let stagedURL = self.stagedURL
                let modelURL = self.modelURL
                let model = self.model
                let fileManager = self.fileManager
                try await Task.detached(priority: .utility) {
                    try AtomicModelInstaller.install(
                        staged: stagedURL,
                        destination: modelURL,
                        descriptor: model,
                        fileManager: fileManager
                    )
                }.value
                self.removeIfPresent(self.resumeDataURL)
                self.hasResumableDownload = false
                self.state = .ready(self.modelURL)
            } catch ModelDownloadError.cancelled(let resumeData) {
                self.removeIfPresent(self.stagedURL)
                if let resumeData, !resumeData.isEmpty {
                    try? resumeData.write(to: self.resumeDataURL, options: [.atomic])
                    try? self.fileManager.setAttributes(
                        [.posixPermissions: 0o600],
                        ofItemAtPath: self.resumeDataURL.path
                    )
                } else {
                    self.removeIfPresent(self.resumeDataURL)
                }
                self.hasResumableDownload = self.fileManager.fileExists(atPath: self.resumeDataURL.path)
                self.state = .missing
            } catch {
                self.removeIfPresent(self.stagedURL)
                self.removeIfPresent(self.resumeDataURL)
                self.hasResumableDownload = false
                if (try? ModelIntegrityVerifier.validate(self.modelURL, descriptor: self.model)) != nil {
                    self.state = .ready(self.modelURL)
                } else {
                    self.state = .failed(Self.message(for: error))
                }
            }
            self.client = nil
            self.cancellationRequested = false
            self.task = nil
        }
    }

    func cancelDownload() {
        cancellationRequested = true
        client?.cancel()
    }

    func retry() { download() }

    private func performDownload(resumeData: Data?) async throws {
        let client = clientFactory(stagedURL) { [weak self] progress in
            Task { @MainActor in self?.state = .downloading(progress) }
        }
        self.client = client
        if cancellationRequested { throw ModelDownloadError.cancelled(nil) }
        do {
            try await client.download(from: model.downloadURL, resumeData: resumeData)
        } catch ModelDownloadError.cancelled(let data) {
            throw ModelDownloadError.cancelled(data)
        } catch where resumeData != nil {
            removeIfPresent(resumeDataURL)
            let freshClient = clientFactory(stagedURL) { [weak self] progress in
                Task { @MainActor in self?.state = .downloading(progress) }
            }
            self.client = freshClient
            if cancellationRequested { throw ModelDownloadError.cancelled(nil) }
            try await freshClient.download(from: model.downloadURL, resumeData: nil)
        }
    }

    private func removeIfPresent(_ url: URL) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    private static func message(for error: Error) -> String {
        switch error {
        case ModelDownloadError.invalidSize: "O arquivo recebido tem tamanho incorreto. Tente novamente."
        case ModelDownloadError.invalidChecksum: "A verificação de segurança falhou. Tente novamente."
        default: "Não foi possível baixar o modelo. Confira a internet e tente novamente."
        }
    }
}

private final class ModelDownloadClient: NSObject, ModelDownloadClientProtocol, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let progress: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var downloadError: Error?
    private var downloadTask: URLSessionDownloadTask?
    private var cancellationRequested = false
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    init(destination: URL, progress: @escaping @Sendable (Double) -> Void) {
        self.destination = destination
        self.progress = progress
    }

    func download(from url: URL, resumeData: Data?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            let task = resumeData.map(session.downloadTask(withResumeData:)) ?? session.downloadTask(with: url)
            downloadTask = task
            lock.unlock()
            task.resume()
        }
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let task = downloadTask
        lock.unlock()
        task?.cancel { [weak self] resumeData in
            self?.finish(.failure(ModelDownloadError.cancelled(resumeData)))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress(min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: location, to: destination)
        } catch {
            downloadError = error
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        let wasCancelled = cancellationRequested
        lock.unlock()
        if wasCancelled { return }
        if let result = downloadError ?? error {
            finish(.failure(result))
        } else if FileManager.default.fileExists(atPath: destination.path) {
            finish(.success(()))
        } else {
            finish(.failure(ModelDownloadError.missingTemporaryFile))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        downloadTask = nil
        lock.unlock()
        guard let continuation else { return }
        session.finishTasksAndInvalidate()
        continuation.resume(with: result)
    }
}
