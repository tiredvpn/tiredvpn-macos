import Foundation
import NetworkExtension
import Combine

@MainActor
final class TunnelManager: ObservableObject {
    static let shared = TunnelManager()

    @Published var state: TunnelState = .disconnected
    @Published var lastLogLines: [String] = []

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    private var logSource: DispatchSourceFileSystemObject?
    private var logFD: Int32 = -1
    private var logOffset: UInt64 = 0
    private var darwinObserverRegistered = false

    // Strategy/latency we've parsed from the extension's published state.json.
    private var lastStrategy: String = "auto"
    private var lastLatency: Int?

    private let appGroup = "group.com.tiredvpn.macos"
    private let providerBundleID = "com.tiredvpn.macos.tunnel"
    private let logCap = 500
    private let darwinNotificationName = "com.tiredvpn.macos.state"

    private init() {
        startTailingLogFile()
        registerDarwinObserver()
    }

    // MARK: - Helpers

    static func appGroupURL() -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.tiredvpn.macos"
        )
    }

    // MARK: - Manager lifecycle

    func loadManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first {
                self.manager = existing
            } else {
                self.manager = NETunnelProviderManager()
            }
            observeStatus()
            updateStateFromConnection()
        } catch {
            state = .error("Failed to load VPN preferences: \(error.localizedDescription)")
        }
    }

    func install(config: ServerConfig, strategyOverride: String? = nil) async throws {
        if manager == nil { await loadManager() }
        guard let mgr = manager else {
            throw NSError(domain: "TiredVPN", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No tunnel manager"])
        }

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleID
        proto.serverAddress = "\(config.server):\(config.port)"

        let jsonData = try JSONEncoder().encode(config)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

        proto.providerConfiguration = [
            "config_json": jsonString,
            "strategy": strategyOverride ?? config.strategy,
        ]

        mgr.protocolConfiguration = proto
        mgr.localizedDescription = "TiredVPN — \(config.name)"
        mgr.isEnabled = true

        try await mgr.saveToPreferences()
        // Reload to pick up the saved config (NE requires this round-trip).
        try await mgr.loadFromPreferences()
    }

    func connect() async {
        guard let mgr = manager else {
            state = .error("Tunnel not installed")
            return
        }
        do {
            state = .connecting
            try mgr.connection.startVPNTunnel(options: nil)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func disconnect() async {
        guard let mgr = manager else { return }
        state = .disconnecting
        mgr.connection.stopVPNTunnel()
    }

    func removeManager() async {
        guard let mgr = manager else { return }
        do {
            try await mgr.removeFromPreferences()
            self.manager = nil
            state = .disconnected
        } catch {
            state = .error("Remove failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Provider messaging

    func sendCommand(_ json: [String: Any]) async throws -> [String: Any]? {
        guard let session = manager?.connection as? NETunnelProviderSession else {
            return nil
        }
        let data = try JSONSerialization.data(withJSONObject: json)
        return try await withCheckedThrowingContinuation { cont in
            do {
                try session.sendProviderMessage(data) { resp in
                    guard let resp, !resp.isEmpty else {
                        cont.resume(returning: nil); return
                    }
                    let obj = try? JSONSerialization.jsonObject(with: resp) as? [String: Any]
                    cont.resume(returning: obj)
                }
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    /// Convenience for the Go core's "port_hop" command.
    func portHop() async throws -> [String: Any]? {
        try await sendCommand(["cmd": "port_hop"])
    }

    /// Convenience for the Go core's "status" command.
    func queryStatus() async throws -> [String: Any]? {
        try await sendCommand(["cmd": "status"])
    }

    // MARK: - Status observation

    private func observeStatus() {
        guard let mgr = manager else { return }
        if let existing = statusObserver {
            NotificationCenter.default.removeObserver(existing)
        }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: mgr.connection,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateStateFromConnection() }
        }
    }

    private func updateStateFromConnection() {
        guard let mgr = manager else {
            state = .disconnected
            return
        }
        switch mgr.connection.status {
        case .invalid, .disconnected:
            state = .disconnected
        case .connecting:
            state = .connecting
        case .connected:
            state = .connected(strategy: lastStrategy, latencyMs: lastLatency)
        case .reasserting:
            state = .reasserting
        case .disconnecting:
            state = .disconnecting
        @unknown default:
            state = .disconnected
        }
    }

    // MARK: - Darwin notifications + state.json

    private func registerDarwinObserver() {
        if darwinObserverRegistered { return }
        darwinObserverRegistered = true

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let cb: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let me = Unmanaged<TunnelManager>.fromOpaque(observer).takeUnretainedValue()
            Task { @MainActor in me.readStateFile() }
        }
        CFNotificationCenterAddObserver(
            center,
            observer,
            cb,
            darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func readStateFile() {
        guard let url = Self.appGroupURL()?.appendingPathComponent("state.json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let strat = obj["strategy"] as? String {
            lastStrategy = strat
        }
        lastLatency = obj["latency_ms"] as? Int

        if let status = obj["state"] as? String {
            switch status {
            case "connected":
                state = .connected(strategy: lastStrategy, latencyMs: lastLatency)
            case "connecting":
                state = .connecting
            case "reasserting":
                state = .reasserting
            case "disconnecting":
                state = .disconnecting
            case "disconnected":
                state = .disconnected
            case "error":
                let msg = (obj["error"] as? String) ?? "unknown"
                state = .error(msg)
            default:
                updateStateFromConnection()
            }
        } else {
            updateStateFromConnection()
        }
    }

    // MARK: - Log tailing

    private func startTailingLogFile() {
        guard let groupURL = Self.appGroupURL() else { return }
        let logDir = groupURL.appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logURL = logDir.appendingPathComponent("tunnel.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        attachLogSource(url: logURL)
    }

    private func attachLogSource(url: URL) {
        let fd = open(url.path, O_RDONLY | O_EVTONLY)
        guard fd >= 0 else { return }
        self.logFD = fd

        // Seek to current EOF; we only stream new lines from now on.
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
        lseek(fd, off_t(size), SEEK_SET)
        logOffset = size

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.extend, .write, .delete, .rename],
            queue: .global(qos: .utility)
        )
        source.setEventHandler { [weak self] in
            self?.drainLog(url: url)
        }
        source.setCancelHandler { [weak self] in
            if let f = self?.logFD, f >= 0 { close(f) }
            self?.logFD = -1
        }
        source.resume()
        self.logSource = source
    }

    private func drainLog(url: URL) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: logOffset)
        } catch {
            // File was truncated/rotated; rewind.
            logOffset = 0
            try? handle.seek(toOffset: 0)
        }
        let data = handle.availableData
        guard !data.isEmpty else { return }
        logOffset += UInt64(data.count)
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        let lines = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        Task { @MainActor [lines] in
            for line in lines where !line.isEmpty {
                self.lastLogLines.append(line)
            }
            if self.lastLogLines.count > self.logCap {
                self.lastLogLines.removeFirst(self.lastLogLines.count - self.logCap)
            }
        }
    }
}
