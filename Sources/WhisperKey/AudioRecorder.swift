import AVFoundation

enum AudioRecorderError: LocalizedError {
    case alreadyRecording
    case failedToStart
    case notRecording

    var errorDescription: String? {
        switch self {
        case .alreadyRecording: "Audio recording is already active."
        case .failedToStart: "The microphone did not start recording."
        case .notRecording: "No audio recording is active."
        }
    }
}

@MainActor
final class AudioRecorder {
    nonisolated static let staleRecordingAge: TimeInterval = 24 * 60 * 60
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private var meterTimer: Timer?
    private var durationTimer: Timer?
    var onLevel: (@MainActor (Float) -> Void)?
    var onMaximumDuration: (@MainActor () -> Void)?

    func start(maximumDuration: TimeInterval = ResenhaRuntimeLimits.maximumRecordingDuration) throws {
        guard recorder == nil else { throw AudioRecorderError.alreadyRecording }

        let directory = Self.recordingDirectory()
        try Self.prepareDirectory(directory)
        let outputURL = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder(url: outputURL, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: outputURL.path)
            guard recorder.record(forDuration: max(0, maximumDuration)) else {
                throw AudioRecorderError.failedToStart
            }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
        self.outputURL = outputURL
        self.recorder = recorder
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleLevel() }
        }
        meterTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        let durationTimer = Timer(timeInterval: max(0, maximumDuration), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.maximumDurationReached() }
        }
        self.durationTimer = durationTimer
        RunLoop.main.add(durationTimer, forMode: .common)
    }

    func stop() throws -> URL {
        guard let recorder, let outputURL else { throw AudioRecorderError.notRecording }
        stopMetering()
        recorder.stop()
        self.recorder = nil
        self.outputURL = nil
        return outputURL
    }

    func cancel() {
        stopMetering()
        recorder?.stop()
        recorder = nil
        if let outputURL { try? FileManager.default.removeItem(at: outputURL) }
        outputURL = nil
    }

    private func sampleLevel() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        onLevel?(RecordingMeter.normalizedDecibels(recorder.averagePower(forChannel: 0)))
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func maximumDurationReached() {
        durationTimer?.invalidate()
        durationTimer = nil
        guard recorder != nil else { return }
        onMaximumDuration?()
    }

    nonisolated static func cleanupStaleRecordings(
        now: Date = Date(),
        olderThan minimumAge: TimeInterval = 0,
        directory: URL = recordingDirectory(),
        fileManager: FileManager = .default
    ) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files where file.pathExtension.lowercased() == "wav" {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  now.timeIntervalSince(modified) >= max(0, minimumAge) else { continue }
            try? fileManager.removeItem(at: file)
        }
    }

    nonisolated static func recordingDirectory(base: URL = FileManager.default.temporaryDirectory) -> URL {
        base.appendingPathComponent("WhisperKey", isDirectory: true)
    }

    nonisolated private static func prepareDirectory(_ directory: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }
}
