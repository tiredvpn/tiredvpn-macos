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
        // config_json is already in client.Config shape (ServerAddr, StrategyName,
        // MacOSMode=true). TunFd is set separately via TiredvpnSetTunFd.

        // b. Network settings.
        // TODO: derive local IP / peer IP / DNS / MTU from Go ConnectFn response.
        // Placeholder values for now — server-side handshake will eventually
        // provide these via state callback or a separate query.
        let remoteAddress = extractServerAddr(fromConfigJSON: configJSON) ?? "0.0.0.0"
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
                completionHandler: completionHandler
            )
        }
    }

    private func continueStart(
        configJSON: String,
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

        // g. config_json is already a fully-formed client.Config JSON; pass through.
        let rc = GoBridge.start(json: configJSON)
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

    /// Pulls the host portion out of client.Config.ServerAddr ("host:port") for
    /// `tunnelRemoteAddress`. NE just uses this as a routing hint; format errors
    /// degrade to "0.0.0.0".
    private func extractServerAddr(fromConfigJSON json: String) -> String? {
        guard
            let data = json.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let addr = obj["ServerAddr"] as? String
        else { return nil }
        // Strip port: "host:443" → "host", "[::1]:443" → "[::1]".
        if let colon = addr.lastIndex(of: ":") {
            return String(addr[..<colon])
        }
        return addr
    }
}
