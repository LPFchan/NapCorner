#if DEBUG
import AppKit
import SwiftUI

/// Debug builds only: a window with sliders for every spring in the
/// indicator and a live copy of it to watch. Changes apply on the next frame,
/// everywhere (the real corner too), and stick across launches. "Copy as
/// Swift" puts the table on the clipboard, to paste over `Feel.standard`.
enum SpringTuner {
    typealias Tune = (response: Double, dampingRatio: Double)

    private static var table: [Feel: Tune] = Dictionary(uniqueKeysWithValues: Feel.allCases.map { feel in
        let d = UserDefaults.standard
        let r = d.object(forKey: key(feel, "response")) as? Double
        let z = d.object(forKey: key(feel, "damping")) as? Double
        return (feel, (r ?? feel.standard.response, z ?? feel.standard.dampingRatio))
    })

    static func value(for feel: Feel) -> Tune { table[feel] ?? feel.standard }

    static func set(_ feel: Feel, _ tune: Tune) {
        table[feel] = tune
        UserDefaults.standard.set(tune.response, forKey: key(feel, "response"))
        UserDefaults.standard.set(tune.dampingRatio, forKey: key(feel, "damping"))
    }

    private static func key(_ feel: Feel, _ part: String) -> String { "tune.\(feel.rawValue).\(part)" }

    static var swift: String {
        Feel.allCases.map { f in
            let t = value(for: f)
            return "        case .\(f.rawValue): (\(fmt(t.response)), \(fmt(t.dampingRatio)))"
        }.joined(separator: "\n")
    }

    static func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
}

extension Feel {
    var title: String {
        switch self {
        case .pop: "Pill pops out"
        case .width: "Pill width"
        case .fill: "Stroke fill"
        case .swell: "Swell"
        case .squash: "Squash on push"
        case .letterPop: "Letter pops in"
        case .letterSlide: "Letter slides"
        case .zSize: "z size"
        }
    }
}

@Observable @MainActor
final class SpringTunerModel {
    let indicator = IndicatorView(frame: NSRect(x: 0, y: 0, width: IndicatorView.size, height: IndicatorView.size))
    /// Bumped on every change so the sliders redraw.
    private(set) var revision = 0
    var looping = false { didSet { looping ? play() : () } }
    private var run: Task<Void, Never>?

    init() { indicator.corner = .topRight }

    func binding(_ feel: Feel, _ part: WritableKeyPath<Pair, Double>) -> Binding<Double> {
        Binding(
            get: { _ = self.revision; return Pair(SpringTuner.value(for: feel))[keyPath: part] },
            set: { v in
                var p = Pair(SpringTuner.value(for: feel))
                p[keyPath: part] = v
                SpringTuner.set(feel, (p.response, p.damping))
                self.revision += 1
            })
    }

    func isChanged(_ feel: Feel) -> Bool {
        _ = revision
        return Pair(SpringTuner.value(for: feel)) != Pair(feel.standard)
    }

    func reset(_ feel: Feel) { SpringTuner.set(feel, feel.standard); revision += 1 }
    func resetAll() { Feel.allCases.forEach { SpringTuner.set($0, $0.standard) }; revision += 1 }

    /// One nap: fills over 2.4 s with a few pushes, commits, then snaps away
    /// the way it does when the curtain covers it.
    func play() {
        run?.cancel()
        run = Task {
            repeat {
                indicator.reset()
                indicator.arm()
                for i in 0...60 {
                    indicator.setProgress(Double(i) / 60)
                    if i == 18 || i == 42 { indicator.kick(30, 22) }
                    try? await Task.sleep(for: .milliseconds(40))
                    if Task.isCancelled { return }
                }
                indicator.commit()
                try? await Task.sleep(for: .seconds(0.9))
                if Task.isCancelled { return }
                indicator.reset()
                try? await Task.sleep(for: .seconds(0.5))
            } while looping && !Task.isCancelled
        }
    }

    func push() { indicator.kick(40, 30) }

    func letGo() {
        run?.cancel()
        looping = false
        indicator.disarm()
    }

    struct Pair: Equatable {
        var response: Double
        var damping: Double
        init(_ t: SpringTuner.Tune) { response = t.response; damping = t.dampingRatio }
    }
}

final class SpringTunerWindow: NSWindow {
    @MainActor init(_ model: SpringTunerModel) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "Spring Tuner"
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: SpringTunerView(model: model))
        center()
    }
}

private struct SpringTunerView: View {
    let model: SpringTunerModel

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color(nsColor: Palette.light), Color(nsColor: Palette.accent).opacity(0.5)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Indicator(view: model.indicator)
                    .frame(width: IndicatorView.size, height: IndicatorView.size)
            }
            .frame(height: 130, alignment: .top)
            .clipped()

            HStack {
                Button(String("Play")) { model.play() }
                Toggle(isOn: Binding(get: { model.looping }, set: { model.looping = $0 })) { Text(verbatim: "Loop") }
                Button(String("Push")) { model.push() }
                Button(String("Let go")) { model.letGo() }
                Spacer()
                Button(String("Copy as Swift")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(SpringTuner.swift, forType: .string)
                }
                Button(String("Reset all")) { model.resetAll() }
            }
            .padding(12)

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text(verbatim: "")
                    Text(verbatim: "response (s) — lower is snappier").foregroundStyle(.secondary)
                    Text(verbatim: "damping — lower is bouncier").foregroundStyle(.secondary)
                    Text(verbatim: "")
                }
                .font(.caption)
                ForEach(Feel.allCases, id: \.self) { feel in
                    GridRow {
                        Text(verbatim: feel.title)
                            .fontWeight(model.isChanged(feel) ? .semibold : .regular)
                        Knob(value: model.binding(feel, \.response), range: 0.05...1.5)
                        Knob(value: model.binding(feel, \.damping), range: 0.1...1.5)
                        Button(String("↺")) { model.reset(feel) }
                            .buttonStyle(.borderless)
                            .disabled(!model.isChanged(feel))
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 640)
        .onAppear { model.looping = true }
    }
}

private struct Knob: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Slider(value: $value, in: range).frame(width: 170)
            Text(verbatim: SpringTuner.fmt(value)).monospacedDigit().frame(width: 34, alignment: .trailing)
        }
    }
}

private struct Indicator: NSViewRepresentable {
    let view: IndicatorView
    func makeNSView(context: Context) -> IndicatorView { view }
    func updateNSView(_ nsView: IndicatorView, context: Context) {}
}
#endif
