import AppKit
import QuartzCore

/// A black window over one screen. On the screen the nap started from it
/// closes like an iris out of that corner; on the others it fades. It stays
/// up while the display sleeps, so a wake NapCorner undoes shows black
/// instead of a flash of the desktop, and comes down at once when the guard
/// ends.
final class CurtainWindow: NSWindow {
    private let shape = CAShapeLayer()
    private let origin: CGPoint?

    /// `corner` is where the iris grows from, or nil to fade.
    init(screen: NSScreen, corner: Corner?) {
        origin = corner.map { $0.point(in: CGRect(origin: .zero, size: screen.frame.size)) }
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = NSWindow.Level(NSWindow.Level.screenSaver.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        shape.fillColor = NSColor.black.cgColor
        shape.frame = view.bounds
        view.layer?.addSublayer(shape)
        contentView = view
        setFrame(screen.frame, display: false)
    }

    private func circle(_ r: CGFloat) -> CGPath {
        guard let o = origin else { return CGPath(rect: contentView!.bounds, transform: nil) }
        return CGPath(ellipseIn: CGRect(x: o.x - r, y: o.y - r, width: r * 2, height: r * 2), transform: nil)
    }

    private var farRadius: CGFloat {
        let s = contentView!.bounds.size
        return hypot(s.width, s.height) + 40
    }

    /// Covers the screen, then calls `done`.
    func close(duration: TimeInterval, done: @escaping () -> Void) {
        orderFrontRegardless()
        CATransaction.begin()
        CATransaction.setCompletionBlock(done)
        if origin != nil {
            let from = circle(60), to = circle(farRadius)
            shape.path = to
            let a = CABasicAnimation(keyPath: "path")
            a.fromValue = from
            a.toValue = to
            a.duration = duration
            a.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0, 0.3, 1)
            shape.add(a, forKey: "iris")
        } else {
            shape.path = circle(0)
            let a = CABasicAnimation(keyPath: "opacity")
            a.fromValue = 0
            a.toValue = 1
            a.duration = duration
            shape.add(a, forKey: "fade")
        }
        CATransaction.commit()
    }
}
