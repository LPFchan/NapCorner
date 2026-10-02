import AppKit

/// A screen corner. Raw values are macOS's own hot-corner names, as in the
/// `wvous-<raw>-corner` keys of com.apple.dock.
enum Corner: String, CaseIterable, Codable, Identifiable {
    case topLeft = "tl", topRight = "tr", bottomLeft = "bl", bottomRight = "br"

    var id: String { rawValue }

    /// Which way the corner points, in AppKit coordinates (y up): +1 for the
    /// right or top side, -1 for the left or bottom.
    var sx: CGFloat { self == .topRight || self == .bottomRight ? 1 : -1 }
    var sy: CGFloat { self == .topLeft || self == .topRight ? 1 : -1 }

    /// The corner's point in a rect.
    func point(in r: CGRect) -> CGPoint {
        CGPoint(x: sx > 0 ? r.maxX : r.minX, y: sy > 0 ? r.maxY : r.minY)
    }

    /// The corner the cursor is pinned in, if any: within `slop` points of
    /// one of `corners` of a screen, where no other screen continues past it
    /// (the cursor can't be pushed further, the same corners macOS uses).
    static func pinned(at p: CGPoint, in corners: Set<Corner>, slop: CGFloat = 3) -> (Corner, NSScreen)? {
        let screens = NSScreen.screens
        for screen in screens {
            let f = screen.frame
            for c in corners {
                let cp = c.point(in: f)
                // The cursor's last position on the right/top edge is 1 pt
                // inside the frame.
                guard abs(p.x - cp.x) <= slop + 1, abs(p.y - cp.y) <= slop + 1 else { continue }
                let beyond = [CGPoint(x: cp.x + c.sx * 2, y: cp.y - c.sy * 2),
                              CGPoint(x: cp.x - c.sx * 2, y: cp.y + c.sy * 2),
                              CGPoint(x: cp.x + c.sx * 2, y: cp.y + c.sy * 2)]
                if beyond.contains(where: { pt in screens.contains { $0.frame.contains(pt) } }) { continue }
                return (c, screen)
            }
        }
        return nil
    }
}
