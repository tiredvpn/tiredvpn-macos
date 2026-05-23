import Foundation
import os.log

// C ABI (from cmd/tiredvpn/cgo_darwin.go):
//   typedef void (*tv_state_cb)(const char* state, const char* json_data);
//   typedef void (*tv_log_cb)(const char* message);
//   void TiredvpnSetCallbacks(uintptr_t state_cb, uintptr_t log_cb);
//
// Callbacks may fire from arbitrary Go runtime threads — keep them re-entrant
// and non-blocking. `state` is one of "connecting"|"connected"|"disconnected"|"error".

private let bridgeLog = OSLog(subsystem: "com.tiredvpn.macos", category: "bridge")

@_cdecl("tiredvpn_swift_state_cb")
fileprivate func goStateCB(_ cState: UnsafePointer<CChar>?, _ cJSON: UnsafePointer<CChar>?) {
    let state = cState.map { String(cString: $0) } ?? ""
    let json = cJSON.map { String(cString: $0) } ?? "{}"
    SharedState.publishState(state: state, payload: json)
}

@_cdecl("tiredvpn_swift_log_cb")
fileprivate func goLogCB(_ cStr: UnsafePointer<CChar>?) {
    guard let cStr = cStr else { return }
    LogBuffer.shared.append(String(cString: cStr))
}

enum GoBridge {
    /// Installs C callbacks into the Go runtime. Idempotent.
    /// The header types `TiredvpnSetCallbacks` as `(uintptr_t, uintptr_t)` so we
    /// bit-cast the function pointers through `UInt`.
    static func installCallbacks() {
        let stateAddr = unsafeBitCast(
            goStateCB as @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> Void,
            to: UInt.self
        )
        let logAddr = unsafeBitCast(
            goLogCB as @convention(c) (UnsafePointer<CChar>?) -> Void,
            to: UInt.self
        )
        TiredvpnSetCallbacks(uintptr_t(stateAddr), uintptr_t(logAddr))
        os_log("GoBridge: callbacks installed", log: bridgeLog, type: .info)
    }

    @discardableResult
    static func start(json: String) -> Int32 {
        return json.withCString { TiredvpnStart(UnsafeMutablePointer(mutating: $0)) }
    }

    static func stop() {
        TiredvpnStop()
    }

    static func setTunFd(_ fd: Int32) {
        TiredvpnSetTunFd(fd)
    }

    /// Send JSON command; returned C string is owned by Go — free via TiredvpnFreeString.
    static func sendCommand(_ json: String) -> String? {
        return json.withCString { cIn -> String? in
            guard let cOut = TiredvpnSendCommand(UnsafeMutablePointer(mutating: cIn)) else {
                return nil
            }
            defer { TiredvpnFreeString(cOut) }
            return String(cString: cOut)
        }
    }

    /// Version string. The header comment says "do not free" but cgo allocates
    /// via C.CString each call — that's a Go-side leak to fix separately. We
    /// honour the contract here and skip the free.
    static var version: String {
        guard let cPtr = TiredvpnVersion() else { return "unknown" }
        return String(cString: cPtr)
    }
}
