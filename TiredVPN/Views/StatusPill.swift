import SwiftUI

struct StatusPill: View {
    let state: TunnelState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: Self.symbol(for: state))
                .imageScale(.medium)
            Text(label(for: state))
                .font(.headline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Self.color(for: state).opacity(0.18))
        )
        .overlay(
            Capsule().stroke(Self.color(for: state), lineWidth: 1.5)
        )
        .foregroundColor(Self.color(for: state))
    }

    private func label(for state: TunnelState) -> String {
        switch state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected(let s, let lat):
            if let lat { return "Connected · \(s) · \(lat)ms" }
            return "Connected · \(s)"
        case .reasserting: return "Reasserting…"
        case .disconnecting: return "Disconnecting…"
        case .error(let m): return "Error: \(m)"
        }
    }

    static func symbol(for state: TunnelState) -> String {
        switch state {
        case .connected: return "lock.shield.fill"
        case .connecting, .reasserting, .disconnecting: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.shield"
        case .disconnected: return "lock.open"
        }
    }

    static func color(for state: TunnelState) -> Color {
        switch state {
        case .connected: return .green
        case .connecting, .reasserting: return .orange
        case .disconnecting: return .yellow
        case .error: return .red
        case .disconnected: return .secondary
        }
    }
}
