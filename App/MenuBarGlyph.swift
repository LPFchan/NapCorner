import AppKit

/// The menu bar icon: "zzZ", the z's growing toward the last one like the
/// indicator's. A template image, so macOS tints it.
enum MenuBarGlyph {
    static func image(dimmed: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
            var x: CGFloat = 1
            let baseline: CGFloat = 2.5
            for size in [8.0, 10.5, 14.0] {
                let font = NSFont.systemFont(ofSize: size, weight: .heavy)
                let z = NSAttributedString(string: "Z", attributes: [
                    .font: font,
                    .foregroundColor: NSColor.black.withAlphaComponent(dimmed ? 0.4 : 1),
                ])
                z.draw(at: CGPoint(x: x, y: baseline + font.descender))
                x += z.size().width - 0.3
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
