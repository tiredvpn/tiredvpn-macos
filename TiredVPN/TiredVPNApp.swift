import SwiftUI

@main
struct TiredVPNApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Eagerly instantiate singletons so the menu bar reflects state immediately.
    @StateObject private var tunnel = TunnelManager.shared
    @StateObject private var store = ConfigStore.shared

    var body: some Scene {
        WindowGroup("TiredVPN") {
            ContentView()
                .environmentObject(tunnel)
                .environmentObject(store)
                .frame(minWidth: 680, minHeight: 480)
                .onAppear {
                    Task {
                        await tunnel.loadManager()
                        store.load()
                    }
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
