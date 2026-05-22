import Foundation
import TOMLKit

struct ServerConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var server: String
    var port: Int
    var strategy: String
    var psk: String?
    var raw: String

    init(id: UUID = UUID(),
         name: String,
         server: String,
         port: Int,
         strategy: String,
         psk: String? = nil,
         raw: String) {
        self.id = id
        self.name = name
        self.server = server
        self.port = port
        self.strategy = strategy
        self.psk = psk
        self.raw = raw
    }

    /// Parse a TOML string into a ServerConfig.
    ///
    /// Schema mirrors `internal/config` from the Go core. The TOML may either be
    /// flat or nested under `[server]`; we accept both for forward-compat with
    /// the Go-side config formats.
    static func parse(toml text: String) throws -> ServerConfig {
        let table = try TOMLTable(string: text)

        let serverTable: TOMLTable = {
            if let nested = table["server"]?.table { return nested }
            return table
        }()

        guard let host = serverTable["server"]?.string ?? serverTable["host"]?.string,
              !host.isEmpty else {
            throw ConfigParseError.missing("server")
        }
        guard let port = serverTable["port"]?.int else {
            throw ConfigParseError.missing("port")
        }
        let strategy = serverTable["strategy"]?.string ?? "auto"
        let psk = serverTable["psk"]?.string ?? serverTable["preshared_key"]?.string
        let name = serverTable["name"]?.string ?? "\(host):\(port)"

        return ServerConfig(
            name: name,
            server: host,
            port: port,
            strategy: strategy,
            psk: psk,
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
