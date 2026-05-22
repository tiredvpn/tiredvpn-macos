import SwiftUI

struct StatusView: View {
    @EnvironmentObject var tunnel: TunnelManager
    @EnvironmentObject var store: ConfigStore

    static let strategies = ["auto", "direct", "splithttps", "tlsfrag", "udpobfs"]

    @State private var strategyOverride: String = "auto"
    @State private var actionError: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 12)

            StatusPill(state: tunnel.state)
                .scaleEffect(1.1)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Server").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { store.activeID ?? store.configs.first?.id },
                        set: { newID in if let id = newID { store.setActive(id: id) } }
                    )) {
                        ForEach(store.configs) { cfg in
                            Text("\(cfg.name)  (\(cfg.server):\(cfg.port))").tag(Optional(cfg.id))
                        }
                        if store.configs.isEmpty {
                            Text("No configs").tag(Optional<UUID>(nil))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 280)
                }

                HStack {
                    Text("Strategy").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $strategyOverride) {
                        ForEach(Self.strategies, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 280)
                }
            }
            .padding(.horizontal, 24)

            Button(action: toggle) {
                Text(buttonTitle)
                    .font(.title3.weight(.semibold))
                    .frame(width: 220, height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(tunnel.state.isConnected ? .red : .accentColor)
            .disabled(store.active() == nil && !tunnel.state.isConnected)

            if let err = actionError {
                Text(err).font(.caption).foregroundColor(.red)
            }

            Spacer()
        }
        .padding()
    }

    private var buttonTitle: String {
        switch tunnel.state {
        case .connected, .connecting, .reasserting: return "Disconnect"
        case .disconnecting: return "Disconnecting…"
        default: return "Connect"
        }
    }

    private func toggle() {
        actionError = nil
        Task {
            if tunnel.state.isConnected || tunnel.state.isBusy {
                await tunnel.disconnect()
                return
            }
            guard let cfg = store.active() else {
                actionError = "Select a config first"
                return
            }
            do {
                try await tunnel.install(config: cfg, strategyOverride: strategyOverride)
                await tunnel.connect()
            } catch {
                actionError = error.localizedDescription
            }
        }
    }
}
