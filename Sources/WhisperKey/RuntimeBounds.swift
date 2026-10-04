import Foundation

enum ResenhaRuntimeLimits {
    static let maximumRecordingDuration: TimeInterval = 5 * 60
    static let maximumInferenceDuration: TimeInterval = 4.5 * 60
    static let serviceTimeout: TimeInterval = 10 * 60
    static let whisperContextIdleLifetime: TimeInterval = 45

    static var serviceBudgetIsValid: Bool {
        maximumRecordingDuration + maximumInferenceDuration < serviceTimeout
    }
}

enum WhisperAbortReason: Equatable {
    case cancelled
    case timedOut
}

struct MonotonicDeadline {
    private let deadline: TimeInterval
    private var lastObservedUptime: TimeInterval

    init(duration: TimeInterval, startedAt: TimeInterval) {
        lastObservedUptime = startedAt
        deadline = startedAt + max(0, duration)
    }

    mutating func remaining(at uptime: TimeInterval) -> TimeInterval {
        lastObservedUptime = max(lastObservedUptime, uptime)
        return max(0, deadline - lastObservedUptime)
    }

    mutating func hasExpired(at uptime: TimeInterval) -> Bool {
        remaining(at: uptime) == 0
    }
}

final class WhisperCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private let deadline: TimeInterval
    private let clock: @Sendable () -> TimeInterval
    private var cancelled = false

    init(
        maximumRuntime: TimeInterval,
        startedAt: TimeInterval = ProcessInfo.processInfo.systemUptime,
        clock: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        deadline = startedAt + max(0, maximumRuntime)
        self.clock = clock
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }

    func abortReason(taskIsCancelled: Bool = false) -> WhisperAbortReason? {
        lock.withLock {
            if cancelled || taskIsCancelled { return .cancelled }
            return clock() >= deadline ? .timedOut : nil
        }
    }
}

struct WhisperContextUnloadGate {
    private(set) var generation: UInt64 = 0

    mutating func beginUse() {
        generation &+= 1
    }

    mutating func scheduleUnload() -> UInt64 {
        generation &+= 1
        return generation
    }

    func permitsUnload(generation candidate: UInt64) -> Bool {
        candidate == generation
    }

    mutating func invalidate() {
        generation &+= 1
    }
}
