import Foundation

enum TunnelState: Equatable {
    case disconnected
    case connecting
    case connected(strategy: String, latencyMs: Int?)
    case reasserting
    case disconnecting
    case error(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isBusy: Bool {
        switch self {
        case .connecting, .reasserting, .disconnecting: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .reasserting: return "Reasserting"
        case .disconnecting: return "Disconnecting"
        case .error: return "Error"
        }
    }
}
