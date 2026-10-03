import AppKit
import CoreGraphics

/// Puts the displays to sleep, then keeps them asleep for a timed or infinite guard
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
    private var wakeObserver: NSObjectProtocol?
    private var startedAt = Date()
    /// nil means the guard lasts until a key press or click.
    private var deadline: Date?
    private var lastSleepCall = Date.distantPast
    private var wasAsleep = false
    /// The displays went dark since the last sleep call, so waking now is a
    /// fresh wake to undo rather than the call still taking effect.
    private var sleptSinceCall = false
    private var guardSeconds = 0.0
    private var resleeps = 0
    /// How long macOS can take to turn the displays off after it's asked.
    private let sleepTransition = 0.7
    /// A wake left over from inside the guard is undone even after it ends,
    /// but never for longer than this.
    private let overtime = 2.0

    func sleep(from corner: Corner, on screen: NSScreen, guardSeconds: Double) {
        guard !isBusy else { return }
        isBusy = true
        startedAt = Date()
        self.guardSeconds = guardSeconds
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
            // The guard counts from the displays going dark; this is the
            // fallback for when a wiggle cancels the sleep and they never do.
            self.deadline = guardSeconds == Preferences.infiniteGuardSeconds
                ? nil : Date().addingTimeInterval(self.sleepTransition + guardSeconds)
            if self.deadline == nil { self.observeDisplayWake() }
            self.sleepNow()
            self.startWatching()
        }
    }

    /// Infinite guards wait on workspace notifications while the displays are
    /// dark, and only poll during a sleep/wake transition.
    private func observeDisplayWake() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.startWatching() }
        }
    }

    private func startWatching() {
        guard isBusy, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.watch() }
        }
    }

    private func sleepNow() {
        lastSleepCall = Date()
        sleptSinceCall = false
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

    private func movedSince(_ date: Date) -> Bool {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: .mouseMoved) < Date().timeIntervalSince(date)
    }

    private func watch() {
        let now = Date()
        let asleep = displaysAsleep
        if asleep {
            sleptSinceCall = true
            if !wasAsleep {
                wasAsleep = true
                deadline = guardSeconds == Preferences.infiniteGuardSeconds
                    ? nil : now.addingTimeInterval(guardSeconds)
                Log.write("[Sleeper] displays asleep after \(String(format: "%.2f", now.timeIntervalSince(startedAt)))s")
            }
        }
        if meantToWake {
            Log.write("[Sleeper] key or click: waking")
            finish()
            return
        }
        // Past the guard, finish once the displays are dark or the mouse moves
        // again; a wake from inside the guard is put back to sleep first.
        if let deadline, now >= deadline {
            if !wasAsleep { Log.write("[Sleeper] displays never slept") }
            if asleep || !wasAsleep || movedSince(deadline) || now >= deadline.addingTimeInterval(overtime) {
                finish()
                return
            }
        }
        if asleep && deadline == nil {
            timer?.invalidate()
            timer = nil
            return
        }
        if !asleep && (sleptSinceCall || now.timeIntervalSince(lastSleepCall) > sleepTransition) {
            resleeps += 1
            Log.write("[Sleeper] awake \(String(format: "%.2f", now.timeIntervalSince(startedAt)))s in; back to sleep (\(resleeps))")
            sleepNow()
        }
    }

    /// Takes the curtains down at once: asleep, there's nothing to see, and
    /// awake, the desktop should simply be there.
    private func finish() {
        Log.write("[Sleeper] done, displays \(displaysAsleep ? "asleep" : "awake")")
        timer?.invalidate()
        timer = nil
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        curtains.forEach { $0.orderOut(nil) }
        curtains = []
        isBusy = false
        onFinished()
    }
}
