import AppKit

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
            self.init(title: "Transcrição demorou demais", diagnostic: nil, recovery: "O processo local foi encerrado. Tente novamente com um áudio menor.")
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
    private let permissions: PermissionService
    private let panel: FloatingPanelController
    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private let injector = TextInjector()
    private let cuePlayer = DictationCuePlayer()
    private(set) var phase = DictationPhase.idle {
        didSet { if oldValue != phase { onPhaseChange?(phase) } }
    }
    var onPhaseChange: (@MainActor (DictationPhase) -> Void)?
    private(set) var currentError: DictationErrorPresentation?
    private var targetApplication: NSRunningApplication?
    private var task: Task<Void, Never>?
    private var attemptID = UUID()
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
        onFailure: @escaping (DictationErrorPresentation) -> Void = { _ in }
    ) {
        self.permissions = permissions
        self.panel = panel
        self.showsHUD = showsHUD
        self.soundsEnabled = soundsEnabled
        self.language = language
        self.glossaryText = glossaryText
        self.onTranscript = onTranscript
        self.onFailure = onFailure
        recorder.onLevel = { [weak panel] level in
            panel?.updateRecordingLevel(level)
            onRecordingLevel(level)
        }
    }

    func hotkeyPressed() {
        guard phase == .idle else { return }
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
            let audioURL = try recorder.stop()
            transition(to: .transcribing)
            if soundsEnabled() { cuePlayer.play(.stopped) }
            if showsHUD() { panel.show(.transcribing, target: panelTarget) }
            let attemptID = attemptID
            let sessionLanguage = sessionLanguage
            let glossaryText = glossaryText()

            task = Task {
                defer { try? FileManager.default.removeItem(at: audioURL) }
                do {
                    let transcriptionTask = Task.detached(priority: .userInitiated) {
                        try self.transcriber.transcribe(
                            audioURL: audioURL,
                            language: sessionLanguage,
                            glossaryText: glossaryText
                        )
                    }
                    let transcript = try await withTaskCancellationHandler {
                        try await transcriptionTask.value
                    } onCancel: {
                        transcriptionTask.cancel()
                    }
                    try Task.checkCancellation()
                    guard self.attemptID == attemptID else { return }
                    let changeCount = try self.injector.stage(transcript)
                    self.onTranscript(transcript)
                    self.transition(to: .inserting)
                    if self.showsHUD() { self.panel.show(.inserting, target: self.panelTarget) }
                    try await self.injector.insertStaged(into: self.targetApplication, changeCount: changeCount)
                    self.transition(to: .idle)
                    self.reset()
                } catch is CancellationError {
                    guard self.attemptID == attemptID else { return }
                    self.reset()
                } catch {
                    guard self.attemptID == attemptID else { return }
                    self.fail(DictationErrorPresentation(error: error))
                }
            }
        } catch {
            fail(DictationErrorPresentation(error: error))
        }
    }

    func cancel() {
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
        targetApplication = nil
        panel.hide()
        if clearError { currentError = nil }
        phase = .idle
    }
}
