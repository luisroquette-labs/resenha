import AVFoundation

struct AudioSampleSnapshot: Equatable, Sendable {
    let id: UInt64
    let samples: [Float]
    let sampleRange: Range<Int64>
    let capturedAt: TimeInterval
}

struct RollingAudioConfiguration: Equatable, Sendable {
    let maximumRetainedSamples: Int
    let snapshotStrideSamples: Int

    init(maximumRetainedSamples: Int, snapshotStrideSamples: Int) {
        precondition(maximumRetainedSamples > 0)
        precondition(snapshotStrideSamples > 0)
        self.maximumRetainedSamples = maximumRetainedSamples
        self.snapshotStrideSamples = snapshotStrideSamples
    }
}

final class BoundedAudioSampleAccumulator: @unchecked Sendable {
    private let configuration: RollingAudioConfiguration
    private let lock = NSLock()
    private var storage: [Float]
    private var writeIndex = 0
    private var retainedCount = 0
    private var totalSampleCount: Int64 = 0
    private var lastSnapshotEnd: Int64 = 0
    private var nextSnapshotID: UInt64 = 1

    init(configuration: RollingAudioConfiguration) {
        self.configuration = configuration
        storage = [Float](repeating: 0, count: configuration.maximumRetainedSamples)
    }

    func append(_ samples: [Float], capturedAt: TimeInterval) -> AudioSampleSnapshot? {
        guard !samples.isEmpty else { return nil }
        return lock.withLock {
            for sample in samples {
                storage[writeIndex] = sample
                writeIndex = (writeIndex + 1) % storage.count
                retainedCount = min(retainedCount + 1, storage.count)
            }
            totalSampleCount += Int64(samples.count)
            guard totalSampleCount - lastSnapshotEnd >= Int64(configuration.snapshotStrideSamples) else { return nil }
            lastSnapshotEnd = totalSampleCount
            let startIndex = (writeIndex - retainedCount + storage.count) % storage.count
            let samples = (0..<retainedCount).map { storage[(startIndex + $0) % storage.count] }
            let start = totalSampleCount - Int64(retainedCount)
            let snapshot = AudioSampleSnapshot(
                id: nextSnapshotID,
                samples: samples,
                sampleRange: start..<totalSampleCount,
                capturedAt: capturedAt
            )
            nextSnapshotID &+= 1
            return snapshot
        }
    }

    func reset() {
        lock.withLock {
            storage = [Float](repeating: 0, count: configuration.maximumRetainedSamples)
            writeIndex = 0
            retainedCount = 0
            totalSampleCount = 0
            lastSnapshotEnd = 0
            nextSnapshotID = 1
        }
    }

    var retainedSampleCount: Int { lock.withLock { retainedCount } }
}

private final class LatestAudioSnapshotDelivery: @unchecked Sendable {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.resenha.rolling-audio-delivery", qos: .userInitiated)
    private let onSnapshot: @Sendable (AudioSampleSnapshot) -> Void
    private var isDelivering = false
    private var pending: AudioSampleSnapshot?
    private var generation: UInt64 = 0

    init(onSnapshot: @escaping @Sendable (AudioSampleSnapshot) -> Void) {
        self.onSnapshot = onSnapshot
    }

    func submit(_ snapshot: AudioSampleSnapshot) {
        let work: (AudioSampleSnapshot, UInt64)? = lock.withLock {
            guard !isDelivering else {
                pending = snapshot
                return nil
            }
            isDelivering = true
            return (snapshot, generation)
        }
        if let work { enqueue(work.0, generation: work.1) }
    }

    func cancel() {
        lock.withLock {
            generation &+= 1
            pending = nil
        }
    }

    private func enqueue(_ snapshot: AudioSampleSnapshot, generation: UInt64) {
        queue.async { [weak self] in
            guard let self else { return }
            if self.lock.withLock({ self.generation == generation }) { self.onSnapshot(snapshot) }
            let next: AudioSampleSnapshot? = self.lock.withLock {
                guard self.generation == generation else {
                    self.isDelivering = false
                    return nil
                }
                if let pending = self.pending {
                    self.pending = nil
                    return pending
                }
                self.isDelivering = false
                return nil
            }
            if let next { self.enqueue(next, generation: generation) }
        }
    }
}

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
    private var rollingEngine: AVAudioEngine?
    private var rollingAccumulator: BoundedAudioSampleAccumulator?
    private var rollingDelivery: LatestAudioSnapshotDelivery?
    var onLevel: (@MainActor (Float) -> Void)?

    func start(
        rolling configuration: RollingAudioConfiguration? = nil,
        onSnapshot: (@Sendable (AudioSampleSnapshot) -> Void)? = nil
    ) throws {
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
            guard recorder.record() else { throw AudioRecorderError.failedToStart }
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
        self.outputURL = outputURL
        self.recorder = recorder
        if let configuration, let onSnapshot {
            do {
                try startRollingCapture(configuration: configuration, onSnapshot: onSnapshot)
            } catch {
                recorder.stop()
                self.recorder = nil
                self.outputURL = nil
                try? FileManager.default.removeItem(at: outputURL)
                throw error
            }
        }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleLevel() }
        }
        meterTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() throws -> URL {
        guard let recorder, let outputURL else { throw AudioRecorderError.notRecording }
        stopMetering()
        stopRollingCapture()
        recorder.stop()
        self.recorder = nil
        self.outputURL = nil
        return outputURL
    }

    func cancel() {
        stopMetering()
        stopRollingCapture()
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
    }

    private func startRollingCapture(
        configuration: RollingAudioConfiguration,
        onSnapshot: @escaping @Sendable (AudioSampleSnapshot) -> Void
    ) throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              inputFormat.channelCount > 0,
              let outputFormat = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: 16_000,
                  channels: 1,
                  interleaved: false
              ),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioRecorderError.failedToStart
        }
        let accumulator = BoundedAudioSampleAccumulator(configuration: configuration)
        let delivery = LatestAudioSnapshotDelivery(onSnapshot: onSnapshot)
        input.installTap(onBus: 0, bufferSize: 2_048, format: inputFormat) { buffer, _ in
            let capacity = AVAudioFrameCount(
                ceil(Double(buffer.frameLength) * outputFormat.sampleRate / inputFormat.sampleRate)
            )
            guard capacity > 0,
                  let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }
            var supplied = false
            var conversionError: NSError?
            let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
                guard !supplied else {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                supplied = true
                inputStatus.pointee = .haveData
                return buffer
            }
            guard conversionError == nil,
                  status != .error,
                  let channel = converted.floatChannelData?.pointee else { return }
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(converted.frameLength)))
            if let snapshot = accumulator.append(samples, capturedAt: ProcessInfo.processInfo.systemUptime) {
                delivery.submit(snapshot)
            }
        }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        rollingAccumulator = accumulator
        rollingDelivery = delivery
        rollingEngine = engine
    }

    private func stopRollingCapture() {
        rollingDelivery?.cancel()
        rollingEngine?.inputNode.removeTap(onBus: 0)
        rollingEngine?.stop()
        rollingAccumulator?.reset()
        rollingDelivery = nil
        rollingAccumulator = nil
        rollingEngine = nil
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
