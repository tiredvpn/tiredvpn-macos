import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Home", systemImage: "house") }
            ConfigsView()
                .tabItem { Label("Configs", systemImage: "list.bullet.rectangle") }
            LogView()
                .tabItem { Label("Logs", systemImage: "doc.plaintext") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .padding(.top, 8)
    }
}
