import ApplicationServices
import OSLog

enum HotkeyError: LocalizedError {
    case eventTapUnavailable

    var errorDescription: String? {
        "Atalho global indisponível. Conceda acesso ao Monitoramento de Entrada."
    }
}

enum ResenhaServiceShortcut {
    /// AppKit adds Command automatically; uppercase also adds Shift.
    static let keyEquivalent = "E"
    static let displayName = "Command + Shift + E"
}

struct ServiceReleaseLatch {
    static let recentKeyWindow: TimeInterval = 1

    private(set) var keyCode: Int64?
    private(set) var mostRecentKeyDown: (keyCode: Int64, uptime: TimeInterval)?

    mutating func noteKeyDown(
        _ keyCode: Int64,
        at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) {
        mostRecentKeyDown = (keyCode, uptime)
    }

    mutating func noteKeyUp(_ keyCode: Int64) {
        if mostRecentKeyDown?.keyCode == keyCode { mostRecentKeyDown = nil }
    }

    mutating func expireRecentKey(at uptime: TimeInterval) {
        guard let mostRecentKeyDown,
              uptime >= mostRecentKeyDown.uptime,
              uptime - mostRecentKeyDown.uptime >= Self.recentKeyWindow else { return }
        self.mostRecentKeyDown = nil
    }

    mutating func arm(
        pressedKeyCodes: [Int64],
        at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Bool {
        guard keyCode == nil else { return false }
        let pressed = Set(pressedKeyCodes)
        let pressedKey: Int64?
        if let mostRecentKeyDown,
           uptime >= mostRecentKeyDown.uptime,
           uptime - mostRecentKeyDown.uptime <= Self.recentKeyWindow,
           pressed.contains(mostRecentKeyDown.keyCode) {
            pressedKey = mostRecentKeyDown.keyCode
        } else if pressed.count == 1 {
            pressedKey = pressed.first
        } else {
            pressedKey = nil
        }
        guard let pressedKey else { return false }
        keyCode = pressedKey
        return true
    }

    mutating func consume(eventType: CGEventType, keyCode: Int64) -> Bool {
        guard eventType == .keyUp, self.keyCode == keyCode else { return false }
        self.keyCode = nil
        return true
    }

    mutating func interrupt() -> Bool {
        guard keyCode != nil else { return false }
        keyCode = nil
        return true
    }

    mutating func reset() {
        keyCode = nil
        mostRecentKeyDown = nil
    }
}

final class HotkeyMonitor {
    private let logger = Logger(subsystem: "br.com.luisroquette.Resenha", category: "hotkey")
    var onRelease: (() -> Void)?
    var onInterruption: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var releaseLatch = ServiceReleaseLatch()
    private var recentKeyExpiry: DispatchWorkItem?
    var isRunning: Bool { eventTap != nil }

    /// Snapshots only non-modifier keys that are physically down after AppKit
    /// has opened a real Service request. This supports a user-assigned Service
    /// shortcut without retaining unrelated key events.
    func armServiceRelease(pressedKeyCodes: [Int64]? = nil) -> Bool {
        let keys = pressedKeyCodes ?? Self.nonModifierKeyCodes.filter {
            CGEventSource.keyState(.combinedSessionState, key: CGKeyCode($0))
        }
        return releaseLatch.arm(pressedKeyCodes: keys)
    }

    func disarmServiceRelease() {
        clearTransientKeyState()
    }

    @discardableResult
    func interruptServiceRelease() -> Bool {
        let wasArmed = releaseLatch.interrupt()
        clearTransientKeyState()
        return wasArmed
    }

    func start() throws {
        guard eventTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
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
        clearTransientKeyState()
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            process(eventType: type, keyCode: 0)
            return
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        process(eventType: type, keyCode: keyCode)
    }

    func process(eventType: CGEventType, keyCode: Int64) {
        if eventType == .tapDisabledByTimeout || eventType == .tapDisabledByUserInput {
            if interruptServiceRelease() { deliverInterruption() }
            return
        }
        if eventType == .keyDown {
            guard !Self.modifierKeyCodes.contains(keyCode) else { return }
            let observedAt = ProcessInfo.processInfo.systemUptime
            releaseLatch.noteKeyDown(keyCode, at: observedAt)
            recentKeyExpiry?.cancel()
            let expiry = DispatchWorkItem { [weak self] in
                self?.releaseLatch.expireRecentKey(at: ProcessInfo.processInfo.systemUptime)
            }
            recentKeyExpiry = expiry
            DispatchQueue.main.asyncAfter(deadline: .now() + ServiceReleaseLatch.recentKeyWindow, execute: expiry)
            return
        }
        guard eventType == .keyUp else { return }
        let shouldRelease = releaseLatch.consume(eventType: eventType, keyCode: keyCode)
        if releaseLatch.mostRecentKeyDown?.keyCode == keyCode {
            recentKeyExpiry?.cancel()
            recentKeyExpiry = nil
        }
        releaseLatch.noteKeyUp(keyCode)
        if shouldRelease { deliverRelease() }
    }

    private func clearTransientKeyState() {
        recentKeyExpiry?.cancel()
        recentKeyExpiry = nil
        releaseLatch.reset()
    }

    private func deliverRelease() {
        logger.notice("Service shortcut released")
        DispatchQueue.main.async { [weak self] in self?.onRelease?() }
    }

    private func deliverInterruption() {
        logger.error("Service shortcut monitoring was interrupted")
        DispatchQueue.main.async { [weak self] in self?.onInterruption?() }
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.receive(type: type, event: event)
        return Unmanaged.passUnretained(event)
    }

    private static let modifierKeyCodes: Set<Int64> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
    private static let nonModifierKeyCodes = (0...127).map(Int64.init).filter { !modifierKeyCodes.contains($0) }
}
