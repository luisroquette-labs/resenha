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
final class FloatingPanelController: NSObject {
    private let model = FloatingPanelModel()
    private lazy var panel: NSPanel = makePanel()
    private var dismissalTask: Task<Void, Never>?
    private var onDismiss: (@MainActor () -> Void)?
    private(set) var dismissal = PanelDismissal()
    private(set) var target: PanelTarget = .standalone(nil)
    private var screenSelection = PanelScreenSelection()
    private let clock: () -> TimeInterval
    private(set) var selectedScreenID: UInt32?
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
        invalidateDismissal()
        self.target = target
        model.show(status, now: clock())
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
        invalidateDismissal()
        panel.orderOut(nil)
        screenSelection.endSession()
        model.recording = RecordingMeter()
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
