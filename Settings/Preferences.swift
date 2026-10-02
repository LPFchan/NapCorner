import Foundation

/// NapCorner's settings, in UserDefaults.
enum Preferences {
    private static let defaults = UserDefaults.standard

    static let holdRange = 0.5...5.0
    static let pushRange = 150.0...1200.0
    static let guardRange = 0.0...3.0

    static var enabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    /// The corners NapCorner watches. The first time, the corners macOS uses
    /// for Put Display to Sleep, or top right.
    static var corners: Set<Corner> {
        get {
            if let raw = defaults.stringArray(forKey: "corners") {
                return Set(raw.compactMap(Corner.init(rawValue:)))
            }
            let fromMacOS = HotCorners.sleepCorners
            return fromMacOS.isEmpty ? [.topRight] : fromMacOS
        }
        set { defaults.set(newValue.map(\.rawValue).sorted(), forKey: "corners") }
    }

    /// Seconds of resting in the corner that start a nap.
    static var holdSeconds: Double {
        get { defaults.object(forKey: "holdSeconds") as? Double ?? 1.5 }
        set { defaults.set(newValue, forKey: "holdSeconds") }
    }

    /// Points of pushing into the corner that start a nap on their own.
    static var pushDistance: Double {
        get { defaults.object(forKey: "pushDistance") as? Double ?? 350 }
        set { defaults.set(newValue, forKey: "pushDistance") }
    }

    /// Seconds after the displays sleep during which the mouse can't wake them.
    static var guardSeconds: Double {
        get { defaults.object(forKey: "guardSeconds") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "guardSeconds") }
    }
}
