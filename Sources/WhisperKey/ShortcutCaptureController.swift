import AppKit
import ApplicationServices

@MainActor
final class ShortcutCaptureController: ObservableObject {
    @Published private(set) var isRecording = false
    private var monitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var pendingModifier: (keyCode: Int64, flags: CGEventFlags, label: String)?
    private var completion: ((HotkeyShortcut) -> Void)?

    func begin(completion: @escaping (HotkeyShortcut) -> Void) {
        cancel()
        self.completion = completion
        isRecording = true
        NSApplication.shared.activate(ignoringOtherApps: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.cancel() }
        }
    }

    func cancel() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        monitor = nil
        activationObserver = nil
        pendingModifier = nil
        completion = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard isRecording else { return false }
        if event.type == .keyDown {
            if event.keyCode == 53 { cancel(); return true }
            let label = Self.keyLabel(for: event)
            finish(HotkeyShortcut(
                keyCode: Int64(event.keyCode),
                flags: Self.flags(from: event.modifierFlags),
                keyLabel: label
            ))
            return true
        }

        let keyCode = Int64(event.keyCode)
        guard let flag = Self.modifierFlag(for: keyCode) else { return true }
        let currentFlags = Self.flags(from: event.modifierFlags)
        if currentFlags.contains(flag) {
            pendingModifier = (keyCode, flag, Self.modifierLabel(for: keyCode))
        } else if currentFlags.isEmpty, let pendingModifier, pendingModifier.keyCode == keyCode {
            finish(HotkeyShortcut(
                keyCode: pendingModifier.keyCode,
                flags: pendingModifier.flags,
                keyLabel: pendingModifier.label,
                isModifierOnly: true
            ))
        }
        return true
    }

    private func finish(_ shortcut: HotkeyShortcut) {
        let completion = completion
        cancel()
        completion?(shortcut)
    }

    static func flags(from flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result: CGEventFlags = []
        if flags.contains(.control) { result.insert(.maskControl) }
        if flags.contains(.option) { result.insert(.maskAlternate) }
        if flags.contains(.shift) { result.insert(.maskShift) }
        if flags.contains(.command) { result.insert(.maskCommand) }
        if flags.contains(.function) { result.insert(.maskSecondaryFn) }
        return result
    }

    private static func modifierFlag(for keyCode: Int64) -> CGEventFlags? {
        switch keyCode {
        case 54, 55: .maskCommand
        case 56, 60: .maskShift
        case 58, 61: .maskAlternate
        case 59, 62: .maskControl
        case 63: .maskSecondaryFn
        default: nil
        }
    }

    private static func modifierLabel(for keyCode: Int64) -> String {
        switch keyCode {
        case 54: "Command direita"
        case 55: "Command esquerda"
        case 56: "Shift esquerda"
        case 60: "Shift direita"
        case 58: "Option esquerda"
        case 61: "Option direita"
        case 59: "Control esquerda"
        case 62: "Control direita"
        case 63: "Fn"
        default: "Tecla \(keyCode)"
        }
    }

    private static func keyLabel(for event: NSEvent) -> String {
        let names: [UInt16: String] = [
            36: "Return", 48: "Tab", 49: "Espaço", 51: "Delete", 53: "Esc",
            64: "F17", 79: "F18", 80: "F19", 90: "F20", 96: "F5", 97: "F6",
            98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13",
            106: "F16", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 118: "F4",
            120: "F2", 122: "F1",
            115: "Home", 116: "Page Up", 117: "Forward Delete", 119: "End", 121: "Page Down",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        if let name = names[event.keyCode] { return name }
        let value = event.charactersIgnoringModifiers?.uppercased() ?? ""
        return value.isEmpty ? "Tecla \(event.keyCode)" : value
    }
}
