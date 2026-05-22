import Foundation
import os.log

/// Append-only ring log file in the App Group.
/// - Rotates when size exceeds `maxBytes` (single `.1` backup).
/// - Drops messages when the internal queue exceeds `queueCap` to avoid blocking
///   the Go runtime on log callbacks. Drop count is persisted to `dropped.count`.
final class LogBuffer {
    static let shared = LogBuffer()

    private let maxBytes: UInt64 = 1 * 1024 * 1024
    private let queueCap = 1000

    private let queue = DispatchQueue(label: "com.tiredvpn.macos.logbuffer", qos: .utility)
    private let log = OSLog(subsystem: "com.tiredvpn.macos", category: "log")

    // Touched only on `queue`.
    private var pending: Int = 0
    private var dropped: UInt64 = 0
    private var handle: FileHandle?

    private init() {
        ensureDir()
    }

    /// Non-blocking: schedules append on a serial queue, drops on overflow.
    func append(level: Int32, msg: String) {
        // Best-effort backpressure check. Reading `pending` outside the queue is racy
        // but acceptable — it's only a hint to drop early.
        if pending >= queueCap {
            queue.async { [weak self] in
                guard let self = self else { return }
                self.dropped &+= 1
                self.persistDroppedCount()
            }
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }
            self.pending -= 1 // we decrement first because we incremented optimistically below

            self.writeLine(level: level, msg: msg)
        }
        pending += 1
    }

    private func ensureDir() {
        try? FileManager.default.createDirectory(
            at: AppGroup.logsDirURL,
            withIntermediateDirectories: true
        )
    }

    private func openHandle() -> FileHandle? {
        if let h = handle { return h }
        let url = AppGroup.logFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let h = try? FileHandle(forWritingTo: url) else {
            os_log("LogBuffer: open failed", log: log, type: .error)
            return nil
        }
        try? h.seekToEnd()
        handle = h
        return h
    }

    private func writeLine(level: Int32, msg: String) {
        guard let h = openHandle() else { return }

        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "\(ts) [\(level)] \(msg)\n"
        guard let data = line.data(using: .utf8) else { return }

        do {
            try h.write(contentsOf: data)
        } catch {
            // Re-open on failure.
            try? handle?.close()
            handle = nil
            return
        }

        rotateIfNeeded()
    }

    private func rotateIfNeeded() {
        guard let h = handle else { return }
        let size = (try? h.offset()) ?? 0
        guard size > maxBytes else { return }

        try? h.close()
        handle = nil

        let fm = FileManager.default
        try? fm.removeItem(at: AppGroup.logBackupURL)
        try? fm.moveItem(at: AppGroup.logFileURL, to: AppGroup.logBackupURL)
    }

    private func persistDroppedCount() {
        let data = Data(String(dropped).utf8)
        try? data.write(to: AppGroup.droppedCountURL, options: [.atomic])
    }
}
