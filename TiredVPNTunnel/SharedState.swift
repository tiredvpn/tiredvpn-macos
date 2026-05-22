import Foundation
import os.log

/// Publishes tunnel state JSON to the App Group and notifies the main app
/// via a Darwin notification so it can refresh without polling.
enum SharedState {
    private static let log = OSLog(subsystem: "com.tiredvpn.macos", category: "tunnel")

    /// Writes JSON state atomically to `<AppGroup>/state.json` and posts a Darwin notification.
    /// Safe to call from any thread (including Go runtime threads via callbacks).
    static func publishState(_ json: String) {
        let url = AppGroup.stateFileURL
        let data = Data(json.utf8)

        do {
            // Ensure parent dir exists (it should, but defensive).
            let dir = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        } catch {
            os_log("publishState write failed: %{public}@", log: log, type: .error, String(describing: error))
            return
        }

        postDarwinNotification()
    }

    private static func postDarwinNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(AppGroup.stateNotificationName as CFString)
        CFNotificationCenterPostNotification(
            center,
            name,
            nil,
            nil,
            true // deliverImmediately
        )
    }
}
