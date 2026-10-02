import Foundation

/// macOS's own hot corners (System Settings → Desktop & Dock → Hot Corners),
/// stored as `wvous-<corner>-corner` in com.apple.dock.
enum HotCorners {
    private static let domain = "com.apple.dock" as CFString
    /// The action number macOS uses for Put Display to Sleep.
    static let putDisplayToSleep = 10

    private static func key(_ c: Corner) -> String { "wvous-\(c.rawValue)-corner" }

    /// The action macOS has on a corner; 0 and 1 mean none.
    static func action(_ c: Corner) -> Int {
        CFPreferencesAppSynchronize(domain)
        return (CFPreferencesCopyAppValue(key(c) as CFString, domain) as? Int) ?? 0
    }

    static func isUsed(_ c: Corner) -> Bool { action(c) > 1 }

    static var sleepCorners: Set<Corner> {
        Set(Corner.allCases.filter { action($0) == putDisplayToSleep })
    }

    /// Turns macOS's action off on these corners, so it doesn't fire on top
    /// of NapCorner, and restarts the Dock, which owns hot corners.
    static func clear(_ corners: Set<Corner>) {
        let used = corners.filter(isUsed)
        guard !used.isEmpty else { return }
        for c in used {
            run("/usr/bin/defaults", ["write", "com.apple.dock", key(c), "-int", "1"])
            run("/usr/bin/defaults", ["write", "com.apple.dock", "wvous-\(c.rawValue)-modifier", "-int", "0"])
        }
        run("/usr/bin/killall", ["Dock"])
        Log.write("[HotCorners] cleared macOS hot corners: \(used.map(\.rawValue).sorted())")
    }

    private static func run(_ path: String, _ args: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try? p.run()
        p.waitUntilExit()
    }
}
