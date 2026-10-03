import AppKit

enum PanelTarget: Equatable {
    case session(pid_t?)
    case standalone(pid_t?)
}

struct PanelScreen: Equatable {
    let id: UInt32
    let frame: CGRect
    let visibleFrame: CGRect
}

enum PanelPlacement {
    // AX uses a top-left origin on the primary display, AppKit a bottom-left origin.
    static func appKitFrame(fromAX frame: CGRect, primaryFrame: CGRect) -> CGRect {
        CGRect(x: frame.minX, y: primaryFrame.maxY - frame.maxY, width: frame.width, height: frame.height)
    }

    static func screen(for window: CGRect?, screens: [PanelScreen], fallbackID: UInt32?) -> PanelScreen? {
        if let window, !window.isEmpty {
            let intersections = screens.map { screen -> (PanelScreen, CGFloat) in
                let intersection = screen.frame.intersection(window)
                return (screen, intersection.isNull ? 0 : intersection.width * intersection.height)
            }
            if let largest = intersections.map(\.1).max(), largest > 0 {
                let candidates = intersections.filter { $0.1 == largest }.map(\.0)
                let center = CGPoint(x: window.midX, y: window.midY)
                return candidates.first(where: { $0.frame.contains(center) }) ?? candidates.first
            }
        }
        return screens.first(where: { $0.id == fallbackID }) ?? screens.first
    }

    static func panelFrame(size: CGSize, visibleFrame: CGRect) -> CGRect {
        let available = visibleFrame.insetBy(dx: min(12, visibleFrame.width / 2), dy: min(12, visibleFrame.height / 2))
        let width = min(size.width, available.width)
        let height = min(size.height, available.height)
        return CGRect(x: available.midX - width / 2,
                      y: min(max(visibleFrame.minY + 88, available.minY), available.maxY - height),
                      width: width, height: height)
    }
}

struct PanelScreenSelection {
    private(set) var latestExternalTarget: pid_t?
    private(set) var displayByTarget: [pid_t: UInt32] = [:]
    private(set) var sessionTarget: pid_t?
    private(set) var sessionDisplay: UInt32?
    private(set) var hasSession = false

    mutating func rememberExternalTarget(_ pid: pid_t?) {
        if let pid { latestExternalTarget = pid }
    }

    func standaloneTarget(explicit: pid_t?, frontmost: pid_t?, ownPID: pid_t) -> pid_t? {
        [explicit, frontmost, latestExternalTarget].compactMap { $0 }.first { $0 != ownPID }
    }

    mutating func beginSession(pid: pid_t?, window: CGRect?, screens: [PanelScreen], mainID: UInt32?) {
        rememberExternalTarget(pid)
        sessionTarget = pid
        sessionDisplay = resolve(pid: pid, window: window, screens: screens, mainID: mainID)?.id
        hasSession = true
    }

    mutating func resolve(pid: pid_t?, window: CGRect?, screens: [PanelScreen], mainID: UInt32?) -> PanelScreen? {
        let remembered = pid.flatMap { displayByTarget[$0] }
        let fallback = screens.contains(where: { $0.id == remembered }) ? remembered : mainID
        let screen = PanelPlacement.screen(for: window, screens: screens, fallbackID: fallback)
        if let pid, let screen { displayByTarget[pid] = screen.id }
        return screen
    }

    mutating func sessionScreen(screens: [PanelScreen], mainID: UInt32?) -> PanelScreen? {
        let fallback = screens.contains(where: { $0.id == sessionDisplay }) ? sessionDisplay : mainID
        let screen = PanelPlacement.screen(for: nil, screens: screens, fallbackID: fallback)
        sessionDisplay = screen?.id
        if let sessionTarget, let screen { displayByTarget[sessionTarget] = screen.id }
        return screen
    }

    mutating func endSession() {
        hasSession = false
        sessionTarget = nil
        sessionDisplay = nil
    }
}
