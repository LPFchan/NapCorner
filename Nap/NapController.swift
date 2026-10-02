import AppKit

/// Watches the cursor. Resting in one of the chosen corners fills the
/// indicator over `Preferences.holdSeconds`; pushing the mouse further into
/// the corner fills it faster (`Preferences.pushDistance` points of push fill
/// it alone). Full, the trackpad taps once. Leaving the corner lets it spring away. Full, the displays go
/// to sleep behind a curtain and DisplaySleeper guards the wake.
///
/// Mouse-moved events from a global monitor need no permission, and keep
/// reporting how far the mouse moved even when the cursor is stuck in the
/// corner: that's the push.
@MainActor
final class NapController {
    private let panel = IndicatorPanel()
    private let sleeper = DisplaySleeper()
    private var monitors: [Any] = []
    private var armed: (corner: Corner, screen: NSScreen)?
    private var progress = 0.0
    private var armedAt = Date()
    /// Pushes this soon after arriving don't count: they're the tail of the
    /// flick that brought the cursor here, not a push.
    private let settleSeconds = 0.3
    /// No single mouse event counts for more than this, so a few big jumps
    /// can't add up to a push; holding a push for a moment does.
    private let maxPushPerEvent = 18.0
    /// Points pushed into the corner since it armed, for the log.
    private var pushed = 0.0
    /// After a nap the cursor is still in the corner; it has to leave before
    /// the corner can arm again.
    private var waitingToLeave = false
    var corners = Preferences.corners

    var isRunning: Bool { !monitors.isEmpty }

    init() {
        panel.indicator.onFrame = { [weak self] dt in self?.frame(dt) }
        panel.indicator.onHidden = { [weak self] in self?.panel.orderOut(nil) }
        sleeper.onFinished = { [weak self] in
            self?.panel.indicator.reset()
            self?.panel.orderOut(nil)
        }
    }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.moved(event) }
        }) { monitors.append(global) }
        // A global monitor misses events headed for NapCorner's own windows.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.moved(event) }
            return event
        }) { monitors.append(local) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        disarm()
    }

    private func moved(_ event: NSEvent) {
        guard !sleeper.isBusy else { return }
        let p = NSEvent.mouseLocation
        // Dragging something into a corner isn't asking for a nap.
        let pinned = NSEvent.pressedMouseButtons == 0 ? Corner.pinned(at: p, in: corners) : nil
        if waitingToLeave {
            if pinned == nil { waitingToLeave = false }
            return
        }
        if let armed {
            let cp = armed.corner.point(in: armed.screen.frame)
            // A little slack, so a wobble doesn't drop a nap that's nearly there.
            if abs(p.x - cp.x) > 14 || abs(p.y - cp.y) > 14 || NSEvent.pressedMouseButtons != 0 {
                disarm()
                return
            }
            // deltaY grows downward; AppKit's y grows upward.
            let inX = max(0, Double(event.deltaX * armed.corner.sx))
            let inY = max(0, Double(-event.deltaY * armed.corner.sy))
            guard inX + inY > 0 else { return }
            panel.indicator.kick(inX, inY)
            guard Date().timeIntervalSince(armedAt) > settleSeconds else { return }
            let push = min(inX + inY, maxPushPerEvent)
            pushed += push
            progress += push / Preferences.pushDistance
            panel.indicator.setProgress(progress)
        } else if let pinned {
            arm(pinned.0, pinned.1)
        }
    }

    private func arm(_ corner: Corner, _ screen: NSScreen) {
        armed = (corner, screen)
        armedAt = Date()
        progress = 0
        Log.write("[Nap] armed \(corner.rawValue)")
        panel.show(at: corner, on: screen)
        panel.indicator.arm()
        panel.indicator.setProgress(0)
    }

    private func disarm() {
        guard armed != nil else { return }
        Log.write("[Nap] disarmed at \(String(format: "%.2f", progress)), pushed \(Int(pushed)) pt")
        armed = nil
        progress = 0
        pushed = 0
        panel.indicator.disarm()
    }

    private func frame(_ dt: Double) {
        guard armed != nil else { return }
        // A frame after the displays slept can come seconds late.
        progress += min(dt, 0.05) / Preferences.holdSeconds
        panel.indicator.setProgress(progress)
        if progress >= 1 { nap() }
    }

    private func nap() {
        guard let (corner, screen) = armed else { return }
        armed = nil
        waitingToLeave = true
        Log.write("[Nap] nap from \(corner.rawValue), pushed \(Int(pushed)) pt")
        pushed = 0
        panel.indicator.commit()
        Haptics.tap()
        sleeper.sleep(from: corner, on: screen, guardSeconds: Preferences.guardSeconds)
    }

    #if DEBUG
    /// `--preview-indicator`: arms the top-right corner of the main screen
    /// and loops the fill with a few pushes, without ever napping, so the
    /// indicator can be looked at (and screenshotted) by itself.
    func previewIndicator() {
        guard let screen = NSScreen.main else { return }
        panel.indicator.onFrame = { _ in }
        Task { @MainActor in
            while true {
                panel.show(at: .topRight, on: screen)
                panel.indicator.arm()
                for i in 0...60 {
                    panel.indicator.setProgress(Double(i) / 60)
                    if i % 20 == 10 { panel.indicator.kick(30, 20) }
                    try? await Task.sleep(for: .milliseconds(40))
                }
                try? await Task.sleep(for: .seconds(0.6))
                panel.indicator.disarm()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    #endif
}
