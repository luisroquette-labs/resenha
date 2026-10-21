import AppKit
import Combine
import SwiftUI

struct PanelDismissal {
    private(set) var generation: UInt = 0
    private(set) var deadline: TimeInterval?
    private(set) var feedbackToken: UUID?

    mutating func invalidate(deadline: TimeInterval? = nil, feedbackToken: UUID? = nil) {
        generation &+= 1
        self.deadline = deadline
        self.feedbackToken = feedbackToken
    }

    mutating func dismissIfCurrent(generation: UInt, now: TimeInterval) -> Bool {
        guard generation == self.generation, let deadline, now >= deadline else { return false }
        self.deadline = nil
        return true
    }
}

@MainActor
final class CorrectionSession: ObservableObject {
    private(set) var targetPID: pid_t?
    var token: UUID?
    var recoveryID = UUID()
    var isEditing = false
    @Published private(set) var heard = ""
    @Published private(set) var canonical = ""
    @Published var errorMessage: String?
    @Published var invalidField: TranscriptionCorrectionView.Field?
    @Published var rejectedEditGeneration = 0
    private(set) var inputLimitField: TranscriptionCorrectionView.Field?
    private(set) var language: TranscriptionLanguage
    private(set) var sentence: String
    @Published private(set) var candidateOrdinals: [Int] = []
    @Published private(set) var selectedOrdinal: Int?
    private var retentionProbe: ContextRetentionProbe?
    var actionID: UUID { token ?? recoveryID }
    var selectedContext: (sentence: String, occurrenceOrdinal: Int)? {
        let ranges = Self.occurrenceRanges(of: heard, in: sentence)
        guard let selectedOrdinal, ranges.indices.contains(selectedOrdinal - 1) else { return nil }
        let selectedRange = ranges[selectedOrdinal - 1]
        guard let sentenceRange = ContextualSentenceBoundary.ranges(in: sentence).first(where: {
            $0.lowerBound <= selectedRange.lowerBound && $0.upperBound >= selectedRange.upperBound
        }) else { return nil }
        let localRanges = ranges.filter {
            $0.lowerBound >= sentenceRange.lowerBound && $0.upperBound <= sentenceRange.upperBound
        }
        guard let localIndex = localRanges.firstIndex(of: selectedRange) else { return nil }
        return (
            String(sentence[sentenceRange]).trimmingCharacters(in: .whitespacesAndNewlines),
            localIndex + 1
        )
    }

    init(
        token: UUID,
        targetPID: pid_t?,
        text: String,
        language: TranscriptionLanguage,
        retentionProbe: ContextRetentionProbe?
    ) {
        self.targetPID = targetPID
        self.token = token
        sentence = text
        self.language = language
        self.retentionProbe = retentionProbe
    }

    func update(heard: String, canonical: String) {
        guard isEditing else { return }
        let invalid: TranscriptionCorrectionView.Field? = !TranscriptionGlossary.acceptsCorrectionField(heard)
            ? .heard : (!TranscriptionGlossary.acceptsCorrectionField(canonical) ? .canonical : nil)
        if let invalid {
            inputLimitField = invalid
            invalidField = invalid
            errorMessage = TranscriptionGlossary.CorrectionValidationError.lineLimit.message
            rejectedEditGeneration += 1
            return
        }
        self.heard = heard
        self.canonical = canonical
        let occurrenceCount = Self.occurrenceRanges(of: heard, in: sentence).count
        candidateOrdinals = occurrenceCount == 0 ? [] : Array(1...occurrenceCount)
        selectedOrdinal = candidateOrdinals.count == 1 ? candidateOrdinals[0] : nil
        if inputLimitField != nil { errorMessage = nil; inputLimitField = nil; invalidField = nil }
    }

    func select(ordinal: Int) {
        guard candidateOrdinals.contains(ordinal) else { return }
        selectedOrdinal = ordinal
        errorMessage = nil
    }

    func clear() {
        isEditing = false
        targetPID = nil
        heard = ""
        canonical = ""
        errorMessage = nil
        invalidField = nil
        inputLimitField = nil
        candidateOrdinals = []
        selectedOrdinal = nil
        sentence = ""
        retentionProbe = nil
        token = nil
    }

    private static func occurrenceRanges(of term: String, in sentence: String) -> [Range<String.Index>] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let escaped = NSRegularExpression.escapedPattern(for: trimmed)
        let regex = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])",
            options: [.caseInsensitive]
        )
        return regex?.matches(
            in: sentence,
            range: NSRange(sentence.startIndex..<sentence.endIndex, in: sentence)
        ).compactMap { Range($0.range, in: sentence) } ?? []
    }
}

private struct FeedbackOffer {
    let token: UUID
    let targetPID: pid_t?
    let text: String
    let language: TranscriptionLanguage
    let retentionProbe: ContextRetentionProbe?
}

private final class FeedbackTargetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class FeedbackTargetButton: NSButton {
    var handler: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    @objc func activateFeedback() { handler?() }
}

private struct CorrectionEditor: View {
    @ObservedObject var session: CorrectionSession
    let onSave: () -> Void
    let onCancel: () -> Void
    let onInvalidInput: () -> Void
    let requiresOccurrenceSelection: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(session.sentence)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Frase confirmada: \(session.sentence)")
            if session.candidateOrdinals.count > 1 {
                HStack {
                    Text("Qual ocorrência estava errada?")
                    ForEach(session.candidateOrdinals, id: \.self) { ordinal in
                        Button("\(ordinal)ª") { session.select(ordinal: ordinal) }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Selecionar ocorrência \(ordinal)")
                            .accessibilityAddTraits(session.selectedOrdinal == ordinal ? .isSelected : [])
                    }
                }
            }
            TranscriptionCorrectionView(
                heard: Binding(get: { session.heard }, set: { session.update(heard: $0, canonical: session.canonical) }),
                canonical: Binding(get: { session.canonical }, set: { session.update(heard: session.heard, canonical: $0) }),
                errorMessage: session.errorMessage,
                invalidField: session.invalidField,
                isSaveEnabled: session.token != nil && session.inputLimitField == nil
                    && (!requiresOccurrenceSelection || session.selectedOrdinal != nil),
                onSave: onSave, onCancel: onCancel
            )
        }
        .id(session.rejectedEditGeneration)
        .onChange(of: session.rejectedEditGeneration) { _, _ in onInvalidInput() }
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
    private var offeredFeedback: FeedbackOffer?
    private var recoveryOffer: FeedbackOffer?
    private var feedbackTargets: [NSPanel] = []
    private(set) var correctionWindow: NSWindow?
    private var correctionPreferences: ProductPreferences?
    private var contextualStore: ContextualCorrectionStore?
    var onFeedbackChange: (@MainActor () -> Void)?
    var hasFeedback: Bool { feedback != nil || offeredFeedback != nil || recoveryOffer != nil }
    var isEditingCorrection: Bool { feedback?.isEditing == true }
    var feedbackToken: UUID? { offeredFeedback?.token ?? feedback?.token }
    var correctionActionToken: UUID? { offeredFeedback?.token ?? feedback?.actionID ?? recoveryOffer?.token }
    var approvalActionToken: UUID? { isEditingCorrection ? nil : feedbackToken }
    var correctionDraft: (heard: String, canonical: String)? {
        feedback.map { ($0.heard, $0.canonical) }
    }
    var correctionError: String? { feedback?.errorMessage }
    var canSaveCorrection: Bool {
        guard isEditingCorrection, feedbackToken != nil, feedback?.inputLimitField == nil else { return false }
        if let contextualStore {
            return contextualStore.snapshot.health == .healthy && feedback?.selectedOrdinal != nil
        }
        return correctionPreferences?.canSaveTranscriptionCorrection == true
    }
    var ignoresMouseEvents: Bool { panel.ignoresMouseEvents }
    var isVisible: Bool { panel.isVisible }
    var status: FloatingStatus { model.status }
    var frame: CGRect { panel.frame }
    var recordingMeter: RecordingMeter { model.recording }
    var feedbackPhase: FeedbackBubblePhase { model.feedbackPhase }
    var activePresentationTaskCount: Int { dismissalTask == nil ? 0 : 1 }
    var feedbackTargetWindows: [NSPanel] { feedbackTargets }
    var correctionSession: CorrectionSession? { feedback }

    init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.clock = clock
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationActivated(_:)), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screensChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        rememberFrontmostTarget()
    }

    deinit {
        dismissalTask?.cancel()
        MainActor.assumeIsolated {
            feedback?.clear()
            removeFeedbackTargets()
            panel.orderOut(nil)
            panel.contentView = nil
            closeCorrectionWindow()
        }
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
        panel.ignoresMouseEvents = true
        panel.hasShadow = status != .feedback
        if panel.contentView == nil {
            panel.contentView = NSHostingView(rootView: FloatingStatusView(model: model, feedbackIsVisualOnly: true))
        }
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
        scheduleDismissal(after: 2)
        self.onDismiss = onDismiss
    }

    private func scheduleDismissal(after seconds: TimeInterval, feedbackToken: UUID? = nil) {
        dismissal.invalidate(deadline: clock() + seconds, feedbackToken: feedbackToken)
        let generation = dismissal.generation
        dismissalTask = Task { [weak self] in
            if feedbackToken != nil {
                await Task.yield()
                guard !Task.isCancelled else { return }
                self?.advanceFeedbackPresentation(generation: generation)
                let untilExit = self.map { max(0, ($0.dismissal.deadline ?? $0.clock()) - $0.clock() - 0.75) } ?? 0
                do { try await Task.sleep(for: .seconds(untilExit), clock: .suspending) } catch { return }
                guard !Task.isCancelled else { return }
                self?.advanceFeedbackPresentation(generation: generation)
            }
            let remaining = self.map { max(0, ($0.dismissal.deadline ?? $0.clock()) - $0.clock()) } ?? 0
            do { try await Task.sleep(for: .seconds(remaining), clock: .suspending) } catch { return }
            guard !Task.isCancelled, let self else { return }
            self.dismissIfCurrent(generation: generation, now: self.clock())
        }
    }

    func advanceFeedbackPresentation(generation: UInt) {
        guard generation == dismissal.generation, let deadline = dismissal.deadline,
              dismissal.feedbackToken == offeredFeedback?.token, offeredFeedback != nil,
              model.status == .feedback else { return }
        let now = clock()
        if now >= deadline { dismissIfCurrent(generation: generation, now: now) }
        else { model.feedbackPhase = now >= deadline - 0.75 ? .exiting : .resting }
    }

    func hide() {
        discardFeedback()
        invalidateDismissal()
        panel.orderOut(nil)
        panel.contentView = nil
        screenSelection.endSession()
        model.recording = RecordingMeter()
    }

    func configureFeedback(preferences: ProductPreferences) {
        correctionPreferences = preferences
        contextualStore = nil
    }

    func configureFeedback(preferences: ProductPreferences, store: ContextualCorrectionStore) {
        correctionPreferences = preferences
        contextualStore = store
    }

    func offerFeedback(_ context: DictationCompletion) {
        hide()
        let token = context.id
        let targetPID = context.targetApplication?.processIdentifier
        offeredFeedback = FeedbackOffer(
            token: token,
            targetPID: targetPID,
            text: context.text,
            language: context.language,
            retentionProbe: context.retentionProbe
        )
        model.feedbackPhase = .entering
        present(.feedback, target: .session(targetPID))
        makeFeedbackTargets(token: token)
        scheduleDismissal(after: FeedbackBubbleMotion.duration, feedbackToken: token)
        onFeedbackChange?()
        announce("Transcrição correta. Corrigir transcrição.")
    }

    func approveFeedback(token: UUID) {
        guard approvalActionToken == token else { return }
        hide()
    }

    func openCorrection(token: UUID) {
        guard correctionActionToken == token, correctionPreferences != nil else { return }
        if let offer = offeredFeedback ?? recoveryOffer {
            feedback = CorrectionSession(
                token: offer.token,
                targetPID: offer.targetPID,
                text: offer.text,
                language: offer.language,
                retentionProbe: offer.retentionProbe
            )
            offeredFeedback = nil
            recoveryOffer = nil
        }
        guard let session = feedback, session.actionID == token,
              let preferences = correctionPreferences else { return }
        invalidateDismissal()
        removeFeedbackTargets()
        if session.isEditing {
            NSApplication.shared.activate(ignoringOtherApps: true)
            correctionWindow?.makeKeyAndOrderFront(nil)
            return
        }
        if contextualStore == nil && (session.token == nil || !preferences.canSaveTranscriptionCorrection) {
            if preferences.reloadTranscriptionGlossaryForCorrection() {
                session.token = UUID()
                session.errorMessage = nil
            } else {
                session.token = nil
                session.errorMessage = ProductPreferences.CorrectionSaveResult.storageFailure(recoveryRequired: true).message
            }
        }
        session.isEditing = true
        panel.orderOut(nil)
        panel.contentView = nil
        panel.ignoresMouseEvents = true
        let actionID = session.actionID
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Corrigir transcrição"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: CorrectionEditor(
            session: session,
            onSave: { [weak self] in self?.saveCorrection(token: actionID) },
            onCancel: { [weak self] in self?.cancelFeedback(token: actionID) },
            onInvalidInput: { [weak self] in
                guard self?.correctionActionToken == actionID else { return }
                self?.announce(TranscriptionGlossary.CorrectionValidationError.lineLimit.message)
            },
            requiresOccurrenceSelection: contextualStore != nil
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
        session.update(heard: heard, canonical: canonical)
    }

    func selectCorrectionOccurrence(token: UUID, ordinal: Int) {
        guard let session = feedback, session.actionID == token, session.isEditing else { return }
        session.select(ordinal: ordinal)
    }

    func saveCorrection(token: UUID) {
        guard let session = feedback, session.token == token, canSaveCorrection,
              let preferences = correctionPreferences else { return }
        if let contextualStore {
            guard let selectedContext = session.selectedContext else { return }
            let result = contextualStore.save(.init(
                id: UUID(),
                language: session.language.rawValue,
                heard: session.heard,
                canonical: session.canonical,
                sentence: selectedContext.sentence,
                occurrenceOrdinal: selectedContext.occurrenceOrdinal
            ))
            handleContextualSave(result, session: session)
            return
        }
        let result = preferences.saveTranscriptionCorrection(heard: session.heard, canonical: session.canonical)
        switch result {
        case .saved, .alreadyExists:
            announce(result.message)
            let targetPID = session.targetPID
            hide()
            let restored = restoreTarget(pid: targetPID)
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

    private func handleContextualSave(
        _ result: ContextualCorrectionSaveResult,
        session: CorrectionSession
    ) {
        let message = result.feedbackMessage
        switch result {
        case .saved, .alreadyExists:
            let targetPID = session.targetPID
            announce(message)
            hide()
            let restored = restoreTarget(pid: targetPID)
            showTemporarily(.feedbackNotice(
                restored ? message : "\(message). Volte ao campo de texto para ditar"
            ))
        case .conflict, .limitReached, .invalid, .storageFailure:
            session.errorMessage = message
            announce(message)
        }
    }

    func cancelCorrectionForHotkey(token: UUID) {
        guard correctionActionToken == token, isEditingCorrection else { return }
        let restored = cancelFeedback(token: token)
        let guidance = FloatingStatus.feedbackNotice(restored
            ? "Solte e pressione novamente para ditar"
            : "Volte ao campo de texto. Solte e pressione novamente para ditar")
        if hasFeedback {
            // Only the recovery action remains; closing has already erased both fields.
            present(guidance, target: .standalone(nil))
        } else {
            showTemporarily(guidance)
        }
    }

    @discardableResult
    func cancelFeedback(token: UUID, restoreFocus: Bool = true) -> Bool {
        if let offer = offeredFeedback, offer.token == token {
            let targetPID = offer.targetPID
            hide()
            return !restoreFocus || restoreTarget(pid: targetPID)
        }
        guard let session = feedback, session.actionID == token else { return false }
        let targetPID = session.targetPID
        if contextualStore == nil && session.isEditing
            && correctionPreferences?.canSaveTranscriptionCorrection == false {
            hide()
            recoveryOffer = FeedbackOffer(
                token: UUID(),
                targetPID: targetPID,
                text: "",
                language: .portuguese,
                retentionProbe: nil
            )
            onFeedbackChange?()
        } else {
            hide()
        }
        if restoreFocus && !restoreTarget(pid: targetPID) {
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
        window?.contentView = nil
        window?.close()
    }

    private func discardFeedback() {
        removeFeedbackTargets()
        guard hasFeedback else { return }
        offeredFeedback = nil
        recoveryOffer = nil
        feedback?.clear()
        feedback = nil
        closeCorrectionWindow()
        panel.ignoresMouseEvents = true
        onFeedbackChange?()
    }

    private func restoreTarget(pid: pid_t?) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier else { return true }
        guard let pid, let application = NSRunningApplication(processIdentifier: pid), !application.isTerminated,
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
        if let token = dismissal.feedbackToken {
            guard offeredFeedback?.token == token, !isEditingCorrection, model.status == .feedback else { return }
        }
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
        panel.contentView = NSHostingView(rootView: FloatingStatusView(model: model, feedbackIsVisualOnly: true))
        return panel
    }

    private func makeFeedbackTargets(token: UUID) {
        for index in 0..<2 {
            let overlay = FeedbackTargetPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                              backing: .buffered, defer: false)
            // A fully clear window is skipped by WindowServer mouse routing.
            overlay.backgroundColor = NSColor.black.withAlphaComponent(0.01)
            overlay.isOpaque = false
            overlay.hasShadow = false
            overlay.level = panel.level
            overlay.hidesOnDeactivate = false
            overlay.isReleasedWhenClosed = false
            let button = FeedbackTargetButton(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
            button.isTransparent = true
            button.setAccessibilityElement(true)
            button.setAccessibilityLabel(index == 0 ? FloatingStatusView.approveLabel : FloatingStatusView.correctLabel)
            button.setAccessibilityHelp(index == 0 ? "Encerra a avaliação sem salvar dados."
                : "Abre os campos Saiu como e Correto é para uma correção local.")
            button.target = button
            button.action = #selector(FeedbackTargetButton.activateFeedback)
            button.handler = { [weak self] in
                if index == 0 { self?.approveFeedback(token: token) }
                else { self?.openCorrection(token: token) }
            }
            overlay.contentView = button
            feedbackTargets.append(overlay)
            // Keep independent screen-space windows: attaching the transparent HUD's
            // children before their first order can leave WindowServer bounds parent-relative.
            overlay.collectionBehavior = panel.collectionBehavior
        }
        positionFeedbackTargets()
        feedbackTargets.forEach { $0.orderFrontRegardless() }
    }

    private func removeFeedbackTargets() {
        model.feedbackPhase = .hidden
        for overlay in feedbackTargets {
            (overlay.contentView as? FeedbackTargetButton)?.handler = nil
            overlay.orderOut(nil)
            overlay.contentView = nil
            overlay.close()
        }
        feedbackTargets.removeAll()
    }

    private func positionFeedbackTargets() {
        let size = FeedbackBubbleMotion.targetSize
        let width = size * 2 + 16
        for (index, overlay) in feedbackTargets.enumerated() {
            overlay.setFrame(NSRect(x: panel.frame.midX - width / 2 + CGFloat(index) * (size + 16),
                                    y: panel.frame.midY - size / 2, width: size, height: size), display: true)
        }
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
        positionFeedbackTargets()
    }
}
