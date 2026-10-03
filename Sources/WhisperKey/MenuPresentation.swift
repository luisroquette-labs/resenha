import AppKit

struct MenuStatusPresentation {
    let phase: DictationPhase
    let snapshot: PermissionSnapshot
    let error: DictationErrorPresentation?
    var hotkeyUnavailable = false
    var shortcut: HotkeyShortcut = .rightOption

    var activity: String {
        switch phase {
        case .idle: !snapshot.isReady ? "Permissões necessárias" : hotkeyUnavailable ? "Atalho global indisponível" : "Pronto"
        case .recording: "Ouvindo"
        case .transcribing: "Transcrevendo"
        case .inserting: "Inserindo"
        case .failed: error?.title ?? "Falha no ditado"
        }
    }

    var symbol: String {
        phase == .recording ? "mic.fill"
            : (phase == .failed || (phase == .idle && (!snapshot.isReady || hotkeyUnavailable))
                ? "waveform.badge.exclamationmark" : "waveform")
    }

    var accessibleStatus: String {
        "Resenha — \(activity). Segure \(shortcut.displayName) para ditar."
            + snapshot.missingPermissions.map { " Permissão necessária: \($0.name). \($0.purpose)" }.joined()
    }
}

@MainActor
enum NativeMenuText {
    static func item(_ text: String, availableWidth: CGFloat? = nil) -> NSMenuItem {
        let width = min(360, max(80, (availableWidth ?? NSScreen.main?.visibleFrame.width ?? 384) - 24))
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .menuFont(ofSize: 0)
        label.textColor = .labelColor
        label.cell?.lineBreakMode = .byCharWrapping
        label.preferredMaxLayoutWidth = width - 28
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byCharWrapping
        label.attributedStringValue = NSAttributedString(string: text,
            attributes: [.font: label.font!, .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
        let size = label.attributedStringValue.boundingRect(
            with: NSSize(width: width - 28, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]).size
        label.frame = NSRect(x: 14, y: 5, width: width - 28, height: ceil(size.height))
        label.setAccessibilityLabel(text)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: ceil(size.height) + 10))
        view.addSubview(label)
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.view = view
        item.setAccessibilityLabel(text)
        return item
    }
}
