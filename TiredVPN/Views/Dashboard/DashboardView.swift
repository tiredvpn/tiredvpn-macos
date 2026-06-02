import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var tunnel: TunnelManager
    @EnvironmentObject var store: ConfigStore

    static let strategies = ["auto", "direct", "splithttps", "tlsfrag", "udpobfs"]

    @State private var strategyOverride = "auto"
    @State private var actionError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            slothImage
                .frame(width: 180, height: 180)
                .animation(.easeInOut(duration: 0.4), value: tunnel.state.isConnected)

            Text(statusTitle)
                .font(.tvTitle)
                .foregroundStyle(Color.tvText)
                .padding(.top, 20)

            if let sub = statusSubtitle {
                Text(sub)
                    .font(.tvBody)
                    .foregroundStyle(Color.tvTextSecondary)
                    .padding(.top, 4)
            }

            VStack(spacing: 10) {
                serverPicker
                strategyPicker
            }
            .padding(.horizontal, 48)
            .padding(.top, 24)

            connectButton
                .padding(.top, 24)

            if let err = actionError {
                Text(err)
                    .font(.tvCaption)
                    .foregroundStyle(Color.tvError)
                    .padding(.top, 8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var slothImage: some View {
        if tunnel.state.isConnected {
            Image("sloth_connected")
                .resizable()
                .scaledToFit()
        } else {
            Image("sloth_disconnected")
                .resizable()
                .scaledToFit()
        }
    }

    private var statusTitle: String {
        switch tunnel.state {
        case .disconnected:              return "Not connected"
        case .connecting:                return "Connecting..."
        case .connected(let s, _):       return "Connected - \(s)"
        case .reasserting:               return "Reconnecting..."
        case .disconnecting:             return "Disconnecting..."
        case .error(let m):              return "Error: \(m)"
        }
    }

    private var statusSubtitle: String? {
        if case .connected(_, let lat) = tunnel.state, let ms = lat {
            return "\(ms) ms"
        }
        if case .disconnected = tunnel.state {
            return "Select a server and press Connect"
        }
        return nil
    }

    private var serverPicker: some View {
        HStack {
            Text("Server")
                .font(.tvCaption)
                .foregroundStyle(Color.tvTextSecondary)
            Spacer()
            Picker("", selection: Binding(
                get: { store.activeID ?? store.configs.first?.id },
                set: { if let id = $0 { store.setActive(id: id) } }
            )) {
                ForEach(store.configs) { cfg in
                    Text("\(cfg.name)  (\(cfg.server):\(cfg.port))").tag(Optional(cfg.id))
                }
                if store.configs.isEmpty {
                    Text("No configs").tag(Optional<UUID>(nil))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 240)
        }
    }

    private var strategyPicker: some View {
        HStack {
            Text("Strategy")
                .font(.tvCaption)
                .foregroundStyle(Color.tvTextSecondary)
            Spacer()
            Picker("", selection: $strategyOverride) {
                ForEach(Self.strategies, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .frame(maxWidth: 240)
        }
    }

    private var connectButton: some View {
        Button(action: toggle) {
            Text(buttonTitle)
                .font(.tvSubtitle)
                .foregroundStyle(buttonTextColor)
                .frame(width: 200, height: 48)
                .background(Capsule().fill(buttonColor))
        }
        .buttonStyle(.plain)
        .disabled(store.active() == nil && !tunnel.state.isConnected)
    }

    private var buttonTitle: String {
        switch tunnel.state {
        case .connected, .connecting, .reasserting: return "Disconnect"
        case .disconnecting: return "Disconnecting..."
        default: return "Connect"
        }
    }

    private var buttonColor: Color {
        if tunnel.state.isConnected { return Color.tvError }
        if tunnel.state.isBusy      { return Color.tvTextSecondary.opacity(0.3) }
        return Color.tvPrimary
    }

    private var buttonTextColor: Color {
        if tunnel.state.isConnected || tunnel.state.isBusy { return Color.tvText }
        return Color.tvTextOnPrimary
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
