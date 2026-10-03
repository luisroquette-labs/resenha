import AppKit
import OSLog

private final class ServiceProvider: NSObject {
    private let logger = Logger(subsystem: "br.com.luisroquette.Resenha.ServiceProbe", category: "service")

    @objc(insertProbe:userData:error:)
    func insertProbe(
        _ pasteboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>
    ) {
        logger.notice("Service request received")
        let legacyString = NSPasteboard.PasteboardType("NSStringPboardType")
        pasteboard.declareTypes([.string, legacyString], owner: nil)
        let modernResult = pasteboard.setString("Resenha Service OK", forType: .string)
        let legacyResult = pasteboard.setString("Resenha Service OK", forType: legacyString)
        guard modernResult, legacyResult else {
            logger.error("Service pasteboard write failed")
            error.pointee = "O serviço não conseguiu devolver texto."
            return
        }
        logger.notice("Service response ready")
    }
}

private final class ProbeDelegate: NSObject, NSApplicationDelegate {
    private let provider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = provider
        Logger(subsystem: "br.com.luisroquette.Resenha.ServiceProbe", category: "service")
            .notice("Service provider registered")
    }
}

private let application = NSApplication.shared
private let delegate = ProbeDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
