import Foundation
import os.log

/// Bridges Go's state callback into the App Group + a Darwin notification so the
/// main app can refresh without polling.
///
/// Go calls back with `(state, json_data)`. We compose an envelope:
///   { "state": <state>, "data": <parsed-json or raw-string> }
/// and write it atomically to `<AppGroup>/state.json`.
enum SharedState {
    private static let log = OSLog(subsystem: "com.tiredvpn.macos", category: "tunnel")

    static func publishState(state: String, payload: String) {
        var envelope: [String: Any] = ["state": state, "ts": Date().timeIntervalSince1970]
        if let pdata = payload.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: pdata) {
            envelope["data"] = parsed
        } else {
            envelope["data"] = payload
        }

        let url = AppGroup.stateFileURL
        do {
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: envelope, options: [])
            try data.write(to: url, options: [.atomic])
        } catch {
            os_log("publishState write failed: %{public}@",
                   log: log, type: .error, String(describing: error))
            return
        }

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(AppGroup.stateNotificationName as CFString),
            nil, nil, true
        )
    }
}
