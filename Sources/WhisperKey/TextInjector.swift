import AppKit
import ApplicationServices

enum TextInjectionError: LocalizedError, Equatable {
    case emptyText
    case clipboardUnavailable
    case clipboardChanged
    case targetUnavailable
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .emptyText: "The transcript is empty."
        case .clipboardUnavailable: "The transcript could not be copied."
        case .clipboardChanged: "The clipboard changed before paste."
        case .targetUnavailable: "The original application is no longer available."
        case .eventCreationFailed: "macOS could not create the paste command."
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

    func insertStaged(into target: NSRunningApplication?, changeCount: Int) async throws {
        guard let target, !target.isTerminated else { throw TextInjectionError.targetUnavailable }

        guard target.activate() else {
            throw TextInjectionError.targetUnavailable
        }
        for _ in 0..<10 {
            if TextInjectionTargetPolicy.isExpectedTarget(
                targetPID: target.processIdentifier,
                frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier
            ) { break }
            try await Task.sleep(for: .milliseconds(40))
        }
        guard TextInjectionTargetPolicy.isExpectedTarget(
            targetPID: target.processIdentifier,
            frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier
        ) else { throw TextInjectionError.targetUnavailable }
        guard pasteboard.changeCount == changeCount else { throw TextInjectionError.clipboardChanged }

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            throw TextInjectionError.eventCreationFailed
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

enum TextInjectionTargetPolicy {
    static func isExpectedTarget(targetPID: pid_t, frontmostPID: pid_t?) -> Bool {
        frontmostPID == targetPID
    }
}
