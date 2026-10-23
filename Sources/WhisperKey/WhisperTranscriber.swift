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

struct WhisperAlternativeToken: Equatable, Sendable {
    let tokenID: Int32
    let text: String
    let logit: Float
}

struct WhisperTokenEvidence: Equatable, Sendable {
    let tokenID: Int32
    let text: String
    let probability: Float
    let alternatives: [WhisperAlternativeToken]
}

struct WhisperInferenceResult: Equatable, Sendable {
    let text: String
    let tokenEvidence: [WhisperTokenEvidence]
}

struct WhisperTranscription: Equatable, Sendable {
    let text: String
    let tokenEvidence: [WhisperTokenEvidence]
}

struct WhisperTranscriber: Sendable {
    typealias Inference = @Sendable ([Float], String, String, WhisperExecutionControl) throws -> WhisperInferenceResult
    typealias LegacyInference = @Sendable ([Float], String, String, WhisperExecutionControl) throws -> String
    static let maximumRuntime: TimeInterval = 10 * 60
    static let supportsProactiveEvidence = true
    private static let engine = EmbeddedWhisperEngine()
    private static let defaultInference: Inference = { samples, language, prompt, control in
        try WhisperTranscriber.engine.transcribeWithEvidence(samples: samples, model: WhisperPaths.resolve().model,
            language: language, prompt: prompt, control: control)
    }
    private static let defaultRollingScheduler = RollingWhisperScheduler(infer: defaultInference)
    private static let defaultRemoveAudio: @Sendable (URL) throws -> Void = { url in
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { }
    }

    private let infer: Inference
    private let removeAudio: @Sendable (URL) throws -> Void
    private let supportsRollingInference: Bool
    private let rollingScheduler: RollingWhisperScheduler

    init() {
        infer = Self.defaultInference
        removeAudio = Self.defaultRemoveAudio
        supportsRollingInference = true
        rollingScheduler = Self.defaultRollingScheduler
    }

    init(
        resultInference: @escaping Inference,
        removeAudio: @escaping @Sendable (URL) throws -> Void = WhisperTranscriber.defaultRemoveAudio,
        supportsRollingInference: Bool = true
    ) {
        infer = resultInference
        self.removeAudio = removeAudio
        self.supportsRollingInference = supportsRollingInference
        rollingScheduler = RollingWhisperScheduler(infer: resultInference)
    }

    init(
        infer: @escaping LegacyInference,
        removeAudio: @escaping @Sendable (URL) throws -> Void = WhisperTranscriber.defaultRemoveAudio,
        supportsRollingInference: Bool = true
    ) {
        self.init(
            resultInference: { samples, language, prompt, control in
                WhisperInferenceResult(
                    text: try infer(samples, language, prompt, control),
                    tokenEvidence: []
                )
            },
            removeAudio: removeAudio,
            supportsRollingInference: supportsRollingInference
        )
    }

    // Consumes the captured WAV; callers that need a reusable fixture must pass a copy.
    func transcribe(
        audioURL: URL,
        language: TranscriptionLanguage = .portuguese,
        glossaryText: String = TranscriptionGlossary.defaultText,
        control: WhisperExecutionControl = WhisperExecutionControl()
    ) async throws -> String {
        try await transcribeWithEvidence(
            audioURL: audioURL,
            language: language,
            glossaryText: glossaryText,
            control: control
        ).text
    }

    func transcribeWithEvidence(
        audioURL: URL,
        language: TranscriptionLanguage = .portuguese,
        glossaryText: String = TranscriptionGlossary.defaultText,
        promptTerms: [String] = [],
        control: WhisperExecutionControl = WhisperExecutionControl()
    ) async throws -> WhisperTranscription {
        try await withTaskCancellationHandler {
            try consumeRecording(
                audioURL: audioURL,
                language: language,
                glossaryText: glossaryText,
                promptTerms: promptTerms,
                control: control
            )
        } onCancel: { control.cancel() }
    }

    func makeRollingRecognizer(
        language: TranscriptionLanguage = .portuguese,
        glossaryText: String = TranscriptionGlossary.defaultText,
        promptTerms: @escaping @Sendable () -> [String] = { [] },
        maximumRuntime: TimeInterval = WhisperTranscriber.maximumRuntime,
        clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        onHypothesis: @escaping @Sendable (RollingWhisperHypothesis) -> Void
    ) -> RollingWhisperRecognizer? {
        guard supportsRollingInference else { return nil }
        return RollingWhisperRecognizer(
            scheduler: rollingScheduler,
            language: language.rawValue,
            baseGlossaryText: glossaryText,
            promptTerms: promptTerms,
            maximumRuntime: maximumRuntime,
            clock: clock,
            onHypothesis: onHypothesis
        )
    }

    private func consumeRecording(audioURL: URL, language: TranscriptionLanguage,
                                  glossaryText: String, promptTerms: [String],
                                  control: WhisperExecutionControl) throws -> WhisperTranscription {
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
        let raw = try infer(
            samples,
            language.rawValue,
            Self.prompt(glossaryText: glossaryText, adding: promptTerms),
            control
        )
        try control.check()
        let transcript = TranscriptPostprocessor.process(raw.text, glossary: glossary)
        try control.check()
        guard !transcript.isEmpty else { throw WhisperError.emptyTranscript }
        return WhisperTranscription(text: transcript, tokenEvidence: raw.tokenEvidence)
    }

    static func prompt(glossaryText: String, adding terms: [String]) -> String {
        let base = TranscriptionGlossary(text: glossaryText).terms
        var seen = Set<String>()
        var accepted: [String] = []
        for term in base + terms {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "pt_BR")
            )
            guard seen.insert(key).inserted else { continue }
            let candidate = (accepted + [trimmed]).joined(separator: ", ")
            guard candidate.count <= TranscriptionGlossary.maximumPromptCharacters else { continue }
            accepted.append(trimmed)
        }
        return accepted.joined(separator: ", ")
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

struct RollingWhisperHypothesis: Equatable, Sendable {
    let snapshotID: UInt64
    let sampleRange: Range<Int64>
    let capturedAt: TimeInterval
    let candidateAt: TimeInterval
    let text: String
    let tokenEvidence: [WhisperTokenEvidence]
    let isStale: Bool

    init(
        snapshotID: UInt64,
        sampleRange: Range<Int64>,
        capturedAt: TimeInterval,
        candidateAt: TimeInterval,
        text: String,
        tokenEvidence: [WhisperTokenEvidence] = [],
        isStale: Bool = false
    ) {
        self.snapshotID = snapshotID
        self.sampleRange = sampleRange
        self.capturedAt = capturedAt
        self.candidateAt = candidateAt
        self.text = text
        self.tokenEvidence = tokenEvidence
        self.isStale = isStale
    }

    var isProvisional: Bool { true }
}

final class RollingWhisperRecognizer: @unchecked Sendable {
    private let scheduler: RollingWhisperScheduler
    private let sessionID: UUID

    init(
        scheduler: RollingWhisperScheduler,
        language: String,
        baseGlossaryText: String,
        promptTerms: @escaping @Sendable () -> [String],
        maximumRuntime: TimeInterval,
        clock: @escaping @Sendable () -> TimeInterval,
        onHypothesis: @escaping @Sendable (RollingWhisperHypothesis) -> Void
    ) {
        self.scheduler = scheduler
        sessionID = scheduler.register(
            language: language,
            baseGlossaryText: baseGlossaryText,
            promptTerms: promptTerms,
            maximumRuntime: maximumRuntime,
            clock: clock,
            onHypothesis: onHypothesis
        )
    }

    func submit(_ snapshot: AudioSampleSnapshot) {
        scheduler.submit(snapshot, sessionID: sessionID)
    }

    func cancel() {
        scheduler.cancel(sessionID: sessionID)
    }

    deinit {
        scheduler.cancel(sessionID: sessionID)
    }

    var queuedInferenceCount: Int { scheduler.queuedInferenceCount }
}

final class RollingWhisperScheduler: @unchecked Sendable {
    private struct Session: Sendable {
        let language: String
        let baseGlossaryText: String
        let promptTerms: @Sendable () -> [String]
        let maximumRuntime: TimeInterval
        let clock: @Sendable () -> TimeInterval
        let onHypothesis: @Sendable (RollingWhisperHypothesis) -> Void
        var generation: UInt64 = 0
        var lastDeliveredText: String?
        var isCancelled = false
    }

    private struct Work: Sendable {
        let sessionID: UUID
        let snapshot: AudioSampleSnapshot
        let generation: UInt64
    }

    private struct Active {
        let work: Work
        let control: WhisperExecutionControl
    }

    private let lock = NSLock()
    private let infer: WhisperTranscriber.Inference
    private var sessions: [UUID: Session] = [:]
    private var active: Active?
    private var pending: Work?

    init(infer: @escaping WhisperTranscriber.Inference) {
        self.infer = infer
    }

    func register(
        language: String,
        baseGlossaryText: String,
        promptTerms: @escaping @Sendable () -> [String],
        maximumRuntime: TimeInterval,
        clock: @escaping @Sendable () -> TimeInterval,
        onHypothesis: @escaping @Sendable (RollingWhisperHypothesis) -> Void
    ) -> UUID {
        let id = UUID()
        lock.withLock {
            sessions[id] = Session(
                language: language,
                baseGlossaryText: baseGlossaryText,
                promptTerms: promptTerms,
                maximumRuntime: maximumRuntime,
                clock: clock,
                onHypothesis: onHypothesis
            )
        }
        return id
    }

    func submit(_ snapshot: AudioSampleSnapshot, sessionID: UUID) {
        let activeToStart: Active? = lock.withLock {
            guard let session = sessions[sessionID], !session.isCancelled else { return nil }
            if active?.work.sessionID == sessionID,
               active?.work.snapshot.samples == snapshot.samples,
               active?.work.snapshot.sampleRange == snapshot.sampleRange { return nil }
            if pending?.sessionID == sessionID,
               pending?.snapshot.samples == snapshot.samples,
               pending?.snapshot.sampleRange == snapshot.sampleRange { return nil }
            let work = Work(sessionID: sessionID, snapshot: snapshot, generation: session.generation)
            guard active == nil else {
                pending = work
                return nil
            }
            let newActive = Active(
                work: work,
                control: WhisperExecutionControl(maximumRuntime: session.maximumRuntime, clock: session.clock)
            )
            active = newActive
            return newActive
        }
        if let activeToStart { run(activeToStart) }
    }

    func cancel(sessionID: UUID) {
        let control: WhisperExecutionControl? = lock.withLock {
            guard var session = sessions[sessionID], !session.isCancelled else { return nil }
            session.isCancelled = true
            session.generation &+= 1
            sessions[sessionID] = session
            if pending?.sessionID == sessionID { pending = nil }
            if active?.work.sessionID == sessionID { return active?.control }
            sessions.removeValue(forKey: sessionID)
            return nil
        }
        control?.cancel()
    }

    var queuedInferenceCount: Int {
        lock.withLock { (active == nil ? 0 : 1) + (pending == nil ? 0 : 1) }
    }

    private func run(_ item: Active) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let result = Result {
                try item.control.check()
                guard let session = self.lock.withLock({ self.sessions[item.work.sessionID] }) else {
                    throw CancellationError()
                }
                let raw = try self.infer(
                    item.work.snapshot.samples,
                    session.language,
                    WhisperTranscriber.prompt(
                        glossaryText: session.baseGlossaryText,
                        adding: session.promptTerms()
                    ),
                    item.control
                )
                return WhisperInferenceResult(
                    text: TranscriptNormalizer.normalize(raw.text),
                    tokenEvidence: raw.tokenEvidence
                )
            }
            self.finish(item, result: result)
        }
    }

    private func finish(_ completed: Active, result: Result<WhisperInferenceResult, Error>) {
        var hypothesis: RollingWhisperHypothesis?
        var callback: (@Sendable (RollingWhisperHypothesis) -> Void)?
        var next: Active?
        lock.withLock {
            guard var session = sessions[completed.work.sessionID] else { return }
            let stale = session.isCancelled
                || completed.work.generation != session.generation
                || active?.work.sessionID != completed.work.sessionID
                || active?.work.snapshot.id != completed.work.snapshot.id
            if case .success(let result) = result, !result.text.isEmpty,
               (stale || session.lastDeliveredText != result.text) {
                hypothesis = RollingWhisperHypothesis(
                    snapshotID: completed.work.snapshot.id,
                    sampleRange: completed.work.snapshot.sampleRange,
                    capturedAt: completed.work.snapshot.capturedAt,
                    candidateAt: session.clock(),
                    text: result.text,
                    tokenEvidence: result.tokenEvidence,
                    isStale: stale
                )
                callback = session.onHypothesis
                if !stale {
                    session.lastDeliveredText = result.text
                    sessions[completed.work.sessionID] = session
                }
            }
            guard active?.work.sessionID == completed.work.sessionID,
                  active?.work.snapshot.id == completed.work.snapshot.id else { return }
            active = nil
            if let pending, let pendingSession = sessions[pending.sessionID], !pendingSession.isCancelled {
                self.pending = nil
                let nextActive = Active(
                    work: pending,
                    control: WhisperExecutionControl(
                        maximumRuntime: pendingSession.maximumRuntime,
                        clock: pendingSession.clock
                    )
                )
                active = nextActive
                next = nextActive
            } else {
                pending = nil
            }
            if session.isCancelled { sessions.removeValue(forKey: completed.work.sessionID) }
        }
        if let hypothesis, let callback { callback(hypothesis) }
        if let next { run(next) }
    }
}

final class WhisperLogitCollector: @unchecked Sendable {
    struct Snapshot: Equatable, Sendable {
        let prefixSuffix: [Int32]
        let alternatives: [WhisperAlternativeToken]
    }

    private let lock = NSLock()
    private var snapshots: [Snapshot] = []

    init(snapshots: [Snapshot] = []) {
        self.snapshots = snapshots
    }

    func record(
        context: OpaquePointer,
        tokens: UnsafePointer<whisper_token_data>?,
        tokenCount: Int32,
        logits: UnsafeMutablePointer<Float>?
    ) {
        guard let logits else { return }
        let vocabularyCount = Int(whisper_n_vocab(context))
        let endOfText = Int(whisper_token_eot(context))
        guard vocabularyCount > 0, endOfText > 0 else { return }

        var ranked = Array(repeating: ResenhaLogitCandidate(token_id: 0, logit: 0), count: 16)
        let retained = ranked.withUnsafeMutableBufferPointer { output in
            resenha_top_logits(logits, Int32(min(vocabularyCount, endOfText)), 16, output.baseAddress)
        }
        let alternatives = ranked.prefix(Int(retained)).compactMap { candidate -> WhisperAlternativeToken? in
            guard let pointer = whisper_token_to_str(context, candidate.token_id),
                  let text = String(validatingCString: pointer),
                  !text.hasPrefix("<|"),
                  text.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains) else { return nil }
            return WhisperAlternativeToken(tokenID: candidate.token_id, text: text, logit: candidate.logit)
        }.prefix(4)
        guard !alternatives.isEmpty else { return }
        let start = max(0, Int(tokenCount) - 128)
        let prefix = tokens.map { pointer in
            (start..<Int(tokenCount)).map { pointer[$0].id }
        } ?? []
        lock.withLock {
            snapshots.append(Snapshot(prefixSuffix: prefix, alternatives: Array(alternatives)))
            if snapshots.count > 256 { snapshots.removeFirst(snapshots.count - 256) }
        }
    }

    func align(
        tokenIDs: [Int32],
        tokenTexts: [String],
        probabilities: [Float],
        endOfText: Int32
    ) -> [WhisperTokenEvidence] {
        guard tokenIDs.count == tokenTexts.count, tokenIDs.count == probabilities.count else { return [] }
        let aligned: [WhisperTokenEvidence] = tokenIDs.indices.compactMap { index in
            let tokenID = tokenIDs[index]
            let text = tokenTexts[index]
            guard tokenID < endOfText,
                  !text.hasPrefix("<|"),
                  text.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains) else { return nil }
            let prior = Array(tokenIDs[..<index])
            let alternatives = bestSnapshot(matching: prior)?.alternatives ?? []
            return WhisperTokenEvidence(
                tokenID: tokenID,
                text: text,
                probability: probabilities[index],
                alternatives: alternatives
            )
        }
        var characterCount = 0
        var retained: [WhisperTokenEvidence] = []
        for item in aligned.suffix(128).reversed() {
            guard characterCount + item.text.count <= 600 else { break }
            characterCount += item.text.count
            retained.append(item)
        }
        return retained.reversed()
    }

    private func bestSnapshot(matching prior: [Int32]) -> Snapshot? {
        guard !prior.isEmpty else { return nil }
        let snapshots = lock.withLock { self.snapshots }
        var best: (score: Int, snapshot: Snapshot)?
        for snapshot in snapshots {
            let limit = min(prior.count, snapshot.prefixSuffix.count)
            var score = 0
            while score < limit,
                  prior[prior.count - 1 - score] == snapshot.prefixSuffix[snapshot.prefixSuffix.count - 1 - score] {
                score += 1
            }
            let required = min(prior.count, 128)
            guard score == required, score >= (best?.score ?? 0) else { continue }
            best = (score, snapshot)
        }
        return best?.snapshot
    }
}

final class EmbeddedWhisperEngine: @unchecked Sendable {
    private let access = DispatchSemaphore(value: 1)
    private let inference: (@Sendable (whisper_full_params, [Float]) throws -> String)?
    private let onWait: (@Sendable () -> Void)?
    private let collectsTokenEvidence: Bool
    private var context: OpaquePointer?
    private var modelPath: String?

    init(inference: (@Sendable (whisper_full_params, [Float]) throws -> String)? = nil,
         onWait: (@Sendable () -> Void)? = nil,
         collectsTokenEvidence: Bool = true) {
        self.inference = inference
        self.onWait = onWait
        self.collectsTokenEvidence = collectsTokenEvidence
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
        try transcribeWithEvidence(
            samples: samples,
            model: model,
            language: language,
            prompt: prompt,
            control: control
        ).text
    }

    func transcribeWithEvidence(
        samples: [Float],
        model: URL,
        language: String,
        prompt: String,
        control: WhisperExecutionControl
    ) throws -> WhisperInferenceResult {
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
                return WhisperInferenceResult(text: result, tokenEvidence: [])
            } catch {
                try control.check()
                throw error
            }
        }
        let context = try loadContext(model: model)
        try control.check()
        let collector = collectsTokenEvidence ? WhisperLogitCollector() : nil
        let retainedCollector = collector.map(Unmanaged.passRetained)
        defer { retainedCollector?.release() }
        if let retainedCollector {
            params.logits_filter_callback_user_data = retainedCollector.toOpaque()
            params.logits_filter_callback = { context, _, tokens, tokenCount, logits, userData in
                guard let context, let userData else { return }
                Unmanaged<WhisperLogitCollector>.fromOpaque(userData).takeUnretainedValue().record(
                    context: context,
                    tokens: tokens,
                    tokenCount: tokenCount,
                    logits: logits
                )
            }
        }

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

        let text = (0..<whisper_full_n_segments(context)).compactMap { index in
            whisper_full_get_segment_text(context, index).map(String.init(cString:))
        }.joined()
        var tokenIDs: [Int32] = []
        var tokenTexts: [String] = []
        var probabilities: [Float] = []
        for segment in 0..<whisper_full_n_segments(context) {
            for token in 0..<whisper_full_n_tokens(context, segment) {
                tokenIDs.append(whisper_full_get_token_id(context, segment, token))
                tokenTexts.append(
                    whisper_full_get_token_text(context, segment, token).map(String.init(cString:)) ?? ""
                )
                probabilities.append(whisper_full_get_token_p(context, segment, token))
            }
        }
        return WhisperInferenceResult(
            text: text,
            tokenEvidence: collector?.align(
                tokenIDs: tokenIDs,
                tokenTexts: tokenTexts,
                probabilities: probabilities,
                endOfText: whisper_token_eot(context)
            ) ?? []
        )
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
