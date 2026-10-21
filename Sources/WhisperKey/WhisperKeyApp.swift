import AppKit
import OSLog
import SwiftUI

@main
struct WhisperKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { appDelegate.productSettingsView }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Logger(subsystem: "br.com.luisroquette.Resenha", category: "lifecycle")
    private let permissions = PermissionService()
    let panel = FloatingPanelController()
    private let hotkey = HotkeyMonitor()
    private let cuePlayer = DictationCuePlayer()
    private var coordinator: DictationCoordinator!
    private var permissionTimer: Timer?
    private var lastPermissionSnapshot: PermissionSnapshot?
    private(set) var interaction = DictationInteraction()
    private var hotkeyFailureFeedback = HotkeyFailureFeedback()
    private var didPlayLaunchReadyCue = false
    let preferences = ProductPreferences()
    private let contextualTime = ContinuousContextualTime()
    private let contextualPolicy = ContextualCorrectionPolicy()
    private let contextualStore = ContextualCorrectionStore()
    private let contextualCredentialStore = KeychainContextualCredentialStore()
    private lazy var contextualTimeComposition: ContextualTimeComposition = {
        do {
            return try ContextualTimeComposition(
                resolver: contextualTime,
                diagnostic: contextualTime,
                transport: contextualTime
            )
        } catch {
            preconditionFailure("Contextual clocks must share one origin")
        }
    }()
    private lazy var contextualTransport = URLSessionDecisionsStreamingTransport(
        time: contextualTimeComposition.shared
    )
    private lazy var contextualClient = OpenRouterDecisionsClient(
        transport: contextualTransport,
        credential: { [contextualCredentialStore] in
            guard let value = try contextualCredentialStore.load() else {
                throw OpenRouterDecisionsError.missingCredential
            }
            return value
        }
    )
    private lazy var contextualAuthorization = SyntheticDiagnosticAuthorizationOwner(
        optInStore: preferences,
        credentialStore: contextualCredentialStore,
        guardStore: SyntheticDiagnosticGuard(),
        policy: contextualPolicy
    )
    private lazy var contextualResolver = ContextualCorrectionResolver(
        store: contextualStore,
        policy: contextualPolicy,
        provider: contextualClient,
        storeGeneration: { [contextualStore] in contextualStore.generation },
        time: contextualTimeComposition.shared
    )
    private lazy var contextualDiagnosticController = SyntheticDiagnosticController(
        policy: contextualPolicy,
        authorization: contextualAuthorization,
        client: contextualClient,
        validator: ContextualDecisionValidator(),
        fixture: try! SyntheticDiagnosticFixture.load(),
        time: contextualTimeComposition.shared
    )
    private lazy var transcriptHistory = TranscriptHistory()
    private lazy var menuController = NativeMenuController(delegate: self)
    private lazy var onboardingController = PermissionOnboardingController(
        requestPermissions: { [weak self] in self?.enablePermissions() },
        openSettings: { [weak self] permission in self?.openSettings(for: permission) }
    )
    private lazy var settingsController = ProductSettingsWindowController(
        preferences: preferences,
        contextualStore: contextualStore,
        authorization: contextualAuthorization,
        diagnostic: contextualDiagnosticController
    )

    var productSettingsView: ProductSettingsView {
        ProductSettingsView(
            preferences: preferences,
            contextualStore: contextualStore,
            authorization: contextualAuthorization,
            diagnostic: contextualDiagnosticController
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AudioRecorder.cleanupStaleRecordings()
        contextualStore.onMutation = { [weak contextualPolicy] in
            contextualPolicy?.invalidate(.storeMutated)
        }
        _ = contextualDiagnosticController
        transcriptHistory.onChange = { [weak self] items, storageAvailable in
            self?.menuController.updateRecentTranscripts(items, storageAvailable: storageAvailable)
        }
        preferences.onHistoryChange = { [weak self] enabled in self?.historyPreferenceChanged(enabled) }
        preferences.onLanguageChange = { [weak self] language in self?.menuController.updateLanguage(language) }
        hotkey.configure(shortcut: preferences.shortcut)
        preferences.onShortcutChange = { [weak self] shortcut in
            guard let self else { return }
            self.hotkey.stop()
            self.hotkey.configure(shortcut: shortcut)
            self.startHotkeyIfReady(showResult: true)
        }
        observeCoordinator(DictationCoordinator(
            permissions: permissions,
            panel: panel,
            showsHUD: { [weak preferences] in preferences?.showsHUD ?? true },
            soundsEnabled: { [weak preferences] in preferences?.soundsEnabled ?? true },
            language: { [weak preferences] in preferences?.transcriptionLanguage ?? .portuguese },
            glossaryText: { [weak preferences] in preferences?.transcriptionGlossary ?? TranscriptionGlossary.defaultText },
            onRecordingLevel: { [weak self] level in self?.menuController.updateRecordingLevel(level) },
            onTranscript: { [weak self] text in
                self?.recordTranscript(text)
            },
            onFailure: { _ in },
            outputSink: TextInjector(),
            contextualResolver: contextualResolver,
            contextualTokenSource: DictationCoordinator.productionContextualTokenSource(
                policy: contextualPolicy,
                isEnabled: { [preferences] in preferences.contextualCorrectionsEnabled }
            ),
            contextualStoreGeneration: { [weak contextualStore] in contextualStore?.generation ?? 0 }
        ))
        configureHotkeyRouting()
        configureMenuBar()
        menuController.updateLanguage(preferences.transcriptionLanguage)
        menuController.updateRecentTranscripts(
            preferences.keepsHistory ? transcriptHistory.items : [],
            storageAvailable: transcriptHistory.storageAvailable
        )
        startHotkeyIfReady()
        presentOnboardingIfNeeded()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissionState() }
        }
    }

    func observeCoordinator(_ coordinator: DictationCoordinator) {
        self.coordinator = coordinator
        coordinator.onPhaseChange = { [weak self] _ in self?.updateStatusItem() }
        coordinator.onCompleted = { [weak self] context in
            guard let self, self.preferences.showsHUD else { return }
            self.panel.offerFeedback(context)
        }
        panel.configureFeedback(preferences: preferences, store: contextualStore)
        panel.onFeedbackChange = { [weak self] in self?.updateFeedbackMenu() }
        preferences.onHUDChange = { [weak self] visible in if !visible { self?.panel.hide() } }
    }

    func configureHotkeyRouting() {
        hotkey.onPress = { [weak self] in self?.handleHotkeyPress() }
        hotkey.onRelease = { [weak self] in self?.handleHotkeyRelease() }
    }

    var isHotkeyRoutingConfigured: Bool {
        hotkey.onPress != nil && hotkey.onRelease != nil
    }

    func handleHotkeyPress(targetIsSelf: Bool? = nil) {
        guard acceptHotkeyPress(targetIsSelf: targetIsSelf) else { return }
        coordinator.hotkeyPressed()
    }

    func acceptHotkeyPress(targetIsSelf: Bool? = nil) -> Bool {
        guard let coordinator else { return false }
        let isSelf = targetIsSelf ?? (NSWorkspace.shared.frontmostApplication?.processIdentifier
            == ProcessInfo.processInfo.processIdentifier)
        let wasPressed = interaction.isPressed
        let accepted = interaction.press(phase: coordinator.phase, targetIsSelf: isSelf)
        if !wasPressed, isSelf, panel.isEditingCorrection, let token = panel.correctionActionToken {
            panel.cancelCorrectionForHotkey(token: token)
            return false
        }
        guard accepted else { return false }
        panel.hide()
        return true
    }

    func handleHotkeyRelease() {
        interaction.release()
        coordinator?.hotkeyReleased()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        startHotkeyIfReady()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        settingsController.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        contextualPolicy.invalidate(.appTerminated)
        permissionTimer?.invalidate()
        hotkey.stop()
        panel.hide()
        coordinator?.cancel()
    }

    @objc func enablePermissions() {
        guard !interaction.isRequestingPermission else { return }
        interaction.isRequestingPermission = true
        updateStatusItem()
        permissions.requestInputMonitoring()
        permissions.requestAccessibility()
        Task {
            defer {
                interaction.isRequestingPermission = false
                updateStatusItem()
            }
            await permissions.requestMicrophone()
            startHotkeyIfReady()
            if let missing = permissions.snapshot.missingPermissions.first {
                openSettings(for: missing)
            }
        }
    }

    @objc func checkPermissions() {
        startHotkeyIfReady(showResult: true)
    }

    @objc func openPermissionSettings(_ sender: NSMenuItem) {
        guard let permission = sender.representedObject as? RequiredPermission else { return }
        openSettings(for: permission)
    }

    @objc func showPermissionSetup() {
        onboardingController.show(snapshot: permissions.snapshot, isRequesting: interaction.isRequestingPermission)
    }

    @objc func showSettings() {
        settingsController.show()
    }

    @objc func approveTranscription(_ sender: NSMenuItem) {
        guard let token = sender.representedObject as? UUID else { return }
        panel.approveFeedback(token: token)
    }

    @objc func correctTranscription(_ sender: NSMenuItem) {
        guard let token = sender.representedObject as? UUID else { return }
        panel.openCorrection(token: token)
    }

    @objc func copyRecentTranscript(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc func selectTranscriptionLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = TranscriptionLanguage(rawValue: rawValue) else { return }
        preferences.transcriptionLanguage = language
    }

    @objc func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Limpar os textos recentes?"
        alert.informativeText = "Os 10 textos locais serão apagados deste Mac. Esta ação não pode ser desfeita."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Limpar")
        alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        transcriptHistory.clear()
    }

    @objc func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Resenha",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        ])
    }

    func settingsNavigationFinished(_ opened: Bool, for permission: RequiredPermission) {
        menuController.settingsNavigationFinished(opened, for: permission)
        updateStatusItem()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func startHotkeyIfReady(showResult: Bool = false) {
        guard coordinator != nil else { return }
        let snapshot = permissions.snapshot
        guard applyPermissionSnapshot(snapshot, showResult: showResult) else { return }

        coordinator.permissionsRestored()
        updateStatusItem(snapshot)
        do {
            let wasRunning = hotkey.isRunning
            try hotkey.start()
            hotkeyFailureFeedback.lastAttemptFailed = false
            updateStatusItem(snapshot)
            if !wasRunning { logger.notice("Hotkey monitoring active") }
            if !didPlayLaunchReadyCue, preferences.soundsEnabled {
                didPlayLaunchReadyCue = true
                cuePlayer.play(.ready, readySound: preferences.readySound)
            }
            if showResult || !wasRunning { showRoutineStatus(.ready) }
        } catch {
            if hotkeyFailureFeedback.recordFailure(phase: coordinator.phase, explicitCheck: showResult) {
                showRoutineStatus(.failure("Atalho global indisponível"))
            }
            updateStatusItem(snapshot)
        }
    }

    func applyPermissionSnapshot(_ snapshot: PermissionSnapshot, showResult: Bool = false) -> Bool {
        guard let coordinator else { return false }
        lastPermissionSnapshot = snapshot
        updateStatusItem(snapshot)
        guard !snapshot.isReady else { return true }
        hotkeyFailureFeedback.lastAttemptFailed = false
        hotkey.stop()
        interaction.release()
        if panel.hasFeedback { panel.hide() }
        coordinator.permissionLost(snapshot)
        if showResult { showRoutineStatus(.failure(snapshot.missingPermissionMessage)) }
        return false
    }

    private func refreshPermissionState() {
        let snapshot = permissions.snapshot
        if snapshot != lastPermissionSnapshot || (snapshot.isReady && !hotkey.isRunning) {
            startHotkeyIfReady()
        }
    }

    func showRoutineStatus(_ status: FloatingStatus) {
        guard coordinator?.phase.acceptsStatusFeedback == true, !panel.hasFeedback, preferences.showsHUD else { return }
        panel.showTemporarily(status)
    }

    private func updateStatusItem(_ snapshot: PermissionSnapshot? = nil) {
        guard let coordinator else { return }
        let currentSnapshot = snapshot ?? permissions.snapshot
        let presentation = MenuStatusPresentation(phase: coordinator.phase, snapshot: currentSnapshot,
            error: coordinator.currentError, hotkeyUnavailable: hotkeyFailureFeedback.lastAttemptFailed,
            shortcut: preferences.shortcut)
        menuController.update(presentation, isRequestingPermission: interaction.isRequestingPermission)
        updateFeedbackMenu()
        onboardingController.update(snapshot: currentSnapshot, isRequesting: interaction.isRequestingPermission)
    }

    func menuWillOpen(_ menu: NSMenu) {
        interaction.openMenuCount += 1
        updateStatusItem()
    }
    func menuDidClose(_ menu: NSMenu) { interaction.openMenuCount = max(0, interaction.openMenuCount - 1) }

    private func configureMenuBar() {
        menuController.configure()
        updateFeedbackMenu()
    }

    private func updateFeedbackMenu() {
        menuController.updateFeedback(approvalToken: panel.approvalActionToken, correctionToken: panel.correctionActionToken)
    }

    private func recordTranscript(_ text: String) {
        guard preferences.keepsHistory else { return }
        transcriptHistory.add(text)
    }

    private func historyPreferenceChanged(_ enabled: Bool) {
        guard !enabled else {
            menuController.updateRecentTranscripts(
                transcriptHistory.items,
                storageAvailable: transcriptHistory.storageAvailable
            )
            return
        }
        let alert = NSAlert()
        alert.messageText = "Desativar textos recentes?"
        alert.informativeText = "O histórico local existente será apagado. As novas transcrições ainda ficarão no clipboard."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Desativar e limpar")
        alert.addButton(withTitle: "Cancelar")
        if alert.runModal() == .alertFirstButtonReturn {
            transcriptHistory.clear()
        } else {
            preferences.keepsHistory = true
        }
    }

    private func presentOnboardingIfNeeded() {
        let defaults = UserDefaults.standard
        let snapshot = permissions.snapshot
        let modelReady: Bool
        if case .ready = WhisperModelManager.shared.state { modelReady = true } else { modelReady = false }
        guard PermissionOnboardingPolicy.shouldPresent(
            snapshot: snapshot,
            hasPresented: defaults.bool(forKey: PermissionOnboardingPolicy.presentedKey),
            modelReady: modelReady
        ) else { return }
        defaults.set(true, forKey: PermissionOnboardingPolicy.presentedKey)
        onboardingController.show(snapshot: snapshot, isRequesting: interaction.isRequestingPermission)
    }

    private func openSettings(for permission: RequiredPermission) {
        settingsNavigationFinished(permissions.openSettings(for: permission), for: permission)
    }

    func makePermissionsMenu(_ snapshot: PermissionSnapshot) -> NSMenu {
        menuController.makePermissionsMenu(snapshot)
    }

    func makeDetailsMenu(_ error: DictationErrorPresentation) -> NSMenu {
        menuController.makeDetailsMenu(error)
    }
}
