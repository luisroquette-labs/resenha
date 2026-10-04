import CryptoKit
import XCTest
@testable import WhisperKey

final class LocalIntegrityTests: XCTestCase {
    private func makeDirectory(_ label: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Resenha-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func descriptor(for data: Data, filename: String = "model.bin") -> WhisperModelDescriptor {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return WhisperModelDescriptor(
            filename: filename,
            displayName: "Fixture",
            downloadURL: URL(string: "https://example.invalid/model.bin")!,
            byteCount: Int64(data.count),
            sha256: digest
        )
    }

    @MainActor
    private func waitForState(
        _ manager: WhisperModelManager,
        timeout: Duration = .seconds(2),
        predicate: @escaping (WhisperModelManager.State) -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !predicate(manager.state) {
            if clock.now >= deadline { XCTFail("Timed out waiting for model state: \(manager.state)"); return }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @MainActor
    func testLaunchVerifiesChecksumBeforeReadyAndRejectsCorruption() async throws {
        let directory = try makeDirectory("launch-verification")
        defer { try? FileManager.default.removeItem(at: directory) }
        let modelURL = directory.appendingPathComponent("model.bin")
        let validData = Data("verified model".utf8)
        try validData.write(to: modelURL)
        let descriptor = descriptor(for: validData)

        let validManager = WhisperModelManager(model: descriptor, modelURL: modelURL)
        XCTAssertEqual(validManager.state, .verifying)
        try await waitForState(validManager) { if case .ready = $0 { true } else { false } }
        XCTAssertEqual(validManager.state, .ready(modelURL))

        try Data("tampered model".utf8).write(to: modelURL)
        let corruptManager = WhisperModelManager(model: descriptor, modelURL: modelURL)
        XCTAssertEqual(corruptManager.state, .verifying)
        try await waitForState(corruptManager) { if case .failed = $0 { true } else { false } }
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelURL.path))
    }

    func testAtomicInstallerPreservesPreviousModelWhenCandidateOrReplacementFails() throws {
        let directory = try makeDirectory("atomic-install")
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("model.bin")
        let staged = directory.appendingPathComponent(".model.bin.download")
        let previous = Data("previous valid model".utf8)
        let candidate = Data("new verified model".utf8)
        try previous.write(to: destination)
        try Data("invalid".utf8).write(to: staged)

        XCTAssertThrowsError(try AtomicModelInstaller.install(
            staged: staged,
            destination: destination,
            descriptor: descriptor(for: candidate)
        ))
        XCTAssertEqual(try Data(contentsOf: destination), previous)

        try candidate.write(to: staged)
        XCTAssertThrowsError(try AtomicModelInstaller.install(
            staged: staged,
            destination: destination,
            descriptor: descriptor(for: candidate),
            replacement: { destination, staged, backupName in
                let backup = destination.deletingLastPathComponent().appendingPathComponent(backupName)
                try FileManager.default.moveItem(at: destination, to: backup)
                try FileManager.default.moveItem(at: staged, to: destination)
                throw CocoaError(.fileWriteUnknown)
            }
        ))
        XCTAssertEqual(try Data(contentsOf: destination), previous)

        try candidate.write(to: staged)
        try AtomicModelInstaller.install(
            staged: staged,
            destination: destination,
            descriptor: descriptor(for: candidate)
        )
        XCTAssertEqual(try Data(contentsOf: destination), candidate)
        let permissions = try XCTUnwrap(
            FileManager.default.attributesOfItem(atPath: destination.path)[.posixPermissions] as? NSNumber
        ).intValue
        XCTAssertEqual(permissions & 0o777, 0o600)
    }

    func testRollbackFailureSurfacesAndPreservesVerifiedBackup() throws {
        let directory = try makeDirectory("rollback-failure")
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("model.bin")
        let staged = directory.appendingPathComponent(".model.bin.download")
        let previous = Data("previous valid model".utf8)
        let candidate = Data("new verified model".utf8)
        try previous.write(to: destination)
        try candidate.write(to: staged)

        XCTAssertThrowsError(try AtomicModelInstaller.install(
            staged: staged,
            destination: destination,
            descriptor: descriptor(for: candidate),
            replacement: { destination, staged, backupName in
                let backup = destination.deletingLastPathComponent().appendingPathComponent(backupName)
                try FileManager.default.moveItem(at: destination, to: backup)
                try FileManager.default.moveItem(at: staged, to: destination)
                throw CocoaError(.fileWriteUnknown)
            },
            restoration: { _, _ in throw CocoaError(.fileWriteNoPermission) }
        )) { error in
            guard let rollback = error as? ModelRollbackError else {
                return XCTFail("Expected explicit rollback failure, got \(error)")
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: rollback.preservedBackupURL.path))
            XCTAssertEqual(try? Data(contentsOf: rollback.preservedBackupURL), previous)
        }
    }

    @MainActor
    func testLaunchRecoversValidBackupAndCleansOrphans() async throws {
        let directory = try makeDirectory("backup-recovery")
        defer { try? FileManager.default.removeItem(at: directory) }
        let modelURL = directory.appendingPathComponent("model.bin")
        let valid = Data("verified model".utf8)
        let descriptor = descriptor(for: valid)
        let recoverable = directory.appendingPathComponent(".model.bin.backup-recoverable")
        let invalid = directory.appendingPathComponent(".model.bin.backup-invalid")
        try Data("corrupt canonical".utf8).write(to: modelURL)
        try valid.write(to: recoverable)
        try Data("bad backup".utf8).write(to: invalid)

        let manager = WhisperModelManager(model: descriptor, modelURL: modelURL)
        XCTAssertEqual(manager.state, .verifying)
        try await waitForState(manager) { if case .ready = $0 { true } else { false } }

        XCTAssertEqual(try Data(contentsOf: modelURL), valid)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recoverable.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: invalid.path))

        let stale = directory.appendingPathComponent(".model.bin.backup-stale")
        try valid.write(to: stale)
        let validatingManager = WhisperModelManager(model: descriptor, modelURL: modelURL)
        try await waitForState(validatingManager) { if case .ready = $0 { true } else { false } }
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
    }

    @MainActor
    func testCancelledDownloadPersistsResumeDataAndResumeCleansArtifacts() async throws {
        let directory = try makeDirectory("resume")
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Data("downloaded model".utf8)
        let descriptor = descriptor(for: payload)
        let modelURL = directory.appendingPathComponent(descriptor.filename)
        let resumeData = Data("resume-token".utf8)

        let cancellableClient = CancellableDownloadClient(resumeData: resumeData)
        let cancelled = WhisperModelManager(
            model: descriptor,
            modelURL: modelURL,
            autoRefresh: false,
            clientFactory: { _, _ in cancellableClient }
        )
        cancelled.download()
        let clock = ContinuousClock()
        let startDeadline = clock.now.advanced(by: .seconds(2))
        while !cancellableClient.hasStarted && clock.now < startDeadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(cancellableClient.hasStarted)
        cancelled.cancelDownload()
        try await waitForState(cancelled) { $0 == .missing && cancelled.hasResumableDownload }
        XCTAssertEqual(try Data(contentsOf: cancelled.resumeDataURL), resumeData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cancelled.stagedURL.path))

        let observation = ResumeDataObservation()
        let resumed = WhisperModelManager(
            model: descriptor,
            modelURL: modelURL,
            autoRefresh: false,
            clientFactory: { destination, _ in
                FixtureDownloadClient(destination: destination, payload: payload, observation: observation)
            }
        )
        XCTAssertTrue(resumed.hasResumableDownload)
        resumed.download()
        try await waitForState(resumed) { if case .ready = $0 { true } else { false } }
        XCTAssertEqual(observation.value, resumeData)
        XCTAssertEqual(try Data(contentsOf: modelURL), payload)
        XCTAssertFalse(FileManager.default.fileExists(atPath: resumed.resumeDataURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: resumed.stagedURL.path))
    }

    @MainActor
    func testFailedDownloadPreservesExistingValidModelAndCleansArtifacts() async throws {
        let directory = try makeDirectory("failed-update")
        defer { try? FileManager.default.removeItem(at: directory) }
        let previous = Data("existing verified model".utf8)
        let descriptor = descriptor(for: previous)
        let modelURL = directory.appendingPathComponent(descriptor.filename)
        try previous.write(to: modelURL)

        let manager = WhisperModelManager(
            model: descriptor,
            modelURL: modelURL,
            autoRefresh: false,
            clientFactory: { destination, _ in
                FailingDownloadClient(destination: destination)
            }
        )
        try Data("resume".utf8).write(to: manager.resumeDataURL)
        manager.download()
        try await waitForState(manager) { if case .ready = $0 { true } else { false } }

        XCTAssertEqual(try Data(contentsOf: modelURL), previous)
        XCTAssertFalse(FileManager.default.fileExists(atPath: manager.stagedURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: manager.resumeDataURL.path))
        XCTAssertFalse(manager.hasResumableDownload)
    }

    @MainActor
    func testClearHistoryDeletesCanonicalAndAllQuarantines() throws {
        let directory = try makeDirectory("history-clear")
        defer { try? FileManager.default.removeItem(at: directory) }
        let canonical = directory.appendingPathComponent("recent-transcripts.json")
        let first = directory.appendingPathComponent("recent-transcripts.corrupt-first.json")
        let second = directory.appendingPathComponent("recent-transcripts.corrupt-second.json")
        let unrelated = directory.appendingPathComponent("keep.json")
        try Data("[]".utf8).write(to: canonical)
        try Data("private".utf8).write(to: first)
        try Data("private".utf8).write(to: second)
        try Data("keep".utf8).write(to: unrelated)

        let history = TranscriptHistory(fileURL: canonical)
        history.clear()

        XCTAssertFalse(FileManager.default.fileExists(atPath: canonical.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    @MainActor
    func testPrivacyMigrationClearsLegacyArtifactsOnceBeforeOptIn() throws {
        let directory = try makeDirectory("history-privacy-migration")
        defer { try? FileManager.default.removeItem(at: directory) }
        let canonical = directory.appendingPathComponent("recent-transcripts.json")
        let quarantine = directory.appendingPathComponent("recent-transcripts.corrupt-legacy.json")
        try Data("[]".utf8).write(to: canonical)
        try Data("private".utf8).write(to: quarantine)
        let suite = "ResenhaHistoryPrivacyMigration.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ProductPreferences(defaults: defaults)
        let history = TranscriptHistory(fileURL: canonical)

        XCTAssertTrue(preferences.migrateLegacyHistoryIfNeeded { history.clear() })
        XCTAssertFalse(FileManager.default.fileExists(atPath: canonical.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: quarantine.path))

        try Data("new opt-in history".utf8).write(to: canonical)
        let relaunched = ProductPreferences(defaults: defaults)
        XCTAssertTrue(relaunched.migrateLegacyHistoryIfNeeded {
            XCTFail("Completed migration must be idempotent")
            return false
        })
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonical.path))
    }

    @MainActor
    func testClearHistoryUsesInjectedFilesystemIdentityForAliasedCanonicalFile() throws {
        let directory = try makeDirectory("history-clear-identity")
        defer { try? FileManager.default.removeItem(at: directory) }
        let canonical = directory.appendingPathComponent("recent-transcripts.json")
        let listedAlias = URL(fileURLWithPath: "/synthetic-alias/recent-transcripts.json")
        let normalizedIdentity = URL(fileURLWithPath: "/normalized/recent-transcripts.json")
        try Data("[]".utf8).write(to: canonical)
        var attempts: [URL] = []
        let operations = TranscriptHistoryClearFileOperations(
            fileExists: { _ in true },
            contents: { _ in [listedAlias] },
            remove: { url in
                attempts.append(url)
                try FileManager.default.removeItem(at: canonical)
            },
            identity: { url in
                url == canonical || url == listedAlias ? normalizedIdentity : url
            }
        )

        let history = TranscriptHistory(fileURL: canonical, clearFileOperations: operations)
        history.clear()

        XCTAssertEqual(attempts, [listedAlias])
        XCTAssertFalse(FileManager.default.fileExists(atPath: canonical.path))
        XCTAssertTrue(history.storageAvailable)
    }

    func testFoundationResolvesExistingVarAndPrivateVarToSameIdentity() throws {
        let varParent = URL(fileURLWithPath: "/var", isDirectory: true)
        let privateVarParent = URL(fileURLWithPath: "/private/var", isDirectory: true)
        guard FileManager.default.fileExists(atPath: varParent.path),
              FileManager.default.fileExists(atPath: privateVarParent.path) else {
            throw XCTSkip("macOS /var aliases are unavailable on this host")
        }

        XCTAssertNotEqual(varParent, privateVarParent)
        XCTAssertEqual(
            varParent.standardizedFileURL.resolvingSymlinksInPath(),
            privateVarParent.standardizedFileURL.resolvingSymlinksInPath()
        )
    }

    @MainActor
    func testClearHistoryAttemptsEveryArtifactAfterDeletionFailure() throws {
        let directory = try makeDirectory("history-clear-failure")
        defer { try? FileManager.default.removeItem(at: directory) }
        let canonical = directory.appendingPathComponent("recent-transcripts.json")
        let first = directory.appendingPathComponent("recent-transcripts.corrupt-first.json")
        let second = directory.appendingPathComponent("recent-transcripts.corrupt-second.json")
        try Data("[]".utf8).write(to: canonical)
        for file in [first, second] { try Data("private".utf8).write(to: file) }
        var attempts: [URL] = []
        let operations = TranscriptHistoryClearFileOperations(
            fileExists: { _ in true },
            contents: { _ in [canonical, first, second] },
            remove: { url in
                attempts.append(url)
                if url == canonical { throw CocoaError(.fileWriteNoPermission) }
                try FileManager.default.removeItem(at: url)
            }
        )
        let history = TranscriptHistory(fileURL: canonical, clearFileOperations: operations)

        history.clear()

        XCTAssertEqual(attempts, [canonical, first, second])
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonical.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
        XCTAssertFalse(history.storageAvailable)
    }

    @MainActor
    func testServiceAdmissionRequiresReadyModelState() {
        let hotkey = HotkeyMonitor()
        let verified = URL(fileURLWithPath: "/verified/model.bin")
        var state = WhisperModelManager.State.verifying
        var starts = 0
        let app = AppDelegate(hotkey: hotkey, verifiedModelURL: {
            guard case .ready(let url) = state else { return nil }
            return url
        }) {
            starts += 1
            return true
        }
        app.configureHotkeyRouting()

        hotkey.process(eventType: .keyDown, keyCode: 14)
        XCTAssertFalse(app.beginServiceDictation(pressedKeyCodes: [14], targetIsSelf: false))
        state = .failed("invalid")
        XCTAssertFalse(app.beginServiceDictation(pressedKeyCodes: [14], targetIsSelf: false))
        XCTAssertEqual(starts, 0)

        state = .ready(verified)
        XCTAssertTrue(app.beginServiceDictation(pressedKeyCodes: [14], targetIsSelf: false))
        XCTAssertEqual(starts, 1)
        hotkey.process(eventType: .keyUp, keyCode: 14)
    }
}

private final class CancellableDownloadClient: ModelDownloadClientProtocol, @unchecked Sendable {
    private let resumeData: Data
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var started = false

    init(resumeData: Data) { self.resumeData = resumeData }

    var hasStarted: Bool { lock.withLock { started } }

    func download(from url: URL, resumeData: Data?) async throws {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                started = true
                self.continuation = continuation
            }
        }
    }

    func cancel() {
        let continuation = lock.withLock {
            let value = self.continuation
            self.continuation = nil
            return value
        }
        continuation?.resume(throwing: ModelDownloadError.cancelled(resumeData))
    }
}

private final class ResumeDataObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Data?

    var value: Data? { lock.withLock { storage } }
    func record(_ data: Data?) { lock.withLock { storage = data } }
}

private final class FixtureDownloadClient: ModelDownloadClientProtocol {
    private let destination: URL
    private let payload: Data
    private let observation: ResumeDataObservation

    init(destination: URL, payload: Data, observation: ResumeDataObservation) {
        self.destination = destination
        self.payload = payload
        self.observation = observation
    }

    func download(from url: URL, resumeData: Data?) async throws {
        observation.record(resumeData)
        try payload.write(to: destination, options: .atomic)
    }

    func cancel() {}
}

private final class FailingDownloadClient: ModelDownloadClientProtocol {
    private let destination: URL

    init(destination: URL) { self.destination = destination }

    func download(from url: URL, resumeData: Data?) async throws {
        try Data("partial".utf8).write(to: destination)
        throw URLError(.networkConnectionLost)
    }

    func cancel() {}
}
