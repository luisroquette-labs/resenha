import AppKit
import SwiftUI

struct PanelDismissal {
    private(set) var generation: UInt = 0
    private(set) var deadline: TimeInterval?

    mutating func invalidate(deadline: TimeInterval? = nil) {
        generation &+= 1
        self.deadline = deadline
    }

    mutating func dismissIfCurrent(generation: UInt, now: TimeInterval) -> Bool {
        guard generation == self.generation, let deadline, now >= deadline else { return false }
        self.deadline = nil
        return true
    }
}

@MainActor
private final class CorrectionSession: ObservableObject {
    let context: DictationCompletion
    var token: UUID?
    var recoveryID = UUID()
    var isEditing = false
    @Published var heard = ""
    @Published var canonical = ""
    @Published var errorMessage: String?
    @Published var invalidField: TranscriptionCorrectionView.Field?
    var actionID: UUID { token ?? recoveryID }

    init(context: DictationCompletion) {
        self.context = context
        token = context.id
    }
}

private struct CorrectionEditor: View {
    @ObservedObject var session: CorrectionSession
    @ObservedObject var preferences: ProductPreferences
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        TranscriptionCorrectionView(
            heard: $session.heard, canonical: $session.canonical,
            errorMessage: session.errorMessage, invalidField: session.invalidField,
            isSaveEnabled: preferences.canSaveTranscriptionCorrection && session.token != nil,
            onSave: onSave, onCancel: onCancel
        )
    }
}

@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private let model = FloatingPanelModel()
    private lazy var panel: NSPanel = makePanel()
    private var dismissalTask: Task<Void, Never>?
    private var onDismiss: (@MainActor () -> Void)?
    private(set) var dismissal = PanelDismissal()
    private(set) var target: PanelTarget = .standalone(nil)
    private var screenSelection = PanelScreenSelection()
    private let clock: () -> TimeInterval
    private(set) var selectedScreenID: UInt32?
    private var feedback: CorrectionSession?
    private(set) var correctionWindow: NSWindow?
    private var correctionPreferences: ProductPreferences?
    var onFeedbackChange: (@MainActor () -> Void)?
    var hasFeedback: Bool { feedback != nil }
    var isEditingCorrection: Bool { feedback?.isEditing == true }
    var feedbackToken: UUID? { feedback?.token }
    var correctionActionToken: UUID? { feedback?.actionID }
    var approvalActionToken: UUID? { isEditingCorrection ? nil : feedback?.token }
    var correctionDraft: (heard: String, canonical: String)? {
        feedback.map { ($0.heard, $0.canonical) }
    }
    var correctionError: String? { feedback?.errorMessage }
    var canSaveCorrection: Bool {
        isEditingCorrection && feedbackToken != nil && correctionPreferences?.canSaveTranscriptionCorrection == true
    }
    var ignoresMouseEvents: Bool { panel.ignoresMouseEvents }
    var isVisible: Bool { panel.isVisible }
    var status: FloatingStatus { model.status }
    var frame: CGRect { panel.frame }
    var recordingMeter: RecordingMeter { model.recording }

    init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.clock = clock
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        rememberFrontmostTarget()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func captureSessionTarget(pid: pid_t?) {
        let screens = currentScreens()
        screenSelection.beginSession(pid: pid, window: focusedWindowFrame(pid: pid), screens: screens, mainID: mainScreenID)
    }

    func show(_ status: FloatingStatus, target: PanelTarget = .standalone(nil)) {
        discardFeedback()
        present(status, target: target)
    }

    private func present(_ status: FloatingStatus, target: PanelTarget) {
        invalidateDismissal()
        self.target = target
        model.show(status, now: clock())
        panel.ignoresMouseEvents = status != .feedback
        selectTargetScreen(target)
        positionPanel()
        panel.orderFrontRegardless()
    }

    func showTemporarily(
        _ status: FloatingStatus,
        target: PanelTarget = .standalone(nil),
        onDismiss: (@MainActor () -> Void)? = nil
    ) {
        show(status, target: target)
        dismissal.invalidate(deadline: ProcessInfo.processInfo.systemUptime + 2)
        self.onDismiss = onDismiss
        let generation = dismissal.generation
        dismissalTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled else { return }
            self?.dismissIfCurrent(generation: generation, now: ProcessInfo.processInfo.systemUptime)
        }
    }

    func hide() {
        discardFeedback()
        invalidateDismissal()
        panel.orderOut(nil)
        screenSelection.endSession()
        model.recording = RecordingMeter()
    }

    func configureFeedback(preferences: ProductPreferences) {
        correctionPreferences = preferences
    }

    func offerFeedback(_ context: DictationCompletion) {
        hide()
        feedback = CorrectionSession(context: context)
        panel.contentView = NSHostingView(rootView: FloatingStatusView(model: model,
            onApprove: { [weak self] in self?.approveFeedback(token: context.id) },
            onCorrect: { [weak self] in self?.openCorrection(token: context.id) }))
        present(.feedback, target: .session(context.targetApplication?.processIdentifier))
        onFeedbackChange?()
    }

    func approveFeedback(token: UUID) {
        guard approvalActionToken == token else { return }
        hide()
    }

    func openCorrection(token: UUID) {
        guard let session = feedback, session.actionID == token,
              let preferences = correctionPreferences else { return }
        if session.isEditing {
            NSApplication.shared.activate(ignoringOtherApps: true)
            correctionWindow?.makeKeyAndOrderFront(nil)
            return
        }
        if session.token == nil || !preferences.canSaveTranscriptionCorrection {
            if preferences.reloadTranscriptionGlossaryForCorrection() {
                session.token = UUID()
                session.errorMessage = nil
            } else {
                session.token = nil
                session.errorMessage = ProductPreferences.CorrectionSaveResult.storageFailure(recoveryRequired: true).message
            }
        }
        session.isEditing = true
        invalidateDismissal()
        panel.orderOut(nil)
        panel.ignoresMouseEvents = true
        let actionID = session.actionID
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Corrigir transcrição"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: CorrectionEditor(
            session: session, preferences: preferences,
            onSave: { [weak self] in self?.saveCorrection(token: actionID) },
            onCancel: { [weak self] in self?.cancelFeedback(token: actionID) }
        ))
        let screen = NSScreen.screens.first { screenID($0) == selectedScreenID } ?? NSScreen.main
        if let screen {
            window.setContentSize(TranscriptionCorrectionView.panelSize(available: screen.visibleFrame.size))
            window.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - window.frame.width / 2,
                                          y: screen.visibleFrame.midY - window.frame.height / 2))
        }
        correctionWindow = window
        onFeedbackChange?()
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        if let error = session.errorMessage { announce(error) }
    }

    func updateCorrectionDraft(token: UUID, heard: String, canonical: String) {
        guard let session = feedback, session.actionID == token, session.isEditing else { return }
        session.heard = heard
        session.canonical = canonical
    }

    func saveCorrection(token: UUID) {
        guard let session = feedback, session.token == token, canSaveCorrection,
              let preferences = correctionPreferences else { return }
        let result = preferences.saveTranscriptionCorrection(heard: session.heard, canonical: session.canonical)
        switch result {
        case .saved, .alreadyExists:
            announce(result.message)
            let context = session.context
            hide()
            let restored = restoreTarget(context)
            showTemporarily(.feedbackNotice(restored ? result.message : "\(result.message). Volte ao campo de texto para ditar"))
        case .invalid, .storageFailure:
            session.errorMessage = result.message
            let invalidCharacters = CharacterSet.newlines.union(CharacterSet(charactersIn: "="))
            let heardInvalid = session.heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || session.heard.rangeOfCharacter(from: invalidCharacters) != nil
            let canonicalInvalid = session.canonical.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || session.canonical.rangeOfCharacter(from: invalidCharacters) != nil
            session.invalidField = !heardInvalid && canonicalInvalid ? .canonical : .heard
            announce(result.message)
        }
    }

    func cancelCorrectionForHotkey(token: UUID) {
        guard correctionActionToken == token, isEditingCorrection else { return }
        let restored = cancelFeedback(token: token)
        let guidance = FloatingStatus.feedbackNotice(restored
            ? "Solte e pressione novamente para ditar"
            : "Volte ao campo de texto. Solte e pressione novamente para ditar")
        if hasFeedback {
            // Recovery remains available until an external press actually starts the next dictation.
            present(guidance, target: .standalone(nil))
        } else {
            showTemporarily(guidance)
        }
    }

    @discardableResult
    func cancelFeedback(token: UUID, restoreFocus: Bool = true) -> Bool {
        guard let session = feedback, session.actionID == token else { return false }
        let context = session.context
        if session.isEditing && correctionPreferences?.canSaveTranscriptionCorrection == false {
            session.token = nil
            session.recoveryID = UUID()
            session.isEditing = false
            closeCorrectionWindow()
            invalidateDismissal()
            panel.orderOut(nil)
            panel.ignoresMouseEvents = true
            onFeedbackChange?()
        } else {
            hide()
        }
        if restoreFocus && !restoreTarget(context) {
            present(.feedbackNotice("Volte ao campo de texto para ditar"), target: .standalone(nil))
            return false
        }
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === correctionWindow, let token = correctionActionToken else { return true }
        cancelFeedback(token: token)
        return false
    }

    private func closeCorrectionWindow() {
        let window = correctionWindow
        correctionWindow = nil
        window?.delegate = nil
        window?.close()
    }

    private func discardFeedback() {
        guard feedback != nil else { return }
        feedback = nil
        closeCorrectionWindow()
        panel.ignoresMouseEvents = true
        onFeedbackChange?()
    }

    private func restoreTarget(_ context: DictationCompletion) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier else { return true }
        guard let application = context.targetApplication, !application.isTerminated,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return false }
        return application.activate(options: [])
    }

    private func announce(_ message: String) {
        NSAccessibility.post(element: correctionWindow ?? panel, notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func updateRecordingLevel(_ level: Float) {
        guard model.status == .listening else { return }
        model.recording.append(level: level, at: clock())
    }

    func dismissIfCurrent(generation: UInt, now: TimeInterval) {
        guard dismissal.dismissIfCurrent(generation: generation, now: now) else { return }
        let completion = onDismiss
        hide()
        completion?()
    }

    private func invalidateDismissal() {
        dismissalTask?.cancel()
        dismissalTask = nil
        onDismiss = nil
        dismissal.invalidate()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: FloatingStatusView(model: model))
        return panel
    }

    private var mainScreenID: UInt32? { NSScreen.main.map(screenID) }

    private func screenID(_ screen: NSScreen) -> UInt32 {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    private func currentScreens() -> [PanelScreen] {
        NSScreen.screens.map { PanelScreen(id: screenID($0), frame: $0.frame, visibleFrame: $0.visibleFrame) }
    }

    private func rememberFrontmostTarget() {
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if pid != ProcessInfo.processInfo.processIdentifier { screenSelection.rememberExternalTarget(pid) }
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        screenSelection.rememberExternalTarget(app.processIdentifier)
    }

    private func selectTargetScreen(_ target: PanelTarget) {
        let screens = currentScreens()
        switch target {
        case .session(let pid):
            if !screenSelection.hasSession || screenSelection.sessionTarget != pid { captureSessionTarget(pid: pid) }
            selectedScreenID = screenSelection.sessionScreen(screens: screens, mainID: mainScreenID)?.id
        case .standalone(let explicit):
            let pid = screenSelection.standaloneTarget(explicit: explicit,
                frontmost: NSWorkspace.shared.frontmostApplication?.processIdentifier,
                ownPID: ProcessInfo.processInfo.processIdentifier)
            screenSelection.rememberExternalTarget(pid)
            selectedScreenID = screenSelection.resolve(pid: pid, window: focusedWindowFrame(pid: pid), screens: screens, mainID: mainScreenID)?.id
        }
    }

    private func focusedWindowFrame(pid: pid_t?) -> CGRect? {
        nil
    }

    @objc private func screensChanged() {
        guard panel.isVisible else { return }
        positionPanel()
    }

    private func positionPanel() {
        let screens = currentScreens()
        let fallback = screens.contains(where: { $0.id == selectedScreenID }) ? selectedScreenID : mainScreenID
        let screen = PanelPlacement.screen(for: nil, screens: screens, fallbackID: fallback)
        guard let screen else { return }
        selectedScreenID = screen.id
        if screenSelection.hasSession { _ = screenSelection.sessionScreen(screens: screens, mainID: screen.id) }
        let size = FloatingStatusView.panelSize(for: model.status, available: screen.visibleFrame.size)
        panel.setFrame(PanelPlacement.panelFrame(size: size, visibleFrame: screen.visibleFrame), display: true)
    }
}
