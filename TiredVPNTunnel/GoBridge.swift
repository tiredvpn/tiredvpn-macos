import Foundation
import os.log

// MARK: - C callbacks
//
// These must be top-level `@convention(c)` functions so they have a stable C
// calling convention and can be passed as function pointers to Go. They may be
// invoked from arbitrary Go runtime threads — keep them re-entrant and non-blocking.

private let bridgeLog = OSLog(subsystem: "com.tiredvpn.macos", category: "bridge")

@_cdecl("tiredvpn_swift_state_cb")
fileprivate func goStateCB(_ cStr: UnsafePointer<CChar>?) {
    guard let cStr = cStr else { return }
    let s = String(cString: cStr)
    SharedState.publishState(s)
}

@_cdecl("tiredvpn_swift_log_cb")
fileprivate func goLogCB(_ level: Int32, _ cStr: UnsafePointer<CChar>?) {
    guard let cStr = cStr else { return }
    let s = String(cString: cStr)
    LogBuffer.shared.append(level: level, msg: s)
}

// MARK: - GoBridge

enum GoBridge {
    /// Installs C callbacks into the Go runtime. Call once per process.
    static func installCallbacks() {
        TiredvpnSetCallbacks(goStateCB, goLogCB)
        os_log("GoBridge: callbacks installed", log: bridgeLog, type: .info)
    }

    /// Start the Go tunnel. JSON is fully owned by Swift for the duration of the call.
    @discardableResult
    static func start(json: String) -> Int32 {
        return json.withCString { TiredvpnStart($0) }
    }

    static func stop() {
        TiredvpnStop()
    }

    static func setTunFd(_ fd: Int32) {
        TiredvpnSetTunFd(fd)
    }

    /// Sends a JSON command synchronously. Returned C string is allocated by Go;
    /// we copy it into a Swift String and free the C buffer via `TiredvpnFreeString`.
    static func sendCommand(_ json: String) -> String? {
        return json.withCString { cIn -> String? in
            guard let cOut = TiredvpnSendCommand(cIn) else { return nil }
            defer { TiredvpnFreeString(cOut) }
            return String(cString: cOut)
        }
    }

    /// Version string is a `const char*` literal owned by Go — do NOT free.
    static var version: String {
        guard let cPtr = TiredvpnVersion() else { return "unknown" }
        return String(cString: cPtr)
    }
}
