import CoreGraphics
import Foundation

struct TargetWindowCandidate: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let isOnscreen: Bool
    let quartzFrame: CGRect
    let order: Int
}

enum TargetWindowResolver {
    static func frame(
        for pid: pid_t,
        candidates: [TargetWindowCandidate],
        primaryScreenTop: CGFloat
    ) -> CGRect? {
        candidates
            .filter {
                $0.ownerPID == pid && $0.layer == 0 && $0.isOnscreen &&
                $0.quartzFrame.width >= 80 && $0.quartzFrame.height >= 40
            }
            .sorted {
                if $0.order != $1.order { return $0.order < $1.order }
                return $0.quartzFrame.width * $0.quartzFrame.height > $1.quartzFrame.width * $1.quartzFrame.height
            }
            .first
            .map { appKitFrame(from: $0.quartzFrame, primaryScreenTop: primaryScreenTop) }
    }

    static func appKitFrame(from quartzFrame: CGRect, primaryScreenTop: CGFloat) -> CGRect {
        CGRect(
            x: quartzFrame.minX,
            y: primaryScreenTop - quartzFrame.maxY,
            width: quartzFrame.width,
            height: quartzFrame.height
        )
    }

    static func currentFrame(for pid: pid_t, primaryScreenTop: CGFloat) -> CGRect? {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return nil }

        let candidates = windowInfo.enumerated().compactMap { index, info -> TargetWindowCandidate? in
            guard
                let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                let bounds = info[kCGWindowBounds as String],
                let frame = rect(from: bounds)
            else { return nil }
            let isOnscreen = (info[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
            return TargetWindowCandidate(
                ownerPID: ownerPID,
                layer: layer,
                isOnscreen: isOnscreen,
                quartzFrame: frame,
                order: index
            )
        }
        return frame(for: pid, candidates: candidates, primaryScreenTop: primaryScreenTop)
    }

    private static func rect(from value: Any) -> CGRect? {
        guard
            let values = value as? [String: Any],
            let x = (values["X"] as? NSNumber)?.doubleValue,
            let y = (values["Y"] as? NSNumber)?.doubleValue,
            let width = (values["Width"] as? NSNumber)?.doubleValue,
            let height = (values["Height"] as? NSNumber)?.doubleValue
        else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
