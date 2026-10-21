import AppKit

struct DictationCompletion {
    let id: UUID
    let targetApplication: NSRunningApplication?
    let text: String
    let language: TranscriptionLanguage
    let retentionProbe: ContextRetentionProbe?

    init(
        id: UUID,
        targetApplication: NSRunningApplication?,
        text: String,
        language: TranscriptionLanguage,
        retentionProbe: ContextRetentionProbe? = nil
    ) {
        self.id = id
        self.targetApplication = targetApplication
        self.text = text
        self.language = language
        self.retentionProbe = retentionProbe
    }

    init(id: UUID, targetApplication: NSRunningApplication?) {
        self.init(
            id: id,
            targetApplication: targetApplication,
            text: "",
            language: .portuguese
        )
    }
}

final class ContextRetentionProbe {
    private let onDeinit: () -> Void
    init(onDeinit: @escaping () -> Void) { self.onDeinit = onDeinit }
    deinit { onDeinit() }
}

typealias ContextualPolicyTokenSource = @MainActor @Sendable (UUID) -> ContextualPolicyToken
typealias ContextualStoreGenerationSource = @MainActor @Sendable () -> UInt64

@MainActor
protocol DictationOutputSink {
    func stage(_ text: String) throws -> Int
    func insertStaged(into target: NSRunningApplication?, changeCount: Int) async throws
}

extension TextInjector: DictationOutputSink {}

enum DictationPhase: Equatable {
    case idle
    case recording
    case transcribing
    case inserting
    case failed

    var acceptsStatusFeedback: Bool { self == .idle }
    var shouldStopRecordingForPermissionLoss: Bool { self == .recording }

    func canTransition(to next: DictationPhase) -> Bool {
        switch (self, next) {
        case (.idle, .recording),
             (.recording, .transcribing),
             (.transcribing, .inserting),
             (.inserting, .idle),
             (.failed, .idle): true
        case (_, .failed): self != .idle
        default: false
        }
    }
}

struct DictationErrorPresentation: Equatable {
    let title: String
    let diagnostic: String?
    let recovery: String
    var isPermissionFailure = false

    static func permission(_ snapshot: PermissionSnapshot) -> Self {
        Self(title: snapshot.missingPermissionMessage, diagnostic: nil,
             recovery: "Ative a permissão ausente pelo menu do Resenha.", isPermissionFailure: true)
    }

    init(title: String, diagnostic: String?, recovery: String, isPermissionFailure: Bool = false) {
        self.title = title
        self.diagnostic = diagnostic
        self.recovery = recovery
        self.isPermissionFailure = isPermissionFailure
    }

    init(error: Error) {
        switch error {
        case WhisperError.modelMissing(let paths):
            self.init(title: "Modelo Whisper não encontrado", diagnostic: paths, recovery: "Instale o modelo local ou confira o caminho configurado.")
        case WhisperError.modelLoadFailed(let path):
            self.init(title: "Falha ao abrir o modelo Whisper", diagnostic: path, recovery: "Baixe novamente o modelo local e tente de novo.")
        case WhisperError.failed(let code, _):
            self.init(title: "Falha na transcrição", diagnostic: "Código de saída: \(code)", recovery: "Confira o Whisper e o modelo local e tente novamente.")
        case WhisperError.timedOut:
            self.init(title: "Transcrição demorou demais", diagnostic: nil, recovery: "A transcrição local foi interrompida. Tente novamente com um áudio menor.")
        case WhisperError.emptyTranscript, TextInjectionError.emptyText:
            self.init(title: "Nenhuma fala detectada", diagnostic: nil, recovery: "Segure seu atalho, fale e solte.")
        case WhisperError.invalidAudio:
            self.init(title: "Áudio inválido", diagnostic: nil, recovery: "Confira o microfone e tente novamente.")
        case TextInjectionError.clipboardUnavailable:
            self.init(title: "Falha ao guardar o texto", diagnostic: nil, recovery: "Confira o clipboard e tente novamente.")
        case TextInjectionError.accessibilityUnavailable:
            self.init(title: "Acessibilidade necessária", diagnostic: nil, recovery: "Ative o Resenha em Privacidade e Segurança → Acessibilidade.", isPermissionFailure: true)
        case TextInjectionError.clipboardChanged:
            self.init(title: "O clipboard mudou", diagnostic: nil, recovery: "O texto continua no histórico do Resenha. Tente novamente.")
        case TextInjectionError.targetUnavailable:
            self.init(title: "O aplicativo original não está disponível", diagnostic: nil, recovery: "Volte ao campo de texto e tente novamente.")
        case TextInjectionError.eventCreationFailed:
            self.init(title: "Não foi possível inserir o texto", diagnostic: nil, recovery: "O texto está no clipboard. Use Command-V.")
        case is AudioRecorderError:
            self.init(title: "Microfone indisponível", diagnostic: nil, recovery: "Confira o acesso e a disponibilidade do microfone.")
        default:
            self.init(title: "Falha no ditado", diagnostic: nil, recovery: "Confira as permissões e o mecanismo local e tente novamente.")
        }
    }
}

@MainActor
final class DictationCoordinator {
    static func productionContextualTokenSource(
        policy: ContextualCorrectionPolicy,
        isEnabled: @escaping @MainActor @Sendable () -> Bool
    ) -> ContextualPolicyTokenSource {
        { _ in policy.issueToken(scope: isEnabled() ? .personalDictation : .disabled) }
    }

    private let permissions: PermissionService
    private let panel: FloatingPanelController
    private let recorder = AudioRecorder()
    private let transcriber: WhisperTranscriber
    private let outputSink: any DictationOutputSink
    private let contextualResolver: any ContextualResolving
    private let contextualTokenSource: ContextualPolicyTokenSource
    private let contextualStoreGeneration: ContextualStoreGenerationSource
    private let cuePlayer = DictationCuePlayer()
    private(set) var phase = DictationPhase.idle {
        didSet { if oldValue != phase { onPhaseChange?(phase) } }
    }
    var onPhaseChange: (@MainActor (DictationPhase) -> Void)?
    var onCompleted: (@MainActor (DictationCompletion) -> Void)?
    private(set) var currentError: DictationErrorPresentation?
    private var targetApplication: NSRunningApplication?
    private var task: Task<Void, Never>?
    private var executionControl: WhisperExecutionControl?
    private(set) var attemptID = UUID()
    private let showsHUD: () -> Bool
    private let soundsEnabled: () -> Bool
    private let onTranscript: (String) -> Void
    private let onFailure: (DictationErrorPresentation) -> Void
    private let language: () -> TranscriptionLanguage
    private let glossaryText: () -> String
    private var sessionLanguage = TranscriptionLanguage.portuguese
    private var panelTarget: PanelTarget { .session(targetApplication?.processIdentifier) }

    init(
        permissions: PermissionService,
        panel: FloatingPanelController,
        showsHUD: @escaping () -> Bool = { true },
        soundsEnabled: @escaping () -> Bool = { true },
        language: @escaping () -> TranscriptionLanguage = { .portuguese },
        glossaryText: @escaping () -> String = { TranscriptionGlossary.defaultText },
        onRecordingLevel: @escaping (Float) -> Void = { _ in },
        onTranscript: @escaping (String) -> Void = { _ in },
        onFailure: @escaping (DictationErrorPresentation) -> Void = { _ in },
        transcriber: WhisperTranscriber = WhisperTranscriber(),
        outputSink: any DictationOutputSink,
        contextualResolver: any ContextualResolving,
        contextualTokenSource: @escaping ContextualPolicyTokenSource,
        contextualStoreGeneration: @escaping ContextualStoreGenerationSource
    ) {
        self.permissions = permissions
        self.panel = panel
        self.showsHUD = showsHUD
        self.soundsEnabled = soundsEnabled
        self.language = language
        self.glossaryText = glossaryText
        self.onTranscript = onTranscript
        self.onFailure = onFailure
        self.transcriber = transcriber
        self.outputSink = outputSink
        self.contextualResolver = contextualResolver
        self.contextualTokenSource = contextualTokenSource
        self.contextualStoreGeneration = contextualStoreGeneration
        recorder.onLevel = { [weak panel] level in
            panel?.updateRecordingLevel(level)
            onRecordingLevel(level)
        }
    }

    func hotkeyPressed() {
        guard phase == .idle else { return }
        panel.hide()
        attemptID = UUID()
        currentError = nil
        sessionLanguage = language()
        targetApplication = NSWorkspace.shared.frontmostApplication
        panel.captureSessionTarget(pid: targetApplication?.processIdentifier)
        let snapshot = permissions.snapshot
        guard snapshot.isReady else {
            fail(.permission(snapshot))
            return
        }

        do {
            try recorder.start()
            transition(to: .recording)
            if soundsEnabled() { cuePlayer.play(.started) }
            if showsHUD() { panel.show(.listening, target: panelTarget) }
        } catch {
            fail(DictationErrorPresentation(error: error))
        }
    }

    func hotkeyReleased() {
        guard phase == .recording else { return }
        do {
            transcribeRecording(at: try recorder.stop())
        } catch {
            fail(DictationErrorPresentation(error: error))
        }
    }

    func transcribeRecording(at audioURL: URL) {
        precondition(phase == .recording)
        let control = WhisperExecutionControl()
        executionControl = control
        transition(to: .transcribing)
        if soundsEnabled() { cuePlayer.play(.stopped) }
        if showsHUD() { panel.show(.transcribing, target: panelTarget) }
        let attemptID = attemptID
        let sessionLanguage = sessionLanguage
        let glossaryText = glossaryText()
        let transcriber = transcriber

        task = Task {
            do {
                let transcriptionTask = Task.detached(priority: .userInitiated) {
                    try await transcriber.transcribe(
                        audioURL: audioURL,
                        language: sessionLanguage,
                        glossaryText: glossaryText,
                        control: control
                    )
                }
                let transcript = try await withTaskCancellationHandler {
                    try await transcriptionTask.value
                } onCancel: {
                    control.cancel()
                    transcriptionTask.cancel()
                }
                try await self.finishTranscription(
                    transcript,
                    attemptID: attemptID,
                    language: sessionLanguage
                )
            } catch is CancellationError {
                guard self.attemptID == attemptID else { return }
                self.reset()
            } catch {
                guard self.attemptID == attemptID else { return }
                self.fail(DictationErrorPresentation(error: error))
            }
        }
    }

    func finishTranscription(
        _ transcript: String,
        attemptID: UUID,
        language: TranscriptionLanguage
    ) async throws {
        let generation = contextualStoreGeneration()
        let token = contextualTokenSource(attemptID)
        let final = await contextualResolver.resolve(.init(
            attemptID: attemptID,
            text: transcript,
            language: language.rawValue,
            policyToken: token,
            storeGenerationAtStart: generation
        ))
        try Task.checkCancellation()
        guard self.attemptID == attemptID,
              phase == .transcribing,
              generation == contextualStoreGeneration(),
              token.generation == contextualTokenSource(attemptID).generation else {
            if self.attemptID == attemptID { reset() }
            return
        }

        let target = targetApplication
        let changeCount = try outputSink.stage(final)
        onTranscript(final)
        transition(to: .inserting)
        if showsHUD() { panel.show(.inserting, target: panelTarget) }
        try await outputSink.insertStaged(into: target, changeCount: changeCount)
        guard !Task.isCancelled,
              self.attemptID == attemptID,
              phase == .inserting,
              generation == contextualStoreGeneration(),
              token.generation == contextualTokenSource(attemptID).generation else {
            if self.attemptID == attemptID { reset() }
            return
        }
        let completion = DictationCompletion(
            id: attemptID,
            targetApplication: target,
            text: final,
            language: language
        )
        reset()
        if showsHUD() { onCompleted?(completion) }
    }

    // Called only after insertStaged returns successfully; identity is checked after its suspension.
    func completeInsertion(
        attemptID: UUID,
        isCancelled: Bool,
        text: String,
        language: TranscriptionLanguage
    ) {
        guard !isCancelled, self.attemptID == attemptID, phase == .inserting else { return }
        let completion = DictationCompletion(
            id: attemptID,
            targetApplication: targetApplication,
            text: text,
            language: language
        )
        reset()
        if showsHUD() { onCompleted?(completion) }
    }

    func completeInsertion(attemptID: UUID, isCancelled: Bool) {
        completeInsertion(
            attemptID: attemptID,
            isCancelled: isCancelled,
            text: "",
            language: sessionLanguage
        )
    }

    func cancel() {
        executionControl?.cancel()
        task?.cancel()
        task = nil
        recorder.cancel()
        reset()
    }

    func permissionLost(_ snapshot: PermissionSnapshot) {
        guard !snapshot.isReady, phase.shouldStopRecordingForPermissionLoss else { return }
        fail(.permission(snapshot))
    }

    func permissionsRestored() {
        if currentError?.isPermissionFailure == true { currentError = nil }
    }

    func transition(to next: DictationPhase) {
        precondition(phase.canTransition(to: next), "Invalid dictation transition: \(phase) → \(next)")
        phase = next
    }

    func fail(_ error: DictationErrorPresentation) {
        currentError = error
        onFailure(error)
        recorder.cancel()
        phase = .failed
        let attemptID = attemptID
        guard showsHUD() else {
            reset(clearError: false)
            return
        }
        panel.showTemporarily(.failure(error.title), target: panelTarget) { [weak self] in
            guard let self, self.attemptID == attemptID, self.phase == .failed else { return }
            self.reset(clearError: false)
        }
    }

    private func reset(clearError: Bool = true) {
        attemptID = UUID()
        task = nil
        executionControl = nil
        targetApplication = nil
        panel.hide()
        if clearError { currentError = nil }
        phase = .idle
    }
}
