import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tunnel: TunnelManager

    var body: some View {
        Form {
            Section {
                LabeledContent("Launch at login") {
                    Toggle("", isOn: .constant(false)).labelsHidden()
                }
                LabeledContent("Show in menu bar") {
                    Toggle("", isOn: .constant(true)).labelsHidden()
                }
            } header: {
                Text("General")
                    .font(.tvLabel)
                    .foregroundStyle(Color.tvTextSecondary)
            }

            Section {
                LabeledContent("Auto-reconnect") {
                    Toggle("", isOn: .constant(true)).labelsHidden()
                }
                VStack(alignment: .leading, spacing: 2) {
                    LabeledContent("Kill switch") {
                        Toggle("", isOn: .constant(false)).labelsHidden()
                    }
                    Text("Block all traffic if VPN drops")
                        .font(.tvCaption)
                        .foregroundStyle(Color.tvTextSecondary)
                }
            } header: {
                Text("Connection")
                    .font(.tvLabel)
                    .foregroundStyle(Color.tvTextSecondary)
            }

            Section {
                Button(role: .destructive) {
                    Task { await tunnel.removeManager() }
                } label: {
                    Label("Uninstall VPN profile", systemImage: "trash")
                }
                Text("Removes the VPN configuration from System Settings. Keychain configs are kept.")
                    .font(.tvCaption)
                    .foregroundStyle(Color.tvTextSecondary)
            } header: {
                Text("Advanced")
                    .font(.tvLabel)
                    .foregroundStyle(Color.tvTextSecondary)
            }
        }
        .formStyle(.grouped)
    }
}
