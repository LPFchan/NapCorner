import AppKit
import SwiftUI

/// Corners, how long to hold or how hard to push, and how long the mouse is
/// ignored after the displays go to sleep. Changes apply at once.
@MainActor @Observable
final class SettingsModel {
    var corners = Preferences.corners {
        didSet { Preferences.corners = corners; onCorners(corners); refreshConflicts() }
    }
    var holdSeconds = Preferences.holdSeconds { didSet { Preferences.holdSeconds = holdSeconds } }
    /// 0 is light (little push needed), 1 is firm.
    var firmness = (Preferences.pushDistance - Preferences.pushRange.lowerBound)
        / (Preferences.pushRange.upperBound - Preferences.pushRange.lowerBound) {
        didSet {
            Preferences.pushDistance = Preferences.pushRange.lowerBound
                + firmness * (Preferences.pushRange.upperBound - Preferences.pushRange.lowerBound)
        }
    }
    var guardSeconds = Preferences.guardSeconds { didSet { Preferences.guardSeconds = guardSeconds } }
    var openAtLogin = LaunchAtLogin.isEnabled { didSet { LaunchAtLogin.set(openAtLogin) } }
    private(set) var conflicts: Set<Corner> = []
    @ObservationIgnored var onCorners: (Set<Corner>) -> Void = { _ in }

    init() { refreshConflicts() }

    func refreshConflicts() { conflicts = corners.filter(HotCorners.isUsed) }

    func clearConflicts() {
        HotCorners.clear(conflicts)
        refreshConflicts()
    }
}

final class SettingsWindow: NSWindow {
    @MainActor init(_ model: SettingsModel) {
        super.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = String(localized: "NapCorner Settings")
        isReleasedWhenClosed = false
        contentView = NSHostingView(rootView: SettingsView(model: model))
        center()
    }
}

private struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    CornerPicker(corners: $model.corners)
                    if !model.conflicts.isEmpty {
                        HStack {
                            Text("macOS has its own hot corner there too.")
                                .foregroundStyle(.secondary)
                            Button("Turn Off in macOS") { model.clearConflicts() }
                        }
                        .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } header: {
                Text("Corners")
            }

            Section {
                LabeledContent {
                    Slider(value: $model.holdSeconds, in: Preferences.holdRange, step: 0.25)
                } label: {
                    Text("Hold for")
                    Text(seconds(model.holdSeconds))
                }
                LabeledContent {
                    Slider(value: $model.firmness, in: 0...1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Text("Light")
                    } maximumValueLabel: {
                        Text("Firm")
                    }
                } label: {
                    Text("Or push")
                }
            } header: {
                Text("Going to sleep")
            } footer: {
                Text("Rest the pointer in the corner, or push the mouse into it, until the pill’s outline fills.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent {
                    Slider(value: $model.guardSeconds, in: Preferences.guardRange, step: 0.25)
                } label: {
                    Text("Ignore the mouse for")
                    Text(model.guardSeconds == 0 ? String(localized: "Off") : seconds(model.guardSeconds))
                }
            } header: {
                Text("Staying asleep")
            } footer: {
                Text("Bumping the mouse this soon after the screen goes dark won’t wake it. A key press or a click always does.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open at Login", isOn: $model.openAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
        .tint(Color(nsColor: Palette.accent))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshConflicts()
        }
    }

    private func seconds(_ s: Double) -> String {
        Measurement(value: s, unit: UnitDuration.seconds)
            .formatted(.measurement(width: .abbreviated, numberFormatStyle: .number.precision(.fractionLength(0...2))))
    }
}
