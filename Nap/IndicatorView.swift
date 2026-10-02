import AppKit
import QuartzCore

/// A black pill that springs out of a screen corner while the cursor rests
/// there and types itself out, one character at a time, as the nap gets
/// closer: "Sleeping" → "Sleeping ..." → "Sleeping ... Z" → "… zZ" →
/// "… zzZ" → "… zzzZ". Each new character slides in at the right; the
/// newest z is always the big one and the others shrink so their sizes ramp
/// evenly up to it. The pill swells as a white stroke wraps around it with
/// the progress, and squashes against the walls when the mouse is pushed
/// into the corner. All motion is hand-stepped springs, so a push can kick it
/// mid-flight.
///
/// The view only draws what it's told: `arm()`, `setProgress(_:)`,
/// `kick(_:_:)` and `commit()` come from NapController (or the onboarding
/// demo).
/// How each of the indicator's springs moves, kept in one place so the
/// Spring Tuner (debug builds) can change them while it runs.
enum Feel: String, CaseIterable {
    case pop, width, fill, swell, squash, letterPop, letterSlide, zSize

    var standard: (response: Double, dampingRatio: Double) {
        switch self {
        case .pop: (0.42, 0.58)
        case .width: (1.0, 0.62)
        case .fill: (0.16, 1)
        case .swell: (0.4, 0.55)
        case .squash: (0.32, 0.38)
        case .letterPop: (0.34, 0.5)
        case .letterSlide: (0.32, 0.72)
        case .zSize: (0.34, 0.6)
        }
    }

    var current: (response: Double, dampingRatio: Double) {
        #if DEBUG
        SpringTuner.value(for: self)
        #else
        standard
        #endif
    }
}

extension Spring {
    init(_ value: Double, _ feel: Feel) {
        let f = feel.current
        self.init(value, response: f.response, dampingRatio: f.dampingRatio)
    }

    mutating func tune(_ feel: Feel) {
        let f = feel.current
        retune(response: f.response, dampingRatio: f.dampingRatio)
    }
}

final class IndicatorView: NSView {
    var corner: Corner = .topRight { didSet { needsDisplay = true } }
    /// Draws everything smaller, for the onboarding demo.
    var scale: Double = 1 { didSet { pieces = nil } }
    /// Called once everything has sprung back to nothing after a disarm.
    var onHidden: () -> Void = {}
    /// Called every frame with the elapsed time, while the view is animating.
    var onFrame: (Double) -> Void = { _ in }

    /// Gap between the pill and the two walls of the corner.
    static let inset: Double = 8
    static let height: Double = 30
    static let padding: Double = 14
    static let size: CGFloat = 240
    /// How many steps the text types out in: the word, three dots, four z's.
    static let stages = 8
    /// The first z's size against the newest (biggest) one.
    static let smallestZ = 0.5

    /// One part of the text that pops in on its own: the word, a dot, a z.
    private struct Piece {
        let text: NSAttributedString
        /// Width at full size.
        let width: Double
        /// The stage it appears at.
        let stage: Int
        /// Space before it, when it isn't the first one showing.
        let gap: Double
        let isZ: Bool
        var shown = Spring(0, .letterPop)
        var x = Spring(0, .letterSlide)
        /// A z's size against the biggest; 1 for everything else.
        var size = Spring(1, .zSize)
    }

    /// How far the pill has sprung out of the corner: 0 tucked in, 1 out.
    private var shown = Spring(0, .pop)
    private var width = Spring(0, .width)
    private var fill = Spring(0, .fill)
    /// Extra size as the stroke fills: the pill swells toward its nap.
    private var swell = Spring(0, .swell)
    static let maxSwell = 0.35
    /// Squash along each wall: negative is pressed flat against it.
    private var squashX = Spring(0, .squash)
    private var squashY = Spring(0, .squash)
    private var pieces: [Piece]?
    private var stage = 0
    private var time = 0.0
    private var armed = false
    private var committed = false
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?

    override var isFlipped: Bool { false }
    override var isOpaque: Bool { false }

    func arm() {
        armed = true
        committed = false
        stage = 0
        layoutPieces(snap: true)
        shown.target = 1
        startLink()
    }

    /// 0…1, how close the nap is.
    func setProgress(_ p: Double) {
        let p = min(max(p, 0), 1)
        fill.target = p
        if !committed { swell.target = p * Self.maxSwell }
        let s = min(Int(p * Double(Self.stages)), Self.stages - 1)
        if s != stage && !committed {
            stage = s
            layoutPieces(snap: false)
        }
    }

    /// The mouse moved this far (points) into the corner, along each wall.
    func kick(_ inX: Double, _ inY: Double) {
        squashX.velocity -= min(inX, 80) * 0.09
        squashY.velocity -= min(inY, 80) * 0.09
        startLink()
    }

    func disarm() {
        armed = false
        shown.target = 0
        fill.target = 0
        swell.target = 0
        startLink()
    }

    /// The nap starts: everything typed out and one last swell before the
    /// curtain covers it.
    func commit() {
        committed = true
        fill.target = 1
        swell.target = Self.maxSwell
        stage = Self.stages - 1
        layoutPieces(snap: false)
        shown.target = 1.15
        shown.velocity += 4
        startLink()
    }

    /// Puts everything back at rest without animating.
    func reset() {
        armed = false
        committed = false
        stage = 0
        for s in [\IndicatorView.shown, \.fill, \.swell, \.squashX, \.squashY] as [ReferenceWritableKeyPath<IndicatorView, Spring>] {
            self[keyPath: s].snap(to: 0)
        }
        needsDisplay = true
    }

    // MARK: - Text

    private func makePieces() -> [Piece] {
        let k = scale
        func piece(_ text: String, size: Double, weight: NSFont.Weight, stage: Int, gap: Double, isZ: Bool = false) -> Piece {
            let s = NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: size * k, weight: weight),
                .foregroundColor: NSColor.white,
            ])
            return Piece(text: s, width: s.size().width, stage: stage, gap: gap * k, isZ: isZ)
        }
        let word = letters(of: String(localized: "Sleeping", comment: "The indicator, while the display is about to sleep"))
        let dots = (1...3).map { piece(".", size: 13, weight: .bold, stage: $0, gap: $0 == 1 ? 4 : 1) }
        // All capitals: a small Z reads as a z, and the size can then shrink
        // smoothly instead of swapping letters.
        let zs = (4...7).map { piece("Z", size: 15, weight: .heavy, stage: $0, gap: $0 == 4 ? 6 : 0.5, isZ: true) }
        return word + dots + zs
    }

    /// The word as one piece per letter, so each can ride the wave; each
    /// letter's width is its advance in the whole word, so the spacing stays
    /// the font's. Scripts whose letters join up (Arabic, Indic) stay whole.
    private func letters(of word: String) -> [Piece] {
        let font = NSFont.systemFont(ofSize: 13 * scale, weight: .semibold)
        func width(_ s: String) -> Double { NSAttributedString(string: s, attributes: [.font: font]).size().width }
        let joins = word.unicodeScalars.contains { (0x0590...0x08FF).contains($0.value) || (0x0900...0x0DFF).contains($0.value) }
        let parts = joins ? [word] : word.map(String.init)
        var prefix = "", x = 0.0
        return parts.map { part in
            prefix += part
            let next = width(prefix)
            defer { x = next }
            let text = NSAttributedString(string: part, attributes: [.font: font, .foregroundColor: NSColor.white])
            return Piece(text: text, width: next - x, stage: 0, gap: 0, isZ: false)
        }
    }

    /// Sets where and how big each piece should be for the current stage;
    /// the springs get them there.
    private func layoutPieces(snap: Bool) {
        if pieces == nil { pieces = makePieces() }
        guard var list = pieces else { return }
        let zCount = list.filter { $0.isZ && $0.stage <= stage }.count
        var x = 0.0
        var zIndex = 0
        for i in list.indices {
            let on = list[i].stage <= stage
            var size = 1.0
            if list[i].isZ && on && zCount > 1 {
                size = Self.smallestZ + (1 - Self.smallestZ) * Double(zIndex) / Double(zCount - 1)
            }
            if list[i].isZ && on { zIndex += 1 }
            list[i].size.target = size
            if on {
                if i > 0 { x += list[i].gap }
                // A newcomer slides in from the right.
                if list[i].shown.target == 0 && !snap { list[i].x.snap(to: x + 18 * scale) }
                list[i].x.target = x
                x += list[i].width * size
            }
            list[i].shown.target = on ? 1 : 0
            if snap {
                list[i].shown.snap(to: list[i].shown.target)
                list[i].x.snap(to: list[i].x.target)
                list[i].size.snap(to: size)
            }
        }
        pieces = list
        width.target = x + 2 * Self.padding * scale
        if snap { width.snap(to: width.target) }
    }

    // MARK: - Frames

    private func startLink() {
        guard link == nil, window != nil else { return }
        lastTimestamp = nil
        let link = displayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { link?.invalidate(); link = nil } else if armed { startLink() }
    }

    @objc private func step(_ link: CADisplayLink) {
        // The first frame after the displays slept can come seconds late.
        let dt = min(lastTimestamp.map { link.targetTimestamp - $0 } ?? 1.0 / 60, 0.05)
        lastTimestamp = link.targetTimestamp
        time += dt
        onFrame(dt)
        #if DEBUG
        retune()
        #endif
        shown.step(dt); width.step(dt); fill.step(dt); swell.step(dt)
        squashX.step(dt); squashY.step(dt)
        squashX.value = max(squashX.value, -0.4)
        squashY.value = max(squashY.value, -0.4)
        if var list = pieces {
            for i in list.indices { list[i].shown.step(dt); list[i].x.step(dt); list[i].size.step(dt) }
            pieces = list
        }
        needsDisplay = true
        if !armed && !committed && shown.isSettled && shown.value < 0.01 {
            link.invalidate()
            self.link = nil
            onHidden()
        }
    }

    #if DEBUG
    /// Picks up whatever the Spring Tuner has set, every frame.
    private func retune() {
        shown.tune(.pop); width.tune(.width); fill.tune(.fill); swell.tune(.swell)
        squashX.tune(.squash); squashY.tune(.squash)
        guard var list = pieces else { return }
        for i in list.indices { list[i].shown.tune(.letterPop); list[i].x.tune(.letterSlide); list[i].size.tune(.zSize) }
        pieces = list
    }
    #endif

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        guard shown.value > 0.01 else { return }
        let grow = shown.value * (1 + swell.value)
        let k = scale
        let c = corner.point(in: bounds)
        let ix = -corner.sx, iy = -corner.sy
        let inset = Self.inset * k
        // Pressed against a wall it flattens there and bulges the other way,
        // and slides into the gap.
        let dx = squashX.value, dy = squashY.value
        let w = width.value * (1 + 0.25 * dx - 0.2 * dy)
        let h = Self.height * k * (1 + 0.7 * dy - 0.35 * dx)
        let anchor = CGPoint(x: c.x + ix * inset * (1 + dx), y: c.y + iy * inset * (1 + dy))
        let center = CGPoint(x: anchor.x + ix * w / 2, y: anchor.y + iy * h / 2)

        ctx.saveGState()
        // Springs out of the corner: scaled about the pill's corner-most point.
        ctx.translateBy(x: anchor.x, y: anchor.y)
        ctx.scaleBy(x: grow, y: grow)
        ctx.translateBy(x: -anchor.x, y: -anchor.y)
        ctx.setAlpha(min(shown.value * 1.6, 1))

        let pill = CGPath(roundedRect: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h),
                          cornerWidth: h / 2, cornerHeight: h / 2, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2 * k), blur: 10 * k,
                      color: NSColor.black.withAlphaComponent(0.4).cgColor)
        ctx.addPath(pill)
        ctx.setFillColor(NSColor.black.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // The stroke: a faint track, and the fill wrapping around from the
        // pill's inner end, along the wall side first.
        let lw = 2 * k, sw = w - lw * 2, sh = h - lw * 2
        let track = capsule(width: sw, height: sh, center: center)
        ctx.setLineWidth(lw)
        ctx.setLineCap(.round)
        ctx.addPath(track)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.16).cgColor)
        ctx.strokePath()
        let f = min(max(fill.value, 0), 1)
        if f > 0.003 {
            let length = 2 * (sw - sh) + .pi * sh
            ctx.addPath(track.copy(dashingWithPhase: 0, lengths: [length * f, length * 2]))
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.strokePath()
        }

        // The text, inside the pill and clipped to it.
        ctx.addPath(pill)
        ctx.clip()
        let left = center.x - w / 2 + Self.padding * k
        // The text's baseline, so z's of different sizes sit on one line.
        let font = NSFont.systemFont(ofSize: 13 * k, weight: .semibold)
        let baseline = center.y - (font.ascender + font.descender) / 2
        for piece in pieces ?? [] {
            let s = piece.shown.value
            guard s > 0.02 else { continue }
            // One wave travelling left to right through all of the text.
            let bob = sin(time * 3.4 - piece.x.value / (9 * k)) * (piece.isZ ? 1.6 : 1.1) * k
            let z = max(piece.size.value, 0.01)
            let bottom = CGPoint(x: left + piece.x.value + piece.width * z / 2, y: baseline + bob)
            ctx.saveGState()
            // Grows out of its own spot on the baseline.
            ctx.translateBy(x: bottom.x, y: bottom.y)
            ctx.scaleBy(x: max(s * z, 0.01), y: max(s * z, 0.01))
            ctx.setAlpha(min(s, 1))
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            let f = piece.text.attribute(.font, at: 0, effectiveRange: nil) as! NSFont
            piece.text.draw(at: CGPoint(x: -piece.width / 2, y: f.descender))
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    /// A capsule path that starts at the end facing away from the corner
    /// and runs along the wall-side edge first.
    private func capsule(width w: Double, height h: Double, center p: CGPoint) -> CGPath {
        let r = h / 2, half = max(w / 2 - r, 0)
        let path = CGMutablePath()
        // Built for the top-right corner (y up, clockwise from the left end),
        // then mirrored for the others.
        path.move(to: CGPoint(x: -half - r, y: 0))
        path.addArc(center: CGPoint(x: -half, y: 0), radius: r, startAngle: .pi, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: half, y: r))
        path.addArc(center: CGPoint(x: half, y: 0), radius: r, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: -half, y: -r))
        path.addArc(center: CGPoint(x: -half, y: 0), radius: r, startAngle: -.pi / 2, endAngle: -.pi, clockwise: true)
        var t = CGAffineTransform(translationX: p.x, y: p.y).scaledBy(x: corner.sx, y: corner.sy)
        return path.copy(using: &t)!
    }
}

/// The borderless, click-through window that holds an IndicatorView in a
/// screen corner, above full-screen apps and the menu bar.
final class IndicatorPanel: NSPanel {
    let indicator = IndicatorView()

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: IndicatorView.size, height: IndicatorView.size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = indicator
    }

    func show(at corner: Corner, on screen: NSScreen) {
        let size = IndicatorView.size
        let p = corner.point(in: screen.frame)
        setFrameOrigin(NSPoint(x: corner.sx > 0 ? p.x - size : p.x, y: corner.sy > 0 ? p.y - size : p.y))
        indicator.corner = corner
        orderFrontRegardless()
    }
}
