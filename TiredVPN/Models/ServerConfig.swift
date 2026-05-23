import Foundation
import TOMLKit

/// User-facing config record stored in Keychain. Maps to `internal/config/toml.ClientConfig`
/// in tiredvpn-oss. Held separately from `client.Config` (the Go runtime struct) — see
/// `TunnelManager.install` for the translation step.
struct ServerConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var server: String      // [server].address
    var port: Int           // [server].port
    var strategy: String    // [strategy].mode
    var serverName: String? // [tls].server_name (SNI override)
    var raw: String         // original TOML, kept for round-trip + export

    init(id: UUID = UUID(),
         name: String,
         server: String,
         port: Int,
         strategy: String,
         serverName: String? = nil,
         raw: String) {
        self.id = id
        self.name = name
        self.server = server
        self.port = port
        self.strategy = strategy
        self.serverName = serverName
        self.raw = raw
    }

    /// Parse TOML matching `internal/config/toml.ClientConfig`:
    ///
    ///   [server]
    ///   address = "..."
    ///   port    = 995
    ///
    ///   [strategy]
    ///   mode = "auto"
    ///
    ///   [tls]
    ///   server_name = "..."  # optional
    ///
    /// A top-level `name = "..."` is accepted as a human label.
    static func parse(toml text: String) throws -> ServerConfig {
        let table = try TOMLTable(string: text)

        guard let serverTable = table["server"]?.table else {
            throw ConfigParseError.missing("[server]")
        }
        guard let address = serverTable["address"]?.string, !address.isEmpty else {
            throw ConfigParseError.missing("server.address")
        }
        guard let port = serverTable["port"]?.int else {
            throw ConfigParseError.missing("server.port")
        }

        let strategyMode = table["strategy"]?.table?["mode"]?.string ?? "auto"
        let sni = table["tls"]?.table?["server_name"]?.string
        let name = table["name"]?.string ?? "\(address):\(port)"

        return ServerConfig(
            name: name,
            server: address,
            port: port,
            strategy: strategyMode,
            serverName: sni,
            raw: text
        )
    }
}

enum ConfigParseError: LocalizedError {
    case missing(String)
    case invalidBase64
    case invalidUTF8

    var errorDescription: String? {
        switch self {
        case .missing(let key): return "Missing required field: \(key)"
        case .invalidBase64: return "Payload is not valid base64"
        case .invalidUTF8: return "Decoded payload is not valid UTF-8"
        }
    }
}
