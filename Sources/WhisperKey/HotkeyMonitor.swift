import ApplicationServices
import OSLog

enum HotkeyError: LocalizedError {
    case eventTapUnavailable

    var errorDescription: String? {
        "Atalho global indisponível. Conceda acesso ao Monitoramento de Entrada."
    }
}

enum HotkeyEdge: Equatable { case pressed, released }

struct HotkeyLatch {
    private(set) var isPressed = false

    mutating func update(_ pressed: Bool) -> HotkeyEdge? {
        guard pressed != isPressed else { return nil }
        isPressed = pressed
        return pressed ? .pressed : .released
    }

    mutating func interrupt() -> HotkeyEdge? {
        guard isPressed else { return nil }
        isPressed = false
        return .released
    }
}

final class HotkeyMonitor {
    private let logger = Logger(subsystem: "br.com.luisroquette.WhisperKey", category: "hotkey")
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var latch = HotkeyLatch()
    private var serviceReleaseArmed = false
    private(set) var shortcut: HotkeyShortcut = .rightOption
    var isRunning: Bool { eventTap != nil }

    func configure(shortcut: HotkeyShortcut) { self.shortcut = shortcut }

    func armServiceRelease() {
        serviceReleaseArmed = true
    }

    func start() throws {
        guard eventTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: Self.callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw HotkeyError.eventTapUnavailable
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        eventTap = nil
        runLoopSource = nil
        serviceReleaseArmed = false
        _ = latch.interrupt()
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            if let edge = latch.interrupt() { deliver(edge) }
            return
        }
        if serviceReleaseArmed, type == .keyUp {
            serviceReleaseArmed = false
            deliver(.released)
            return
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let physicalModifierState = shortcut.isModifierOnly
            ? CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(shortcut.keyCode)) : nil
        guard let pressed = shortcut.isPressed(
            eventType: type,
            keyCode: keyCode,
            flags: event.flags,
            modifierKeyDown: physicalModifierState
        ), let edge = latch.update(pressed) else { return }
        deliver(edge)
    }

    private func deliver(_ edge: HotkeyEdge) {
        logger.notice("Dictation hotkey \(edge == .pressed ? "pressed" : "released", privacy: .public)")
        DispatchQueue.main.async { [weak self] in
            if edge == .pressed { self?.onPress?() } else { self?.onRelease?() }
        }
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.receive(type: type, event: event)
        return Unmanaged.passUnretained(event)
    }
}
