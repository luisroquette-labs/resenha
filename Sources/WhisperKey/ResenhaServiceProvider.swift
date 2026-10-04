import AppKit
import OSLog

/// Synchronous boundary required by AppKit's Services contract.
///
/// AppKit asks the requestor to read the returned pasteboard only after this
/// method returns. When invoked on the main thread, the bounded nested run loop
/// keeps UI, key-release and coordinator callbacks moving without extending
/// the declared service timeout.
final class ResenhaServiceProvider: NSObject {
    struct Timing {
        var timeout: TimeInterval = ResenhaRuntimeLimits.serviceTimeout
        var pollInterval: TimeInterval = 0.02
        var uptime: @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    }

    private enum Outcome {
        case transcript(String)
        case failure(String)
    }

    private let logger = Logger(subsystem: "br.com.luisroquette.Resenha", category: "service")
    private let timing: Timing
    private let stateLock = NSLock()
    private var activeRequestID: UUID?
    private var outcome: Outcome?

    /// Returns `true` only when capture was armed and started for this request.
    var beginDictation: (() -> Bool)?
    /// Cancels the active pipeline if AppKit reaches its outer deadline first.
    var cancelDictation: (() -> Void)?

    init(timing: Timing = Timing()) {
        self.timing = timing
        super.init()
    }

    @objc(dictate:userData:error:)
    func dictate(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard let requestID = beginRequest() else {
            error.pointee = "O Resenha já está ouvindo outro ditado."
            return
        }
        defer { reset(requestID: requestID) }

        logger.notice("Sandboxed text service request started")
        guard beginDictation?() == true else {
            error.pointee = "O Resenha não conseguiu iniciar o ditado. Pressione e segure o atalho do Serviço."
            return
        }

        var deadline = MonotonicDeadline(duration: timing.timeout, startedAt: timing.uptime())
        while currentOutcome(requestID: requestID) == nil {
            let remaining = deadline.remaining(at: timing.uptime())
            guard remaining > 0 else { break }
            let pollDuration = min(remaining, max(0.001, timing.pollInterval))
            if Thread.isMainThread {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: pollDuration))
            } else {
                Thread.sleep(forTimeInterval: pollDuration)
            }
        }

        switch currentOutcome(requestID: requestID) {
        case .transcript(let text):
            let legacyString = NSPasteboard.PasteboardType("NSStringPboardType")
            pasteboard.declareTypes([.string, legacyString], owner: nil)
            guard pasteboard.setString(text, forType: .string),
                  pasteboard.setString(text, forType: legacyString) else {
                error.pointee = "O Resenha não conseguiu devolver o texto ao aplicativo."
                return
            }
            logger.notice("Sandboxed text service response completed")
        case .failure(let message):
            error.pointee = message as NSString
        case nil:
            cancelDictation?()
            error.pointee = "O ditado excedeu o tempo máximo do Serviço."
        }
    }

    func complete(with transcript: String) {
        let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            fail(with: "Nenhuma fala foi detectada.")
            return
        }
        finish(.transcript(normalized))
    }

    func fail(with message: String) {
        finish(.failure(message))
    }

    var isServing: Bool {
        stateLock.withLock { activeRequestID != nil }
    }

    private func beginRequest() -> UUID? {
        stateLock.withLock {
            guard activeRequestID == nil else { return nil }
            let requestID = UUID()
            activeRequestID = requestID
            outcome = nil
            return requestID
        }
    }

    private func currentOutcome(requestID: UUID) -> Outcome? {
        stateLock.withLock {
            guard activeRequestID == requestID else { return nil }
            return outcome
        }
    }

    private func finish(_ outcome: Outcome) {
        stateLock.withLock {
            guard activeRequestID != nil, self.outcome == nil else { return }
            self.outcome = outcome
        }
    }

    private func reset(requestID: UUID) {
        stateLock.withLock {
            guard activeRequestID == requestID else { return }
            activeRequestID = nil
            outcome = nil
        }
    }
}
