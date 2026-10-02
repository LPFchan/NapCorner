import AppKit

/// NapCorner's accent, a dusky magenta (OKLCH hue 325), from deep to light.
enum Palette {
    static let deep = NSColor(srgbRed: 0x34 / 255, green: 0x11 / 255, blue: 0x36 / 255, alpha: 1)
    static let dark = NSColor(srgbRed: 0x58 / 255, green: 0x1E / 255, blue: 0x5C / 255, alpha: 1)
    static let accent = NSColor(srgbRed: 0x8C / 255, green: 0x3F / 255, blue: 0x91 / 255, alpha: 1)
    static let light = NSColor(srgbRed: 0xE5 / 255, green: 0xA3 / 255, blue: 0xE8 / 255, alpha: 1)
}
