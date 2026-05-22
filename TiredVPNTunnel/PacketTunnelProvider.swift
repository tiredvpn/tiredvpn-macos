import Foundation
import NetworkExtension
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = OSLog(subsystem: "com.tiredvpn.macos", category: "tunnel")

    // MARK: - startTunnel

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        os_log("startTunnel: begin (go=%{public}@)", log: log, type: .info, GoBridge.version)

        // a. Read provider configuration.
        guard
            let proto = self.protocolConfiguration as? NETunnelProviderProtocol,
            let providerConfig = proto.providerConfiguration
        else {
            os_log("startTunnel: missing providerConfiguration", log: log, type: .error)
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }

        guard let configJSON = providerConfig["config_json"] as? String else {
            os_log("startTunnel: config_json absent", log: log, type: .error)
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }
        let strategy = (providerConfig["strategy"] as? String) ?? "auto"

        // b. Network settings.
        // TODO: derive server address + local IP/peer IP from Go ConnectFn response.
        // For now we use the tunnel remoteAddress from the server hostname in the JSON
        // if extractable, else a sentinel. The 10.7.0.2/24 local IP is a placeholder.
        let remoteAddress = extractServerHost(fromConfigJSON: configJSON) ?? "0.0.0.0"
        os_log("startTunnel: using placeholder 10.7.0.2/24 — replace with Go ConnectFn response",
               log: log, type: .info)

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteAddress)

        let ipv4 = NEIPv4Settings(addresses: ["10.7.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4
        settings.ipv6Settings = nil

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings = dns
        settings.mtu = 1280

        // c. Apply settings, then proceed.
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                os_log("setTunnelNetworkSettings failed: %{public}@",
                       log: self.log, type: .error, String(describing: error))
                completionHandler(error)
                return
            }

            self.continueStart(
                configJSON: configJSON,
                strategy: strategy,
                completionHandler: completionHandler
            )
        }
    }

    private func continueStart(
        configJSON: String,
        strategy: String,
        completionHandler: @escaping (Error?) -> Void
    ) {
        // d. Extract utun fd via KVC (WireGuardKit-style).
        guard let fd = self.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 else {
            os_log("startTunnel: KVC socket.fileDescriptor returned nil — TODO: fallback to NEPacketTunnelFlow read/write API",
                   log: log, type: .fault)
            completionHandler(NEVPNError(.connectionFailed))
            return
        }
        os_log("startTunnel: got utun fd=%{public}d", log: log, type: .info, fd)

        // e. Install Go callbacks before anything that may call back.
        GoBridge.installCallbacks()

        // f. Hand fd to Go.
        GoBridge.setTunFd(fd)

        // g. Compose start JSON.
        // TODO: contract assumption — Go accepts a single JSON blob; we merge
        // macos_mode/strategy into the user's config_json object. If Go expects
        // a wrapper envelope, change here.
        let startJSON: String
        do {
            startJSON = try mergeStartJSON(configJSON: configJSON, strategy: strategy)
        } catch {
            os_log("startTunnel: merge JSON failed: %{public}@",
                   log: log, type: .error, String(describing: error))
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }

        let rc = GoBridge.start(json: startJSON)
        if rc != 0 {
            os_log("TiredvpnStart returned %{public}d", log: log, type: .error, rc)
            completionHandler(NSError(
                domain: "com.tiredvpn.macos",
                code: Int(rc),
                userInfo: [NSLocalizedDescriptionKey: "TiredvpnStart rc=\(rc)"]
            ))
            return
        }

        // h. Done.
        os_log("startTunnel: ok", log: log, type: .info)
        completionHandler(nil)
    }

    // MARK: - stopTunnel

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        os_log("stopTunnel: reason=%{public}d", log: log, type: .info, reason.rawValue)

        GoBridge.stop()

        // Give Go ~500ms to drain reader/writer goroutines, close fd, flush logs.
        // Calling completionHandler immediately can race with in-flight callbacks.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completionHandler()
        }
    }

    // MARK: - handleAppMessage

    override func handleAppMessage(
        _ messageData: Data,
        completionHandler: ((Data?) -> Void)?
    ) {
        guard let json = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        let response = GoBridge.sendCommand(json)
        let respData = response.flatMap { $0.data(using: .utf8) }
        completionHandler?(respData)
    }

    // MARK: - sleep / wake

    override func sleep(completionHandler: @escaping () -> Void) {
        os_log("sleep", log: log, type: .info)
        // No-op for now.
        completionHandler()
    }

    override func wake() {
        os_log("wake", log: log, type: .info)
        // No-op for now.
    }

    // MARK: - helpers

    /// Merges `macos_mode` and `strategy` into the user's config JSON.
    /// Assumes `configJSON` is a JSON object.
    private func mergeStartJSON(configJSON: String, strategy: String) throws -> String {
        guard let data = configJSON.data(using: .utf8) else {
            throw NSError(domain: "com.tiredvpn.macos", code: -1)
        }
        var obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        obj["macos_mode"] = true
        obj["strategy"] = strategy
        let merged = try JSONSerialization.data(withJSONObject: obj, options: [])
        guard let str = String(data: merged, encoding: .utf8) else {
            throw NSError(domain: "com.tiredvpn.macos", code: -2)
        }
        return str
    }

    /// Best-effort extraction of "server" field from config JSON for tunnelRemoteAddress.
    private func extractServerHost(fromConfigJSON json: String) -> String? {
        guard
            let data = json.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let s = obj["server"] as? String { return s }
        return nil
    }
}
