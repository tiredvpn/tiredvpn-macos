import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        observeTunnel()
        observeSystem()
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "lock.shield",
                                     accessibilityDescription: "TiredVPN")
        item.menu = buildMenu(state: .disconnected)
        self.statusItem = item
    }

    private func buildMenu(state: TunnelState) -> NSMenu {
        let menu = NSMenu()

        let statusTitle: String
        switch state {
        case .disconnected: statusTitle = "Disconnected"
        case .connecting: statusTitle = "Connecting…"
        case .connected(let s, let lat):
            statusTitle = lat.map { "Connected · \(s) · \($0)ms" } ?? "Connected · \(s)"
        case .reasserting: statusTitle = "Reasserting…"
        case .disconnecting: statusTitle = "Disconnecting…"
        case .error(let m): statusTitle = "Error: \(m)"
        }
        let header = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let isConnected: Bool = {
            if case .connected = state { return true }
            return false
        }()

        let toggle = NSMenuItem(
            title: isConnected ? "Disconnect" : "Connect",
            action: isConnected ? #selector(disconnectAction) : #selector(connectAction),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let show = NSMenuItem(title: "Show Main Window",
                              action: #selector(showMainWindow),
                              keyEquivalent: "")
        show.target = self
        menu.addItem(show)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    private func observeTunnel() {
        TunnelManager.shared.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.statusItem?.menu = self.buildMenu(state: state)
                self.statusItem?.button?.image = NSImage(
                    systemSymbolName: self.symbolName(for: state),
                    accessibilityDescription: "TiredVPN"
                )
            }
            .store(in: &cancellables)
    }

    private func symbolName(for state: TunnelState) -> String {
        switch state {
        case .connected: return "lock.shield.fill"
        case .connecting, .reasserting, .disconnecting: return "lock.rotation"
        case .error: return "exclamationmark.shield"
        case .disconnected: return "lock.shield"
        }
    }

    private func observeSystem() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            NSLog("[TiredVPN] willSleep — tunnel state=%@",
                  String(describing: TunnelManager.shared.state))
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            NSLog("[TiredVPN] didWake — tunnel state=%@",
                  String(describing: TunnelManager.shared.state))
        }
    }

    @objc private func connectAction() {
        Task { await TunnelManager.shared.connect() }
    }

    @objc private func disconnectAction() {
        Task { await TunnelManager.shared.disconnect() }
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
    }
}
