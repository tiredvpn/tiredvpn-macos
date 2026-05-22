import Foundation
import Security

/// Stores ServerConfig entries in the shared Keychain access group
/// `$(AppIdentifierPrefix)com.tiredvpn.macos.shared` so both the app and the
/// NE extension can read them. Active selection is mirrored to the App Group
/// UserDefaults so the extension can pick it up at startTunnel time.
@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var configs: [ServerConfig] = []
    @Published var activeID: UUID?

    private let service = "com.tiredvpn.macos.config"
    // The team prefix is resolved at runtime by Security framework when we pass
    // the raw string; the `$(AppIdentifierPrefix)` form is the literal that
    // Apple expects in the entitlements file. In API calls we pass the suffix.
    private let accessGroup = "com.tiredvpn.macos.shared"
    private let appGroup = "group.com.tiredvpn.macos"
    private let activeKey = "active_config_id"

    private init() {}

    // MARK: - Public API

    func load() {
        configs = readAll()
        if let defaults = UserDefaults(suiteName: appGroup),
           let s = defaults.string(forKey: activeKey),
           let id = UUID(uuidString: s) {
            activeID = id
        }
    }

    func save(_ config: ServerConfig) {
        if writeItem(config) {
            if let idx = configs.firstIndex(where: { $0.id == config.id }) {
                configs[idx] = config
            } else {
                configs.append(config)
            }
        }
    }

    func delete(id: UUID) {
        deleteItem(id: id)
        configs.removeAll { $0.id == id }
        if activeID == id {
            activeID = nil
            UserDefaults(suiteName: appGroup)?.removeObject(forKey: activeKey)
        }
    }

    func setActive(id: UUID) {
        activeID = id
        UserDefaults(suiteName: appGroup)?.set(id.uuidString, forKey: activeKey)
    }

    func active() -> ServerConfig? {
        guard let id = activeID else { return nil }
        return configs.first(where: { $0.id == id })
    }

    /// Import a TOML blob: parse, persist, and select as active.
    @discardableResult
    func importTOML(_ text: String) throws -> ServerConfig {
        let cfg = try ServerConfig.parse(toml: text)
        save(cfg)
        setActive(id: cfg.id)
        return cfg
    }

    // MARK: - Keychain

    private func baseQuery(account: String? = nil) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccessGroup as String: accessGroup,
        ]
        if let a = account { q[kSecAttrAccount as String] = a }
        return q
    }

    private func readAll() -> [ServerConfig] {
        var q = baseQuery()
        q[kSecMatchLimit as String] = kSecMatchLimitAll
        q[kSecReturnData as String] = true
        q[kSecReturnAttributes as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }
        let decoder = JSONDecoder()
        return items.compactMap { dict in
            guard let data = dict[kSecValueData as String] as? Data,
                  let cfg = try? decoder.decode(ServerConfig.self, from: data) else {
                return nil
            }
            return cfg
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    private func writeItem(_ config: ServerConfig) -> Bool {
        guard let data = try? JSONEncoder().encode(config) else { return false }
        let account = config.id.uuidString

        // Update if exists, else add.
        let updateStatus = SecItemUpdate(
            baseQuery(account: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        if updateStatus != errSecItemNotFound { return false }

        var add = baseQuery(account: account)
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func deleteItem(id: UUID) {
        let q = baseQuery(account: id.uuidString)
        SecItemDelete(q as CFDictionary)
    }
}
