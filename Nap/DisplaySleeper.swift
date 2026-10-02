import AppKit
import CoreGraphics

/// Puts the displays to sleep, then keeps them asleep for a short guard
/// window: a mouse nudge that wakes them in that window is undone straight
/// away. A key press or a click counts as meaning it and ends the guard.
///
/// macOS wakes the display on any HID activity before an app can see the
/// event, so the guard can't stop the wake itself; it puts the display back
/// to sleep behind a black curtain, so the moment awake shows nothing.
@MainActor
final class DisplaySleeper {
    /// True from the start of the curtain until the guard ends.
    private(set) var isBusy = false
    var onFinished: () -> Void = {}

    private var curtains: [CurtainWindow] = []
    private var timer: Timer?
    private var startedAt = Date()
    private var deadline = Date()
    private var lastSleepCall = Date.distantPast
    private var wasAsleep = false
    private var resleeps = 0
    /// How long macOS takes to turn the displays off after it's asked.
    private let sleepTransition = 0.7

    func sleep(from corner: Corner, on screen: NSScreen, guardSeconds: Double) {
        guard !isBusy else { return }
        isBusy = true
        startedAt = Date()
        wasAsleep = false
        resleeps = 0
        curtains = NSScreen.screens.map { CurtainWindow(screen: $0, corner: $0 == screen ? corner : nil) }
        let pending = DispatchGroup()
        for curtain in curtains {
            pending.enter()
            curtain.close(duration: 0.42) { pending.leave() }
        }
        pending.notify(queue: .main) { [weak self] in
            guard let self, self.isBusy else { return }
            self.sleepNow()
            // A wiggle during the transition can cancel the sleep outright,
            // so the guard runs from the request, not from the displays
            // going dark.
            self.deadline = Date().addingTimeInterval(self.sleepTransition + guardSeconds)
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.watch() }
            }
        }
    }

    private func sleepNow() {
        lastSleepCall = Date()
        let pmset = Process()
        pmset.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmset.arguments = ["displaysleepnow"]
        try? pmset.run()
    }

    private var displaysAsleep: Bool {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, &ids, &count)
        let online = ids.prefix(Int(count))
        return !online.isEmpty && online.allSatisfy { CGDisplayIsAsleep($0) != 0 }
    }

    /// A key press or a click since the nap began.
    private var meantToWake: Bool {
        let since = Date().timeIntervalSince(startedAt)
        let types: [CGEventType] = [.keyDown, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        return types.contains { CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0) < since }
    }

    private func watch() {
        let now = Date()
        let asleep = displaysAsleep
        if asleep && !wasAsleep {
            wasAsleep = true
            Log.write("[Sleeper] displays asleep after \(String(format: "%.2f", now.timeIntervalSince(startedAt)))s")
        }
        if meantToWake {
            Log.write("[Sleeper] key or click: waking")
            finish()
        } else if now >= deadline {
            if !wasAsleep { Log.write("[Sleeper] displays never slept") }
            finish()
        } else if !asleep && now.timeIntervalSince(lastSleepCall) > sleepTransition {
            resleeps += 1
            Log.write("[Sleeper] awake \(String(format: "%.2f", now.timeIntervalSince(startedAt)))s in; back to sleep (\(resleeps))")
            sleepNow()
        }
    }

    /// Takes the curtains down at once: asleep, there's nothing to see, and
    /// awake, the desktop should simply be there.
    private func finish() {
        timer?.invalidate()
        timer = nil
        curtains.forEach { $0.orderOut(nil) }
        curtains = []
        isBusy = false
        onFinished()
    }
}
