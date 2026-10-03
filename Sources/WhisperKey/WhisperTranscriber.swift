import Foundation
import Darwin

enum WhisperError: LocalizedError {
    case executableMissing(String)
    case modelMissing(String)
    case failed(Int32, String)
    case timedOut
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .executableMissing(let paths): "whisper-cli not found: \(paths)"
        case .modelMissing(let paths): "Whisper model not found: \(paths)"
        case .failed(let code, let detail): "Whisper failed (\(code)): \(detail)"
        case .timedOut: "Whisper exceeded the local transcription time limit."
        case .emptyTranscript: "No speech was detected."
        }
    }
}

struct WhisperPaths: Sendable {
    let executable: URL
    let model: URL

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> WhisperPaths {
        let executableCandidates = [
            environment["WHISPER_CLI_PATH"],
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli"
        ].compactMap { $0 }.map(URL.init(fileURLWithPath:))
        guard let executable = executableCandidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) else {
            throw WhisperError.executableMissing(executableCandidates.map(\.path).joined(separator: ", "))
        }

        let modelDirectory = home.appendingPathComponent("Library/Application Support/WhisperKey/Models")
        let modelCandidates = [
            environment["WHISPER_MODEL_PATH"].map(URL.init(fileURLWithPath:)),
            modelDirectory.appendingPathComponent("ggml-large-v3-turbo-q5_0.bin"),
            modelDirectory.appendingPathComponent("ggml-small-q5_1.bin")
        ].compactMap { $0 }
        guard let model = modelCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw WhisperError.modelMissing(modelCandidates.map(\.path).joined(separator: ", "))
        }
        return WhisperPaths(executable: executable, model: model)
    }
}

struct WhisperTranscriber: Sendable {
    static let maximumRuntime: TimeInterval = 10 * 60
    private static let terminationGracePeriod: TimeInterval = 1

    func transcribe(
        audioURL: URL,
        language: TranscriptionLanguage = .portuguese,
        glossaryText: String = TranscriptionGlossary.defaultText
    ) throws -> String {
        let paths = try WhisperPaths.resolve()
        let glossary = TranscriptionGlossary(text: glossaryText)
        let outputPrefix = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisperKey-\(UUID().uuidString)")
        let outputURL = outputPrefix.appendingPathExtension("txt")
        let diagnosticURL = outputPrefix.appendingPathExtension("log")
        guard FileManager.default.createFile(
            atPath: diagnosticURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else { throw CocoaError(.fileWriteUnknown) }
        let diagnosticHandle = try FileHandle(forWritingTo: diagnosticURL)
        defer {
            try? diagnosticHandle.close()
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: diagnosticURL)
        }

        let process = Process()
        process.executableURL = paths.executable
        process.arguments = [
            "-m", paths.model.path,
            "-f", audioURL.path,
            "-l", language.rawValue,
            "-otxt",
            "-of", outputPrefix.path,
            "-np",
            "-nt"
        ]
        if !glossary.prompt.isEmpty { process.arguments! += ["--prompt", glossary.prompt] }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = diagnosticHandle
        try process.run()
        let startedAt = Date()
        while process.isRunning {
            if Task.isCancelled {
                stop(process)
                throw CancellationError()
            }
            if WhisperProcessPolicy.hasTimedOut(
                startedAt: startedAt,
                now: Date(),
                maximumRuntime: Self.maximumRuntime
            ) {
                stop(process)
                throw WhisperError.timedOut
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        try diagnosticHandle.close()
        let errorText = String(decoding: readPrefix(of: diagnosticURL, limit: 64 * 1_024), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw WhisperError.failed(process.terminationStatus, errorText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let raw = try String(contentsOf: outputURL, encoding: .utf8)
        let transcript = TranscriptPostprocessor.process(raw, glossary: glossary)
        guard !transcript.isEmpty else { throw WhisperError.emptyTranscript }
        return transcript
    }

    private func readPrefix(of url: URL, limit: Int) -> Data {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return Data() }
        defer { try? handle.close() }
        return (try? handle.read(upToCount: limit)) ?? Data()
    }

    private func stop(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(Self.terminationGracePeriod)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
    }
}

enum WhisperProcessPolicy {
    static func hasTimedOut(startedAt: Date, now: Date, maximumRuntime: TimeInterval) -> Bool {
        now.timeIntervalSince(startedAt) >= max(0, maximumRuntime)
    }
}

struct TranscriptionGlossary: Equatable, Sendable {
    struct Replacement: Equatable, Sendable { let heard: String; let canonical: String }
    static let maximumTerms = 200
    static let maximumLineCharacters = 160
    static let maximumPromptCharacters = 8_000

    static let defaultText = """
    Resenha
    GitHub
    README
    whisper.cpp
    whisper.cp = whisper.cpp
    whisper.ctp = whisper.cpp
    SwiftUI
    macOS
    pull request
    benchmark
    onboarding
    feedback
    loading time
    dashboard
    deadline
    """

    let terms: [String]
    let replacements: [Replacement]

    init(text: String) {
        var terms: [String] = []
        var replacements: [Replacement] = []
        for rawLine in text.components(separatedBy: .newlines) {
            guard terms.count < Self.maximumTerms else { break }
            let line = String(rawLine.prefix(Self.maximumLineCharacters))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if parts.count == 2, parts.contains(where: { $0.isEmpty }) { continue }
            let canonical = parts.last ?? line
            guard !canonical.isEmpty else { continue }
            terms.append(canonical)
            if parts.count == 2, !parts[0].isEmpty {
                replacements.append(.init(heard: parts[0], canonical: canonical))
            }
        }
        self.terms = Array(Set(terms)).sorted()
        self.replacements = (replacements + self.terms.map { .init(heard: $0, canonical: $0) })
            .sorted { $0.heard.count > $1.heard.count }
    }

    var prompt: String { String(terms.joined(separator: ", ").prefix(Self.maximumPromptCharacters)) }
}

enum TranscriptPostprocessor {
    static func process(_ raw: String, glossary: TranscriptionGlossary) -> String {
        var text = TranscriptNormalizer.normalize(raw)
        if let sentenceSpacing = try? NSRegularExpression(pattern: #"([.!?])(?=\p{Lu})"#) {
            text = sentenceSpacing.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: "$1 "
            )
        }
        for replacement in glossary.replacements {
            let escaped = NSRegularExpression.escapedPattern(for: replacement.heard)
            guard let regex = try? NSRegularExpression(
                pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
                options: [.caseInsensitive]
            ) else { continue }
            text = regex.stringByReplacingMatches(
                in: text,
                range: NSRange(text.startIndex..., in: text),
                withTemplate: NSRegularExpression.escapedTemplate(for: replacement.canonical)
            )
        }
        text = normalizePortugueseTime(in: text)
        return applyExplicitCorrection(to: text)
    }

    private static func normalizePortugueseTime(in text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"\bàs\s+((?:[01]?\d|2[0-3]))\s+horas\b"#,
            options: [.caseInsensitive]
        ) else { return text }
        return regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: "às $1h00"
        )
    }

    static func applyExplicitCorrection(to text: String) -> String {
        let pattern = #"(?is)^(.*)(\b(?:para|pra)\s+)([^.?!]+)([.?!])\s*(?:não\s*[,，.!?]?\s*)*(?:corrige|corrija|corrigir)\s*[.?!:]\s*(.+?[.?!]?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let base = Range(match.range(at: 1), in: text),
              let preposition = Range(match.range(at: 2), in: text),
              let replacement = Range(match.range(at: 5), in: text) else { return text }
        var replacementText = String(text[replacement]).trimmingCharacters(in: .whitespaces)
        let weekdays = ["Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado", "Domingo"]
        if let weekday = weekdays.first(where: { replacementText.hasPrefix($0) }) {
            let end = replacementText.index(replacementText.startIndex, offsetBy: weekday.count)
            replacementText.replaceSubrange(replacementText.startIndex..<end, with: weekday.lowercased())
        }
        let startsWithTimePreposition = replacementText.lowercased().hasPrefix("às ")
        if startsWithTimePreposition, let first = replacementText.first {
            replacementText.replaceSubrange(replacementText.startIndex...replacementText.startIndex, with: String(first).lowercased())
        }
        var corrected = String(text[base])
            + (startsWithTimePreposition ? "" : String(text[preposition]))
            + replacementText
        if corrected.last?.isPunctuation != true { corrected += "." }
        return corrected
    }
}

enum TranscriptNormalizer {
    static func normalize(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !($0.hasPrefix("[") && $0.hasSuffix("]")) }
            .joined(separator: " ")
    }
}
