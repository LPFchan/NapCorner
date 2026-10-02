import Foundation

/// A damped spring, x'' = -k(x - target) - c·x', described the way SwiftUI
/// describes its springs: `response` is the period of the undamped motion in
/// seconds, `dampingRatio` 1 settles without overshoot and lower values
/// bounce. Stepped by hand each frame so it can be kicked mid-flight.
struct Spring {
    var value: Double
    var velocity: Double = 0
    var target: Double
    private(set) var stiffness: Double
    private(set) var damping: Double

    init(_ value: Double = 0, response: Double, dampingRatio: Double) {
        self.value = value
        target = value
        stiffness = 0
        damping = 0
        retune(response: response, dampingRatio: dampingRatio)
    }

    /// Changes how it moves, keeping where it is and how fast it's going.
    mutating func retune(response: Double, dampingRatio: Double) {
        stiffness = pow(2 * .pi / response, 2)
        damping = 4 * .pi * dampingRatio / response
    }

    /// Semi-implicit Euler in fixed 1/240 s substeps, so a slow frame can't
    /// make a stiff spring explode.
    mutating func step(_ dt: Double) {
        var left = min(dt, 0.1)
        while left > 0 {
            let h = min(left, 1.0 / 240)
            velocity += (-stiffness * (value - target) - damping * velocity) * h
            value += velocity * h
            left -= h
        }
    }

    var isSettled: Bool { abs(value - target) < 0.001 && abs(velocity) < 0.001 }

    mutating func snap(to v: Double) { value = v; target = v; velocity = 0 }
}
