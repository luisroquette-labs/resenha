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

@MainActor
final class WhisperModelManager: ObservableObject {
    enum State: Equatable {
        case missing
        case downloading(Double)
        case verifying
        case ready(URL)
        case failed(String)
    }

    static let shared = WhisperModelManager()
    @Published private(set) var state: State = .missing
    let model = WhisperModelDescriptor.starter
    private var task: Task<Void, Never>?
    private var client: ModelDownloadClient?

    var modelURL: URL { WhisperPaths.modelDirectory.appendingPathComponent(model.filename) }

    private init() { refresh() }

    func refresh() {
        guard task == nil else { return }
        state = FileManager.default.fileExists(atPath: modelURL.path) ? .ready(modelURL) : .missing
    }

    func download() {
        guard task == nil else { return }
        state = .downloading(0)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let directory = self.modelURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let staged = directory.appendingPathComponent(".\(self.model.filename).download")
                try? FileManager.default.removeItem(at: staged)
                let client = ModelDownloadClient(destination: staged) { [weak self] progress in
                    Task { @MainActor in self?.state = .downloading(progress) }
                }
                self.client = client
                try await client.download(from: self.model.downloadURL)
                self.state = .verifying
                let attributes = try FileManager.default.attributesOfItem(atPath: staged.path)
                guard (attributes[.size] as? NSNumber)?.int64Value == self.model.byteCount else {
                    throw ModelDownloadError.invalidSize
                }
                guard try Self.sha256(of: staged) == self.model.sha256 else {
                    throw ModelDownloadError.invalidChecksum
                }
                try? FileManager.default.removeItem(at: self.modelURL)
                try FileManager.default.moveItem(at: staged, to: self.modelURL)
                self.state = .ready(self.modelURL)
            } catch {
                self.state = .failed(Self.message(for: error))
            }
            self.client = nil
            self.task = nil
        }
    }

    func retry() { download() }

    private static func sha256(of url: URL) throws -> String {
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

    private static func message(for error: Error) -> String {
        switch error {
        case ModelDownloadError.invalidSize: "O arquivo recebido tem tamanho incorreto. Tente novamente."
        case ModelDownloadError.invalidChecksum: "A verificação de segurança falhou. Tente novamente."
        default: "Não foi possível baixar o modelo. Confira a internet e tente novamente."
        }
    }
}

enum ModelDownloadError: Error {
    case invalidSize
    case invalidChecksum
    case missingTemporaryFile
}

private final class ModelDownloadClient: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let progress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var downloadError: Error?
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    init(destination: URL, progress: @escaping @Sendable (Double) -> Void) {
        self.destination = destination
        self.progress = progress
    }

    func download(from url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
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
        let result = downloadError ?? error
        let continuation = continuation
        self.continuation = nil
        session.finishTasksAndInvalidate()
        if let result { continuation?.resume(throwing: result) }
        else if FileManager.default.fileExists(atPath: destination.path) { continuation?.resume() }
        else { continuation?.resume(throwing: ModelDownloadError.missingTemporaryFile) }
    }
}
