#if RESENHA_APP_STORE
enum ResenhaServiceShortcut {
    /// AppKit adds Command automatically; uppercase also adds Shift.
    static let keyEquivalent = "E"
    static let displayName = "Command + Shift + E"
}

/// AppKit owns the Services shortcut; the Store build never registers a global hotkey.
final class HotkeyMonitor {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onInterruption: (() -> Void)?
    private(set) var isRunning = false

    func configure(shortcut: HotkeyShortcut) {}
    func start() throws { isRunning = true }
    func stop() { isRunning = false }
    @discardableResult func interruptActiveShortcut() -> Bool { false }
}
#endif
