import Foundation

enum AppGroup {
    static let identifier = "group.com.tiredvpn.macos"

    /// Shared container URL. Force-unwrapped: missing entitlement is a build/config error,
    /// not a runtime condition we can recover from.
    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier
        ) else {
            fatalError("App Group container missing: \(identifier). Check entitlements.")
        }
        return url
    }

    static var stateFileURL: URL {
        containerURL.appendingPathComponent("state.json")
    }

    static var logsDirURL: URL {
        containerURL.appendingPathComponent("logs", isDirectory: true)
    }

    static var logFileURL: URL {
        logsDirURL.appendingPathComponent("tunnel.log")
    }

    static var logBackupURL: URL {
        logsDirURL.appendingPathComponent("tunnel.log.1")
    }

    static var droppedCountURL: URL {
        logsDirURL.appendingPathComponent("dropped.count")
    }

    static let stateNotificationName = "com.tiredvpn.macos.state"
}
