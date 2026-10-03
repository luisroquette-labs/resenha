import AppKit

enum TextInjectionError: LocalizedError, Equatable {
    case emptyText
    case clipboardUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyText: "The transcript is empty."
        case .clipboardUnavailable: "The transcript could not be copied."
        }
    }
}

struct TextInjector {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    func stage(_ text: String) throws -> Int {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TextInjectionError.emptyText
        }
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else { throw TextInjectionError.clipboardUnavailable }
        return pasteboard.changeCount
    }
}
