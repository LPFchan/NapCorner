import AppKit
import SwiftUI

/// First-launch window: what NapCorner does (with the real indicator in a
/// demo), which corner to use (and switching macOS's own hot corner off
/// there), then where NapCorner lives and whether it opens at login.
/// NapCorner needs no permissions, so there are no permission steps.
@MainActor @Observable
final class Onboarding {
    enum Step: Int, CaseIterable { case welcome, corner, done }

    var step: Step = .welcome
    var corners = Preferences.corners
    var openAtLogin = true
    @ObservationIgnored var onCorners: (Set<Corner>) -> Void = { _ in }
    @ObservationIgnored var onFinish: (_ completed: Bool) -> Void = { _ in }
}

final class OnboardingWindow: NSWindow, NSWindowDelegate {
    private let onboarding: Onboarding

    @MainActor init(_ onboarding: Onboarding) {
        self.onboarding = onboarding
        super.init(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                   backing: .buffered, defer: false)
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        delegate = self
        contentView = NSHostingView(rootView: OnboardingView(onboarding: onboarding))
        center()
    }

    // Closing early counts as done for showing it at launch; the menu bar
    // still has Settings.
    func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated { onboarding.onFinish(false) }
    }
}

private let accent = Color(nsColor: Palette.accent)

private struct OnboardingView: View {
    @Bindable var onboarding: Onboarding

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch onboarding.step {
                case .welcome: WelcomeStep()
                case .corner: CornerStep(corners: $onboarding.corners)
                case .done: DoneStep(openAtLogin: $onboarding.openAtLogin)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 52)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .id(onboarding.step)

            primaryButton
            HStack(spacing: 8) {
                ForEach(Onboarding.Step.allCases, id: \.self) { step in
                    Circle().fill(step == onboarding.step ? accent : .secondary.opacity(0.3)).frame(width: 7, height: 7)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 26)
        }
        .frame(width: 640, height: 600)
        .background {
            LinearGradient(colors: [accent.opacity(0.2), accent.opacity(0.03)], startPoint: .top, endPoint: .bottom)
                .background(.background)
                .ignoresSafeArea()
        }
        .animation(.spring(duration: 0.45), value: onboarding.step)
    }

    @ViewBuilder private var primaryButton: some View {
        switch onboarding.step {
        case .welcome:
            PrimaryButton("Get Started") { onboarding.step = .corner }
        case .corner:
            PrimaryButton("Continue") {
                Preferences.corners = onboarding.corners
                HotCorners.clear(onboarding.corners)
                onboarding.onCorners(onboarding.corners)
                onboarding.step = .done
            }
            .disabled(onboarding.corners.isEmpty)
        case .done:
            PrimaryButton("Done") { onboarding.onFinish(true) }
        }
    }
}

private struct PrimaryButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    @Environment(\.isEnabled) private var enabled
    init(_ title: LocalizedStringKey, action: @escaping () -> Void) { self.title = title; self.action = action }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 16)
                .frame(width: 300, height: 48)
                .background(accent.opacity(enabled ? 1 : 0.45), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }
}

private struct Header: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 10) {
            Text(title).font(.system(size: 30, weight: .bold)).multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 480)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 22) {
            Header(title: "Welcome to NapCorner",
                   subtitle: "Put your display to sleep from a screen corner, without the accidental naps or the instant wake-ups.")
            NapDemo()
            Text("Rest the pointer in the corner, or push into it, until the pill’s outline fills. Once the screen is dark, small bumps of the mouse won’t wake it.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CornerStep: View {
    @Binding var corners: Set<Corner>

    var body: some View {
        VStack(spacing: 26) {
            Header(title: "Pick your corner",
                   subtitle: "NapCorner takes over from macOS’s Put Display to Sleep hot corner.")
            CornerPicker(corners: $corners)
            Group {
                if corners.isEmpty {
                    Text("Choose at least one corner.")
                } else if corners.contains(where: HotCorners.isUsed) {
                    Text("macOS has its own hot corner there. NapCorner turns it off, so the two don’t both fire.")
                } else {
                    Text(verbatim: " ")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)
        }
    }
}

private struct DoneStep: View {
    @Binding var openAtLogin: Bool

    var body: some View {
        VStack(spacing: 26) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            Header(title: "You’re all set",
                   subtitle: "Try it now: move the pointer into your corner and rest it there.")
            HStack(spacing: 10) {
                Image(nsImage: MenuBarGlyph.image(dimmed: false))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.secondary.opacity(0.15), in: .rect(cornerRadius: 6))
                Text("NapCorner lives in the menu bar. Click it to change the corner or how long to hold.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 440)
            Toggle("Open NapCorner when I log in", isOn: $openAtLogin)
                .toggleStyle(.switch)
                .tint(accent)
                .font(.system(size: 14, weight: .medium))
        }
    }
}
