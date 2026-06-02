import SwiftUI

struct ContentView: View {
    @State private var selection: NavItem = .dashboard

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
        } detail: {
            Group {
                switch selection {
                case .dashboard: DashboardView()
                case .servers:   ServersView()
                case .settings:  SettingsView()
                case .about:     AboutView()
                }
            }
            .background(Color.tvBackground)
        }
        .navigationSplitViewStyle(.balanced)
    }
}
