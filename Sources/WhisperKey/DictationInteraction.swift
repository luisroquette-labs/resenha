struct HotkeyFailureFeedback {
    var lastAttemptFailed = false

    mutating func recordFailure(phase: DictationPhase, explicitCheck: Bool) -> Bool {
        defer { lastAttemptFailed = true }
        return phase.acceptsStatusFeedback && (explicitCheck || !lastAttemptFailed)
    }
}

struct DictationInteraction {
    var openMenuCount = 0
    var isRequestingPermission = false
    private(set) var isPressed = false

    func canStart(phase: DictationPhase, targetIsSelf: Bool) -> Bool {
        phase == .idle && openMenuCount == 0 && !isRequestingPermission && !targetIsSelf
    }

    mutating func press(phase: DictationPhase, targetIsSelf: Bool) -> Bool {
        guard !isPressed, canStart(phase: phase, targetIsSelf: targetIsSelf) else { return false }
        isPressed = true
        return true
    }

    mutating func release() { isPressed = false }
}
