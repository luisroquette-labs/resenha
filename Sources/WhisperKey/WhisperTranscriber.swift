import AVFoundation
import Foundation
import whisper

enum WhisperError: LocalizedError {
    case modelMissing(String)
    case failed(Int32, String)
    case timedOut
    case emptyTranscript
    case invalidAudio
    case modelLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelMissing(let paths): "Whisper model not found: \(paths)"
        case .failed(let code, let detail): "Whisper failed (\(code)): \(detail)"
        case .timedOut: "Whisper exceeded the local transcription time limit."
        case .emptyTranscript: "No speech was detected."
        case .invalidAudio: "The captured audio is not valid 16 kHz mono PCM."
        case .modelLoadFailed(let path): "Whisper could not load the local model: \(path)"
        }
    }
}

struct WhisperPaths: Sendable {
    let model: URL

    static var modelDirectory: URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return applicationSupport.appendingPathComponent("WhisperKey/Models", isDirectory: true)
    }

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        home: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws -> WhisperPaths {
        let defaultHome = FileManager.default.homeDirectoryForCurrentUser
        let modelDirectory = home == defaultHome
            ? Self.modelDirectory
            : home.appendingPathComponent("Library/Application Support/WhisperKey/Models")
        let modelCandidates = [
            environment["WHISPER_MODEL_PATH"].map(URL.init(fileURLWithPath:)),
            modelDirectory.appendingPathComponent("ggml-large-v3-turbo-q5_0.bin"),
            modelDirectory.appendingPathComponent("ggml-small-q5_1.bin")
        ].compactMap { $0 }
        guard let model = modelCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw WhisperError.modelMissing(modelCandidates.map(\.path).joined(separator: ", "))
        }
        return WhisperPaths(model: model)
    }
}

final class WhisperExecutionControl: @unchecked Sendable {
    private enum StopReason { case cancelled, timedOut }
    private let lock = NSLock()
    private var reason: StopReason?
    private var callbackPolls = 0
    private var callbackAborted = false
    private let deadline: TimeInterval
    private let clock: @Sendable () -> TimeInterval

    init(maximumRuntime: TimeInterval = WhisperTranscriber.maximumRuntime,
         clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.clock = clock
        deadline = clock() + max(0, maximumRuntime)
    }

    func cancel() {
        lock.withLock {
            if reason == nil { reason = clock() >= deadline ? .timedOut : .cancelled }
        }
    }

    private func stopReason() -> StopReason? {
        lock.withLock {
            if reason == nil, clock() >= deadline { reason = .timedOut }
            return reason
        }
    }

    var shouldAbort: Bool {
        lock.withLock {
            if reason == nil, clock() >= deadline { reason = .timedOut }
            callbackPolls += 1
            if reason != nil { callbackAborted = true }
            return reason != nil
        }
    }

    var abortCallbackPolls: Int { lock.withLock { callbackPolls } }
    var didAbortInference: Bool { lock.withLock { callbackAborted } }

    func check() throws {
        switch stopReason() {
        case .cancelled: throw CancellationError()
        case .timedOut: throw WhisperError.timedOut
        case nil: return
        }
    }
}

struct WhisperTranscriber: Sendable {
    static let maximumRuntime: TimeInterval = 10 * 60
    private static let engine = EmbeddedWhisperEngine()
    var infer: @Sendable ([Float], String, String, WhisperExecutionControl) throws -> String = { samples, language, prompt, control in
        try WhisperTranscriber.engine.transcribe(samples: samples, model: WhisperPaths.resolve().model,
            language: language, prompt: prompt, control: control)
    }
    var removeAudio: @Sendable (URL) throws -> Void = { url in
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { }
    }

    // Consumes the captured WAV; callers that need a reusable fixture must pass a copy.
    func transcribe(
        audioURL: URL,
        language: TranscriptionLanguage = .portuguese,
        glossaryText: String = TranscriptionGlossary.defaultText,
        control: WhisperExecutionControl = WhisperExecutionControl()
    ) async throws -> String {
        try await withTaskCancellationHandler {
            try consumeRecording(audioURL: audioURL, language: language, glossaryText: glossaryText, control: control)
        } onCancel: { control.cancel() }
    }

    private func consumeRecording(audioURL: URL, language: TranscriptionLanguage,
                                  glossaryText: String, control: WhisperExecutionControl) throws -> String {
        var removed = false
        func removeRecording() throws {
            guard !removed else { return }
            try removeAudio(audioURL)
            removed = true
        }
        defer { try? removeRecording() }
        try control.check()
        let glossary = TranscriptionGlossary(text: glossaryText)
        let samples = try Self.readSamples(from: audioURL)
        try removeRecording()
        try control.check()
        let raw = try infer(samples, language.rawValue, glossary.prompt, control)
        try control.check()
        let transcript = TranscriptPostprocessor.process(raw, glossary: glossary)
        try control.check()
        guard !transcript.isEmpty else { throw WhisperError.emptyTranscript }
        return transcript
    }

    private static func readSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard format.sampleRate == 16_000, format.channelCount == 1,
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: format,
                  frameCapacity: AVAudioFrameCount(file.length)
              ) else { throw WhisperError.invalidAudio }
        try file.read(into: buffer)
        guard let channel = buffer.floatChannelData?.pointee else { throw WhisperError.invalidAudio }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }
}

final class EmbeddedWhisperEngine: @unchecked Sendable {
    private let access = DispatchSemaphore(value: 1)
    private let inference: (@Sendable (whisper_full_params, [Float]) throws -> String)?
    private let onWait: (@Sendable () -> Void)?
    private var context: OpaquePointer?
    private var modelPath: String?

    init(inference: (@Sendable (whisper_full_params, [Float]) throws -> String)? = nil,
         onWait: (@Sendable () -> Void)? = nil) {
        self.inference = inference
        self.onWait = onWait
    }

    deinit {
        if let context { whisper_free(context) }
    }

    func transcribe(
        samples: [Float],
        model: URL,
        language: String,
        prompt: String,
        control: WhisperExecutionControl
    ) throws -> String {
        try control.check()
        while access.wait(timeout: .now() + .milliseconds(10)) == .timedOut {
            onWait?()
            try control.check()
        }
        defer { access.signal() }
        try control.check()
        var params = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        params.n_threads = Int32(max(2, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
        params.translate = false
        params.no_context = true
        params.no_timestamps = true
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.suppress_blank = true
        params.beam_search.beam_size = 5
        let retained = Unmanaged.passRetained(control)
        defer { retained.release() }
        params.abort_callback_user_data = retained.toOpaque()
        params.abort_callback = { pointer in
            guard let pointer else { return true }
            return Unmanaged<WhisperExecutionControl>.fromOpaque(pointer).takeUnretainedValue().shouldAbort
        }

        if let inference {
            do {
                let result = try inference(params, samples)
                try control.check()
                return result
            } catch {
                try control.check()
                throw error
            }
        }
        let context = try loadContext(model: model)
        try control.check()

        let status = language.withCString { languagePointer in
            prompt.withCString { promptPointer in
                params.language = languagePointer
                params.initial_prompt = prompt.isEmpty ? nil : promptPointer
                return samples.withUnsafeBufferPointer { buffer in
                    whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
                }
            }
        }
        // whisper.cpp uses -6/-8/-9 for encode/decode failure and abort alike.
        try control.check()
        guard status == 0 else { throw WhisperError.failed(status, "embedded whisper.cpp inference failed") }

        return (0..<whisper_full_n_segments(context)).compactMap { index in
            whisper_full_get_segment_text(context, index).map(String.init(cString:))
        }.joined()
    }

    private func loadContext(model: URL) throws -> OpaquePointer {
        if let context, modelPath == model.path { return context }
        if let context { whisper_free(context) }
        var parameters = whisper_context_default_params()
        parameters.use_gpu = true
        parameters.flash_attn = true
        guard let loaded = model.path.withCString({ whisper_init_from_file_with_params($0, parameters) }) else {
            context = nil
            modelPath = nil
            throw WhisperError.modelLoadFailed(model.path)
        }
        context = loaded
        modelPath = model.path
        return loaded
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

    enum CorrectionValidationError: Equatable {
        case empty, identical, invalidCharacters, lineLimit, entryLimit, textLimit, promptLimit
        case conflict(existingCanonical: String)
        case ineffective

        var message: String {
            switch self {
            case .empty: "Preencha os dois campos."
            case .identical: "Informe uma correção diferente do texto ouvido."
            case .invalidCharacters: "Use uma única linha, sem o caractere =, em cada campo."
            case .lineLimit: "Use até 160 caracteres e 2.560 bytes por campo. O texto anterior foi preservado."
            case .entryLimit: "O glossário atingiu 200 entradas. Revise-o em Ajustes → Transcrição."
            case .textLimit: "O glossário atingiu 20.000 caracteres. Revise-o em Ajustes → Transcrição."
            case .promptLimit: "O vocabulário excede 8.000 caracteres. Reduza o glossário em Ajustes → Transcrição."
            case .conflict: "Há uma substituição manual conflitante no glossário. Revise-a em Ajustes → Transcrição."
            case .ineffective: "O termo não cabe integralmente no vocabulário. Revise o glossário em Ajustes → Transcrição."
            }
        }
    }

    enum CorrectionCandidate: Equatable {
        case added(text: String)
        case alreadyExists
        case invalid(CorrectionValidationError)
    }

    static let maximumCorrectionFieldCharacters = maximumLineCharacters
    static let maximumCorrectionFieldBytes = maximumCorrectionFieldCharacters * 16

    static func acceptsCorrectionField(_ text: String) -> Bool {
        // Bound bytes first: a single grapheme can contain an unbounded combining sequence.
        text.utf8.prefix(maximumCorrectionFieldBytes + 1).count <= maximumCorrectionFieldBytes
            && text.prefix(maximumCorrectionFieldCharacters + 1).count <= maximumCorrectionFieldCharacters
    }

    static func feedbackVocabularyCandidate(heard: String, canonical: String, existingText: String) -> CorrectionCandidate {
        guard acceptsCorrectionField(heard), acceptsCorrectionField(canonical) else { return .invalid(.lineLimit) }
        // Check before trimming so a pasted trailing newline cannot change the rule grammar.
        guard ![heard, canonical].contains(where: {
            $0.rangeOfCharacter(from: .newlines) != nil || $0.contains("=")
        }) else { return .invalid(.invalidCharacters) }
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonical = canonical.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty, !canonical.isEmpty else { return .invalid(.empty) }
        guard heard != canonical else { return .invalid(.identical) }
        guard existingText.prefix(ProductPreferences.maximumGlossaryCharacters + 1).count
                <= ProductPreferences.maximumGlossaryCharacters else { return .invalid(.textLimit) }
        func matches(_ text: String, _ source: String) -> Bool {
            let regex = try? NSRegularExpression(
                pattern: "\\A\(NSRegularExpression.escapedPattern(for: source))\\z", options: [.caseInsensitive])
            return regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
        let previous = Self(text: existingText)
        let rawLines = existingText.components(separatedBy: .newlines)
        var acceptedCount = 0
        for rawLine in rawLines {
            let parsed = Self(text: rawLine)
            if !parsed.terms.isEmpty { acceptedCount += 1 }
            // Inspect unbounded lines too: an ignored or truncated conflict must remain visible.
            let parts = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            if parts.count == 2, let first = parts.first, let last = parts.last,
               !first.isEmpty, !last.isEmpty {
                if matches(first, heard) || matches(first, canonical), last != canonical {
                    return .invalid(.conflict(existingCanonical: last))
                }
            }
            for replacement in parsed.replacements where matches(replacement.heard, canonical) && replacement.canonical != canonical {
                return .invalid(.conflict(existingCanonical: replacement.canonical))
            }
        }
        if previous.terms.contains(canonical) {
            return .alreadyExists
        }
        guard acceptedCount < maximumTerms else { return .invalid(.entryLimit) }
        let separator = existingText.isEmpty || existingText.last?.isNewline == true ? "" : "\n"
        guard existingText.count + separator.count + canonical.count <= ProductPreferences.maximumGlossaryCharacters
        else { return .invalid(.textLimit) }
        let candidate = existingText + separator + canonical
        let parsed = Self(text: candidate)
        guard parsed.terms.joined(separator: ", ").count <= maximumPromptCharacters else { return .invalid(.promptLimit) }
        guard parsed.terms.contains(canonical),
              previous.replacements.allSatisfy(parsed.replacements.contains) else { return .invalid(.ineffective) }
        return .added(text: candidate)
    }
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
