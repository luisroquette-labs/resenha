#if RESENHA_APP_STORE
import Carbon
import OSLog

enum ResenhaServiceShortcut {
    /// AppKit adds Command automatically; uppercase also adds Shift.
    static let keyEquivalent = "E"
    static let displayName = "Command + Shift + E"
}

/// The registered Services shortcut delivers only its own press/release events.
/// It does not observe arbitrary keyboard input or request Input Monitoring.
final class HotkeyMonitor {
    private let logger = Logger(subsystem: "br.com.luisroquette.Resenha", category: "hotkey")
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onInterruption: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var shortcutPressed = false
    private var serviceReleaseArmed = false
    var isRunning: Bool { hotkeyRef != nil }

    func configure(shortcut: HotkeyShortcut) {}

    func start() throws {
        guard hotkeyRef == nil else { return }
        var types = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handler: EventHandlerUPP = { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(context).takeUnretainedValue()
            if GetEventKind(event) == UInt32(kEventHotKeyPressed) {
                monitor.shortcutPressed = true
            } else if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                monitor.receiveRelease()
            }
            return noErr
        }
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(), handler, types.count, &types, context, &handlerRef
        )
        guard installStatus == noErr else { throw StoreHotkeyError.registrationFailed(installStatus) }

        let identifier = EventHotKeyID(signature: OSType(0x52534E48), id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_E), UInt32(cmdKey | shiftKey), identifier,
            GetApplicationEventTarget(), 0, &hotkeyRef
        )
        guard registerStatus == noErr else {
            if let handlerRef { RemoveEventHandler(handlerRef) }
            handlerRef = nil
            throw StoreHotkeyError.registrationFailed(registerStatus)
        }
        logger.notice("Services shortcut registered")
    }

    func stop() {
        shortcutPressed = false
        serviceReleaseArmed = false
        if let hotkeyRef { UnregisterEventHotKey(hotkeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotkeyRef = nil
        handlerRef = nil
    }

    func armServiceRelease(pressedKeyCodes: [Int64]? = nil) -> Bool {
        guard isRunning, !serviceReleaseArmed else { return false }
        let deadline = Date().addingTimeInterval(0.15)
        while !shortcutPressed, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
        }
        guard shortcutPressed else { return false }
        serviceReleaseArmed = true
        return true
    }

    func disarmServiceRelease() { serviceReleaseArmed = false }

    @discardableResult
    func interruptActiveShortcut() -> Bool {
        let wasArmed = serviceReleaseArmed
        serviceReleaseArmed = false
        return wasArmed
    }

    private func receiveRelease() {
        shortcutPressed = false
        guard serviceReleaseArmed else { return }
        serviceReleaseArmed = false
        DispatchQueue.main.async { [weak self] in self?.onRelease?() }
    }
}

enum StoreHotkeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        "Não foi possível registrar Command + Shift + E. Verifique se outro app usa esse atalho."
    }
}
#endif
