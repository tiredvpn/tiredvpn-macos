import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tunnel: TunnelManager

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "—")
                Link("GitHub repository",
                     destination: URL(string: "https://github.com/tazhate/tiredvpn-macos")!)
            } header: {
                Text("About")
            }

            Section {
                Button(role: .destructive) {
                    Task { await tunnel.removeManager() }
                } label: {
                    Label("Uninstall VPN profile", systemImage: "trash")
                }
                Text("Removes the VPN configuration from System Settings. Your configs in Keychain are kept.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Maintenance")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
