import AppKit
import OSLog

#if STORE_DISTRIBUTION
@MainActor
final class ResenhaServiceProvider: NSObject {
    private enum Outcome {
        case transcript(String)
        case failure(String)
    }

    private let logger = Logger(subsystem: "br.com.luisroquette.Resenha", category: "service")
    private var outcome: Outcome?
    private var isServing = false
    var beginDictation: (() -> Void)?

    @objc(dictate:userData:error:)
    func dictate(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        guard !isServing else {
            error.pointee = "O Resenha já está ouvindo outro ditado."
            return
        }
        isServing = true
        outcome = nil
        defer {
            outcome = nil
            isServing = false
        }

        logger.notice("Sandboxed text service request started")
        beginDictation?()
        let deadline = Date().addingTimeInterval(10 * 60)
        while outcome == nil, Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }

        switch outcome {
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
            error.pointee = "O ditado excedeu o tempo máximo de 10 minutos."
        }
    }

    func complete(with transcript: String) {
        guard isServing else { return }
        outcome = .transcript(transcript)
    }

    func fail(with message: String) {
        guard isServing else { return }
        outcome = .failure(message)
    }
}
#endif
