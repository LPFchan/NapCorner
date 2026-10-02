import SwiftUI

@main
struct NapCornerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu-bar-only app; its windows are opened by the AppDelegate.
        Settings { EmptyView() }
    }
}
