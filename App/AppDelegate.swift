import AppKit
import Sparkle
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let nap = NapController()
    private var statusItem: NSStatusItem?
    private var onboardingWindow: OnboardingWindow?
    private var settingsWindow: SettingsWindow?
    #if DEBUG
    private var tunerWindow: SpringTunerWindow?
    #endif
    // Debug builds report version 0.0.0, so a running updater would find the
    // release and, with automatic installs on, swap the build out on quit.
    #if DEBUG
    private let updatesEnabled = false
    #else
    private let updatesEnabled = true
    #endif
    private lazy var updater = SPUStandardUpdaterController(
        startingUpdater: updatesEnabled, updaterDelegate: nil, userDriverDelegate: self)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Sparkle's own schedule skips the first launch; check on every
        // launch too, as Sparkle advises.
        if updatesEnabled, updater.updater.automaticallyChecksForUpdates {
            updater.updater.checkForUpdatesInBackground()
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.menu = NSMenu()
        statusItem?.menu?.delegate = self
        updateIcon()
        #if DEBUG
        if CommandLine.arguments.contains("--preview-indicator") { nap.previewIndicator(); return }
        if CommandLine.arguments.contains("--tune") { showTuner() }
        #endif
        if Preferences.enabled { nap.start() }
        Log.write("[App] launch \(Bundle.main.shortVersion) corners=\(nap.corners.map(\.rawValue).sorted())")
        // `--onboarding` shows the first-launch window again, for testing.
        if CommandLine.arguments.contains("--onboarding") || !UserDefaults.standard.bool(forKey: "onboarded") {
            showOnboarding()
        }
    }

    // MARK: - Windows

    private func showOnboarding() {
        let onboarding = Onboarding()
        onboarding.onCorners = { [weak self] corners in self?.nap.corners = corners }
        onboarding.onFinish = { [weak self] completed in
            guard let self, let window = self.onboardingWindow else { return }
            self.onboardingWindow = nil
            UserDefaults.standard.set(true, forKey: "onboarded")
            // Only a finished walkthrough applies the login choice.
            if completed { LaunchAtLogin.set(onboarding.openAtLogin) }
            window.close()
        }
        let window = OnboardingWindow(onboarding)
        onboardingWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let model = SettingsModel()
            model.onCorners = { [weak self] corners in self?.nap.corners = corners }
            settingsWindow = SettingsWindow(model)
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    #if DEBUG
    @objc private func showTuner() {
        if tunerWindow == nil { tunerWindow = SpringTunerWindow(SpringTunerModel()) }
        NSApp.activate()
        tunerWindow?.makeKeyAndOrderFront(nil)
    }
    #endif

    private func updateIcon() {
        statusItem?.button?.image = MenuBarGlyph.image(dimmed: !Preferences.enabled)
        statusItem?.button?.setAccessibilityLabel("NapCorner")
    }

    @objc private func toggleEnabled() {
        Preferences.enabled.toggle()
        Preferences.enabled ? nap.start() : nap.stop()
        updateIcon()
    }

    @objc private func toggleLogin() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    @objc private func clearHotCorners() {
        HotCorners.clear(nap.corners)
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    // Rebuilt on every open, so it shows the current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        // macOS's own hot corner on a NapCorner corner would sleep the
        // display straight away, before NapCorner gets a say.
        if Preferences.enabled, nap.corners.contains(where: HotCorners.isUsed) {
            menu.addItem(NSMenuItem(title: String(localized: "macOS has its own hot corner there too"),
                                    action: nil, keyEquivalent: ""))
            let fix = NSMenuItem(title: String(localized: "Turn Off in macOS"),
                                 action: #selector(clearHotCorners), keyEquivalent: "")
            fix.target = self
            menu.addItem(fix)
            menu.addItem(.separator())
        }
        let enabled = NSMenuItem(title: String(localized: "Enabled"), action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabled.state = Preferences.enabled ? .on : .off
        menu.addItem(enabled)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: String(localized: "Settings…"), action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let login = NSMenuItem(title: String(localized: "Open at Login"), action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)
        let update = NSMenuItem(title: String(localized: "Check for Updates…"),
                                action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        update.target = updater
        menu.addItem(update)
        let about = NSMenuItem(title: String(localized: "About NapCorner"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        #if DEBUG
        let tuner = NSMenuItem(title: String("Spring Tuner…"), action: #selector(showTuner), keyEquivalent: "")
        tuner.target = self
        menu.addItem(tuner)
        #endif
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit NapCorner"),
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}

extension AppDelegate: @preconcurrency SPUStandardUserDriverDelegate {
    // A menu bar app is never the active app, so Sparkle would leave an update
    // it found waiting behind other windows. Bring it to the front instead.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        guard !handleShowingUpdate else { return }
        DispatchQueue.main.async { [self] in
            NSApp.activate()
            updater.checkForUpdates(nil)
        }
    }
}

extension Bundle {
    var shortVersion: String { infoDictionary?["CFBundleShortVersionString"] as? String ?? "?" }
}
