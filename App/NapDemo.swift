import SwiftUI

/// The real indicator on a pretend screen, looping through a nap: the
/// pointer drifts into the corner, rests and pushes until the pill’s outline fills,
/// the screen goes dark, a bump of the mouse changes nothing, and a key
/// press wakes it.
struct NapDemo: View {
    @State private var model = DemoModel()
    @State private var cursor = CGPoint(x: 0.32, y: 0.68)
    @State private var dark = false
    @State private var bump = 0.0
    @State private var keyDown = false
    @State private var showKey = false
    @State private var showMouse = false

    static let size = CGSize(width: 400, height: 250)

    var body: some View {
        let w = Self.size.width, h = Self.size.height
        ZStack(alignment: .topLeading) {
            // Wallpaper, with a couple of stand-in windows.
            LinearGradient(colors: [Color(white: 0.42), Color(white: 0.2)], startPoint: .top, endPoint: .bottom)
            RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.85))
                .frame(width: 170, height: 110).offset(x: 34, y: 40)
            RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.6))
                .frame(width: 140, height: 90).offset(x: 150, y: 118)

            IndicatorRepresentable(view: model.indicator)
                .frame(width: IndicatorView.size, height: IndicatorView.size)
                .offset(x: w - IndicatorView.size, y: 0)

            Pointer().frame(width: 16, height: 24)
                .offset(x: cursor.x * w - 2, y: cursor.y * h - 2)
                .opacity(dark ? 0 : 1)

            // The curtain, closing out of the top-right corner.
            Circle().fill(.black)
                .frame(width: 2 * hypot(w, h) + 20, height: 2 * hypot(w, h) + 20)
                .scaleEffect(dark ? 1 : 0.001)
                .position(x: w, y: 0)

            if showMouse {
                MouseBump(amount: bump)
                    .position(x: w / 2, y: h * 0.62)
                    .transition(.opacity)
            }
            if showKey {
                Text(verbatim: "⌃")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 38, height: 34)
                    .background(.white.opacity(keyDown ? 0.32 : 0.14), in: .rect(cornerRadius: 7))
                    .scaleEffect(keyDown ? 0.9 : 1)
                    .position(x: w / 2, y: h * 0.62)
                    .transition(.opacity)
            }
        }
        .frame(width: w, height: h)
        .clipShape(.rect(cornerRadius: 12))
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel("The pointer rests in the top-right corner until a pill’s outline fills, then the screen goes dark. Bumping the mouse leaves it dark; pressing a key wakes it.")
        .task { await loop() }
    }

    @MainActor private func loop() async {
        model.indicator.scale = 0.8
        func wait(_ s: Double) async -> Bool {
            try? await Task.sleep(for: .seconds(s))
            return !Task.isCancelled
        }
        while !Task.isCancelled {
            // Into the corner.
            withAnimation(.spring(duration: 0.8, bounce: 0.15)) { cursor = CGPoint(x: 0.995, y: 0.005) }
            guard await wait(0.75) else { return }
            model.arm()
            guard await wait(0.6) else { return }
            // A few shoves into it.
            for _ in 0..<3 {
                model.push(28)
                guard await wait(0.22) else { return }
            }
            while model.progress < 1 { guard await wait(0.05) else { return } }
            model.commit()
            withAnimation(.timingCurve(0.55, 0, 0.3, 1, duration: 0.42)) { dark = true }
            guard await wait(0.6) else { return }
            model.indicator.reset()

            // A bump of the mouse: still dark.
            withAnimation(.easeOut(duration: 0.2)) { showMouse = true }
            for i in 0..<4 {
                withAnimation(.spring(duration: 0.18, bounce: 0.5)) { bump = i % 2 == 0 ? 1 : -1 }
                guard await wait(0.16) else { return }
            }
            withAnimation(.spring(duration: 0.3)) { bump = 0 }
            guard await wait(0.6) else { return }
            withAnimation(.easeIn(duration: 0.2)) { showMouse = false }

            // A key press wakes it.
            withAnimation(.easeOut(duration: 0.2)) { showKey = true }
            guard await wait(0.5) else { return }
            withAnimation(.spring(duration: 0.15)) { keyDown = true }
            guard await wait(0.15) else { return }
            withAnimation(.spring(duration: 0.2)) { keyDown = false; showKey = false }
            cursor = CGPoint(x: 0.97, y: 0.04)
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.38)) { dark = false }
            guard await wait(0.5) else { return }
            withAnimation(.spring(duration: 0.9, bounce: 0.1)) { cursor = CGPoint(x: 0.32, y: 0.68) }
            guard await wait(1.6) else { return }
        }
    }
}

/// Drives the demo's indicator the way NapController drives the real one.
@MainActor @Observable
final class DemoModel {
    let indicator = IndicatorView(frame: NSRect(x: 0, y: 0, width: IndicatorView.size, height: IndicatorView.size))
    private(set) var progress = 0.0
    private var armed = false
    private let holdSeconds = 2.4

    init() {
        indicator.corner = .topRight
        indicator.onFrame = { [weak self] dt in
            MainActor.assumeIsolated {
                guard let self, self.armed else { return }
                self.progress += dt / self.holdSeconds
                self.indicator.setProgress(self.progress)
            }
        }
    }

    func arm() {
        armed = true
        progress = 0
        indicator.arm()
        indicator.setProgress(0)
    }

    func push(_ amount: Double) {
        progress += amount / 160
        indicator.kick(amount * 0.7, amount)
        indicator.setProgress(progress)
    }

    func commit() {
        armed = false
        indicator.commit()
    }
}

private struct IndicatorRepresentable: NSViewRepresentable {
    let view: IndicatorView
    func makeNSView(context: Context) -> IndicatorView { view }
    func updateNSView(_ nsView: IndicatorView, context: Context) {}
}

/// The arrow pointer, drawn by hand.
private struct Pointer: View {
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            let s = size.height / 24
            p.move(to: CGPoint(x: 2 * s, y: 2 * s))
            p.addLine(to: CGPoint(x: 2 * s, y: 19 * s))
            p.addLine(to: CGPoint(x: 6.5 * s, y: 15 * s))
            p.addLine(to: CGPoint(x: 9.5 * s, y: 21.5 * s))
            p.addLine(to: CGPoint(x: 12 * s, y: 20.4 * s))
            p.addLine(to: CGPoint(x: 9 * s, y: 14 * s))
            p.addLine(to: CGPoint(x: 14.5 * s, y: 14 * s))
            p.closeSubpath()
            ctx.fill(p, with: .color(.black))
            ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 1.4 * s, lineJoin: .round))
        }
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
    }
}

/// A mouse wiggling side to side, with motion lines.
private struct MouseBump: View {
    let amount: Double

    var body: some View {
        ZStack {
            Capsule().stroke(.white.opacity(0.75), lineWidth: 2)
                .frame(width: 22, height: 34)
                .overlay(alignment: .top) {
                    Rectangle().fill(.white.opacity(0.75)).frame(width: 2, height: 9).padding(.top, 4)
                }
                .rotationEffect(.degrees(amount * 8))
                .offset(x: amount * 7)
            ForEach([-1.0, 1.0], id: \.self) { side in
                VStack(spacing: 5) {
                    Capsule().frame(width: 9, height: 2)
                    Capsule().frame(width: 6, height: 2)
                }
                .foregroundStyle(.white.opacity(abs(amount) * 0.5))
                .offset(x: side * 26)
            }
        }
    }
}
