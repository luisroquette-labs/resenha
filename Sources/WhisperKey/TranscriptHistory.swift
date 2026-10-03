import AppKit

struct TranscriptHistoryItem: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let text: String
}

@MainActor
final class TranscriptHistory {
    static let limit = 10
    static let maximumTextCharacters = 100_000
    static let maximumFileBytes = 2 * 1_024 * 1_024

    private let fileURL: URL
    private(set) var items: [TranscriptHistoryItem]
    private(set) var storageAvailable = true
    var onChange: (([TranscriptHistoryItem], Bool) -> Void)?

    init(fileURL: URL? = nil) {
        let resolvedURL = fileURL ?? Self.defaultURL()
        self.fileURL = resolvedURL
        Self.prepareDirectory(for: resolvedURL)
        items = Self.load(from: resolvedURL)
    }

    func add(_ rawText: String, now: Date = Date()) {
        let text = String(rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(Self.maximumTextCharacters))
        guard !text.isEmpty else { return }
        if items.first?.text == text { items.removeFirst() }
        items.insert(TranscriptHistoryItem(id: UUID(), createdAt: now, text: text), at: 0)
        items = Array(items.prefix(Self.limit))
        storageAvailable = persist()
        onChange?(items, storageAvailable)
    }

    func clear() {
        items = []
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            storageAvailable = true
        } catch {
            storageAvailable = false
        }
        onChange?(items, storageAvailable)
    }

    @discardableResult
    private func persist() -> Bool {
        do {
            Self.prepareDirectory(for: fileURL)
            try JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            return true
        } catch {
            // Clipboard remains the primary recovery path; transcript content is never logged.
            return false
        }
    }

    private static func load(from fileURL: URL) -> [TranscriptHistoryItem] {
        if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > maximumFileBytes {
            quarantine(fileURL)
            return []
        }
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        guard let decoded = try? JSONDecoder().decode([TranscriptHistoryItem].self, from: data) else {
            quarantine(fileURL)
            return []
        }
        return Array(decoded.lazy.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { TranscriptHistoryItem(id: $0.id, createdAt: $0.createdAt, text: String($0.text.prefix(maximumTextCharacters))) }
            .prefix(limit))
    }

    private static func quarantine(_ fileURL: URL) {
        let preserved = fileURL.deletingPathExtension()
            .appendingPathExtension("corrupt-\(UUID().uuidString).json")
        try? FileManager.default.moveItem(at: fileURL, to: preserved)
    }

    private static func defaultURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Resenha", isDirectory: true)
            .appendingPathComponent("recent-transcripts.json")
    }

    private static func prepareDirectory(for fileURL: URL) {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }
}

enum DictationCue: Equatable {
    case ready
    case started
    case stopped

    var nativeSoundName: NSSound.Name? {
        switch self {
        case .ready: nil
        case .started: NSSound.Name("Tink")
        case .stopped: NSSound.Name("Pop")
        }
    }
    var maximumDuration: Duration { self == .ready ? .milliseconds(500) : .milliseconds(250) }
    var volume: Float { self == .ready ? 0.62 : 0.35 }

    func makeSound(readySound: ResenhaSound = ResenhaSoundCatalog.defaultSound) -> NSSound? {
        switch self {
        case .ready:
            NSSound(data: ResenhaSoundRenderer.wavData(for: readySound))
        case .started, .stopped:
            nativeSoundName.flatMap(NSSound.init(named:))
        }
    }
}

enum ResenhaReadyTone {
    static let sampleRate = ResenhaSoundRenderer.sampleRate
    static let wavData = ResenhaSoundRenderer.wavData(for: ResenhaSoundCatalog.defaultSound)
}

@MainActor
final class DictationCuePlayer {
    private var sound: NSSound?
    private var stopTask: Task<Void, Never>?

    func play(_ cue: DictationCue, readySound: ResenhaSound = ResenhaSoundCatalog.defaultSound) {
        stopTask?.cancel()
        sound?.stop()
        guard let sound = cue.makeSound(readySound: readySound) else { return }
        sound.volume = cue.volume
        self.sound = sound
        sound.play()
        stopTask = Task { [weak self, weak sound] in
            do { try await Task.sleep(for: cue.maximumDuration) } catch { return }
            sound?.stop()
            self?.sound = nil
        }
    }

    func preview(_ preset: ResenhaSound) {
        stopTask?.cancel()
        sound?.stop()
        guard let sound = NSSound(data: ResenhaSoundRenderer.wavData(for: preset)) else { return }
        sound.volume = 0.62
        self.sound = sound
        sound.play()
        stopTask = Task { [weak self, weak sound] in
            do { try await Task.sleep(for: .milliseconds(Int64(preset.duration * 1_000) + 30)) } catch { return }
            sound?.stop()
            self?.sound = nil
        }
    }
}
