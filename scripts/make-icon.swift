// Renders Resources/Assets.xcassets/AppIcon.appiconset and the homepage
// icons: the arrow pointer gliding up toward the top-right corner, where a
// zzZ drifts off, in the ship skill's icon frame.
// Run: swift scripts/make-icon.swift

// MARK: - Icon frame (ship skill: references/icon-frame.swift)
// Copied verbatim into every app's scripts/make-icon.swift; never tune it per
// app, only the artwork differs. It reproduces icon.kitchen's macOS renderer,
// in 1024-pt canvas units: an 824-pt body (figma squircle, corner radius
// 22.5%, smoothing 0.61), a bevel of two inner shadows (white 44%, 4 down,
// σ 1; black 25%, 3 up, σ 2) and an outer shadow (black 25%, 14 down, σ 10).
import Accelerate
import AppKit

/// The body: icon.kitchen's squircle on the 824-pt grid, y up.
func iconBody() -> CGPath {
    let w: CGFloat = 824, r = 0.225 * w, smoothing: CGFloat = 0.61
    let rad = { (deg: CGFloat) in deg * .pi / 180 }
    // figma-squircle's corner: a bezier, a circular arc, a bezier.
    let p = (1 + smoothing) * r
    let arcMeasure = 90 * (1 - smoothing)
    let arc = sin(rad(arcMeasure / 2)) * r * sqrt(2)
    let c = r * tan(rad((90 - arcMeasure) / 4)) * cos(rad(45 * smoothing))
    let d = c * tan(rad(45 * smoothing))
    let b = (p - arc - c - d) / 3, a = 2 * b
    // y down, like figma-squircle. Each corner in its own frame: k the corner,
    // u along the edge coming in, v along the edge going out.
    let corners: [((CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat))] = [
        ((w, 0), (1, 0), (0, 1)), ((w, w), (0, 1), (-1, 0)),
        ((0, w), (-1, 0), (0, -1)), ((0, 0), (0, -1), (1, 0)),
    ]
    let path = CGMutablePath()
    for (i, (k, u, v)) in corners.enumerated() {
        let at = { (s: CGFloat, t: CGFloat) in
            CGPoint(x: k.0 + u.0 * (s - p) + v.0 * t, y: k.1 + u.1 * (s - p) + v.1 * t)
        }
        if i == 0 { path.move(to: at(0, 0)) } else { path.addLine(to: at(0, 0)) }
        path.addCurve(to: at(a + b + c, d), control1: at(a, 0), control2: at(a + b, 0))
        let s2 = a + b + c + arc, t2 = d + arc
        let o = at(p - r, r), from = at(a + b + c, d), to = at(s2, t2)
        path.addArc(center: o, radius: r, startAngle: atan2(from.y - o.y, from.x - o.x),
                    endAngle: atan2(to.y - o.y, to.x - o.x), clockwise: false)
        path.addCurve(to: at(p, p), control1: at(s2 + d, t2 + c), control2: at(s2 + d, t2 + b + c))
    }
    path.closeSubpath()
    var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 100, ty: 924)
    return path.copy(using: &flip)!
}

/// A plane moved down by `dy` pixels (up if negative), sub-pixel, zero-filled.
func iconShift(_ plane: [Float], _ px: Int, _ dy: Float) -> [Float] {
    let whole = Int(dy.rounded(.down)), f = dy - Float(whole)
    var out = [Float](repeating: 0, count: plane.count)
    for y in 0..<px {
        for (src, weight) in [(y - whole, 1 - f), (y - whole - 1, f)] where weight > 0 && (0..<px).contains(src) {
            for x in 0..<px { out[y * px + x] += weight * plane[src * px + x] }
        }
    }
    return out
}

/// A plane under a gaussian blur of standard deviation `sigma` pixels.
func iconBlur(_ plane: [Float], _ px: Int, _ sigma: Float) -> [Float] {
    let radius = Int((3 * sigma).rounded(.up))
    guard radius >= 1 else { return plane }
    var kernel = (-radius...radius).map { exp(-Float($0 * $0) / (2 * sigma * sigma)) }
    let sum = kernel.reduce(0, +)
    kernel = kernel.map { $0 / sum }
    var src = plane, out = [Float](repeating: 0, count: plane.count)
    src.withUnsafeMutableBytes { s in
        out.withUnsafeMutableBytes { o in
            let n = vImagePixelCount(px)
            var from = vImage_Buffer(data: s.baseAddress, height: n, width: n, rowBytes: px * 4)
            var into = vImage_Buffer(data: o.baseAddress, height: n, width: n, rowBytes: px * 4)
            _ = vImageSepConvolve_PlanarF(&from, &into, nil, 0, 0, kernel, UInt32(kernel.count),
                                          kernel, UInt32(kernel.count), 0, 0, vImage_Flags(kvImageBackgroundColorFill))
        }
    }
    return out
}

/// The icon at `px` square, as PNG data. `art` paints the body in 1024-pt
/// coordinates, y up, already clipped to the body. The current
/// NSGraphicsContext is the same context, so AppKit drawing works too.
func renderIcon(_ px: Int, art: (CGContext) -> Void) -> Data {
    let n = px * px, s = Float(px) / 1024
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: px * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(s), y: CGFloat(s))
    ctx.addPath(iconBody())
    ctx.clip()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    art(ctx)
    NSGraphicsContext.restoreGraphicsState()
    // Premultiplied RGBA, rows top down.
    let bytes = ctx.data!.bindMemory(to: UInt8.self, capacity: n * 4)
    var rgba = (0..<n * 4).map { Float(bytes[$0]) / 255 }
    let alpha = (0..<n).map { rgba[$0 * 4 + 3] }
    for (color, opacity, dy, sigma) in [(Float(1), Float(0.44), Float(4), Float(1)), (0, 0.25, -3, 2)] {
        let cover = iconBlur(iconShift(alpha, px, dy * s), px, sigma * s)
        for i in 0..<n {
            let k = (1 - cover[i]) * opacity
            for ch in 0..<3 { rgba[i * 4 + ch] = rgba[i * 4 + ch] * (1 - k) + color * k * alpha[i] }
        }
    }
    let shadow = iconShift(iconBlur(alpha, px, 10 * s), px, 14 * s)
    for i in 0..<n { rgba[i * 4 + 3] += 0.25 * shadow[i] * (1 - rgba[i * 4 + 3]) }
    for i in 0..<n * 4 { bytes[i] = UInt8((min(max(rgba[i], 0), 1) * 255).rounded()) }
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

/// The ten macOS icon images: file name and pixel size.
let macIconImages = [16, 32, 128, 256, 512].flatMap { pt in
    [1, 2].map { (name: "icon_\(pt)x\(pt)\($0 == 2 ? "@2x" : "").png", pt: pt, scale: $0) }
}

/// Writes an asset catalog .appiconset: the ten images and Contents.json.
func writeAppIconset(_ dir: URL, art: (CGContext) -> Void) {
    try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var entries: [String] = []
    for image in macIconImages {
        try! renderIcon(image.pt * image.scale, art: art).write(to: dir.appending(path: image.name))
        entries.append("""
                { "filename" : "\(image.name)", "idiom" : "mac", "scale" : "\(image.scale)x", "size" : "\(image.pt)x\(image.pt)" }
            """)
    }
    let contents = "{\n  \"images\" : [\n\(entries.joined(separator: ",\n"))\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    try! contents.write(to: dir.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
}

/// Writes an .icns of the ten images, through iconutil.
func writeIcns(_ file: URL, art: (CGContext) -> Void) {
    let iconset = FileManager.default.temporaryDirectory.appending(path: "AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconset)
    try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
    for image in macIconImages {
        try! renderIcon(image.pt * image.scale, art: art).write(to: iconset.appending(path: image.name))
    }
    try! FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", file.path]
    try! iconutil.run()
    iconutil.waitUntilExit()
}

/// Writes one PNG at `px` square, for a homepage or README.
func writePNG(_ file: URL, _ px: Int, art: (CGContext) -> Void) {
    try! FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! renderIcon(px, art: art).write(to: file)
}
// MARK: - End of icon frame

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// The app's palette (Nap/Palette.swift), hue 325.
let deep: UInt32 = 0x341136, dark: UInt32 = 0x581E5C, accent: UInt32 = 0x8C3F91, light: UInt32 = 0xE5A3E8

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

func art(_ ctx: CGContext) {
    // Night falling from the bottom left, and the hot corner glowing at the
    // top right.
    let bg = CGGradient(colorsSpace: nil, colors: [color(accent), color(dark), color(deep)] as CFArray,
                        locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 924, y: 924), end: CGPoint(x: 100, y: 100), options: [])
    let glow = CGGradient(colorsSpace: nil, colors: [color(light, 0.75), color(light, 0.3), color(light, 0)] as CFArray, locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 924, y: 924), startRadius: 0,
                           endCenter: CGPoint(x: 924, y: 924), endRadius: 900, options: [])

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
}

let iconset = root.appending(path: "Resources/Assets.xcassets/AppIcon.appiconset")
writeAppIconset(iconset, art: art)
writePNG(root.appending(path: "docs/icon.png"), 512, art: art)
writePNG(root.appending(path: "docs/favicon.png"), 64, art: art)
print(iconset.path)
