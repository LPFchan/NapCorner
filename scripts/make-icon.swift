// Renders Resources/Assets.xcassets/AppIcon.appiconset: the arrow pointer
// gliding up toward the top-right corner, where a zzZ drifts off. Run:
// swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appending(path: "Resources/Assets.xcassets/AppIcon.appiconset")

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// The app's palette (Nap/Palette.swift), hue 325.
let deep: UInt32 = 0x341136, dark: UInt32 = 0x581E5C, accent: UInt32 = 0x8C3F91, light: UInt32 = 0xE5A3E8

// Apple's continuous-corner squircle, approximated by a superellipse.
func squircle(in r: CGRect) -> CGPath {
    let n = 5.0, path = CGMutablePath(), steps = 720
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let x = pow(abs(cos(t)), 2 / n) * (cos(t) < 0 ? -1 : 1)
        let y = pow(abs(sin(t)), 2 / n) * (sin(t) < 0 ? -1 : 1)
        let p = CGPoint(x: r.midX + x * r.width / 2, y: r.midY + y * r.height / 2)
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

// Drawn by hand: Apple's licence doesn't allow SF Symbols in app icons. The
// arrow is the same outline as the onboarding demo's (App/NapDemo.swift), on
// a 24-unit grid with y down; `tip` is where its point lands.
func pointer(tip: CGPoint, unit: CGFloat) -> CGPath {
    let pts: [(CGFloat, CGFloat)] = [(2, 2), (2, 19), (6.5, 15), (9.5, 21.5), (12, 20.4), (9, 14), (14.5, 14)]
    let p = CGMutablePath()
    for (i, (x, y)) in pts.enumerated() {
        let q = CGPoint(x: tip.x + (x - 2) * unit, y: tip.y - (y - 2) * unit)
        i == 0 ? p.move(to: q) : p.addLine(to: q)
    }
    p.closeSubpath()
    return p
}

// A Z as one stroke: across, down the diagonal, across again.
func zee(_ c: CGPoint, _ size: CGFloat) -> CGPath {
    let p = CGMutablePath(), h = size / 2
    p.move(to: CGPoint(x: c.x - h, y: c.y + h))
    p.addLine(to: CGPoint(x: c.x + h, y: c.y + h))
    p.addLine(to: CGPoint(x: c.x - h, y: c.y - h))
    p.addLine(to: CGPoint(x: c.x + h, y: c.y - h))
    return p
}

func render(_ px: Int) -> Data {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    // macOS icon grid: an 824-pt rounded square centred on a 1024-pt canvas.
    let body = squircle(in: CGRect(x: 100, y: 100, width: 824, height: 824))
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(body); ctx.setFillColor(color(deep)); ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(body); ctx.clip()
    // Night falling from the bottom left, and the hot corner glowing at the
    // top right.
    let bg = CGGradient(colorsSpace: nil, colors: [color(accent), color(dark), color(deep)] as CFArray,
                        locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 924, y: 924), end: CGPoint(x: 100, y: 100), options: [])
    let glow = CGGradient(colorsSpace: nil, colors: [color(light, 0.75), color(light, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 924, y: 924), startRadius: 0,
                           endCenter: CGPoint(x: 924, y: 924), endRadius: 520, options: [])

    // The pointer's trail, along its way up to the corner.
    ctx.setLineCap(.round)
    ctx.setStrokeColor(color(0xFFFFFF, 0.35))
    ctx.setLineWidth(24)
    for (from, to) in [((250.0, 330.0), (370.0, 450.0)), ((340.0, 230.0), (440.0, 330.0))] {
        ctx.move(to: CGPoint(x: from.0, y: from.1))
        ctx.addLine(to: CGPoint(x: to.0, y: to.1))
        ctx.strokePath()
    }

    let arrow = pointer(tip: CGPoint(x: 420, y: 590), unit: 16)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: CGColor(gray: 0, alpha: 0.45))
    ctx.addPath(arrow)
    ctx.setFillColor(color(0x000000))
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineWidth(26)
    ctx.setLineJoin(.round)
    ctx.drawPath(using: .fillStroke)
    ctx.restoreGState()

    // zzZ, growing as it drifts into the corner.
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineJoin(.round)
    for (c, size, w) in [(CGPoint(x: 540, y: 610), 62.0, 20.0), (CGPoint(x: 645, y: 672), 88.0, 25.0),
                         (CGPoint(x: 782, y: 758), 124.0, 31.0)] as [(CGPoint, CGFloat, CGFloat)] {
        ctx.setLineWidth(w)
        ctx.addPath(zee(c, size))
        ctx.strokePath()
    }
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

var images: [String] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try! render(size * scale).write(to: iconset.appending(path: name))
        images.append("""
            { "filename" : "\(name)", "idiom" : "mac", "scale" : "\(scale)x", "size" : "\(size)x\(size)" }
        """)
    }
}
let contents = "{\n  \"images\" : [\n\(images.joined(separator: ",\n"))\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
try! contents.write(to: iconset.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
print(iconset.path)
