import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ServersView: View {
    @EnvironmentObject var store: ConfigStore
    @State private var searchText = ""
    @State private var showPasteSheet = false
    @State private var showQRSheet = false
    @State private var pasteText = ""
    @State private var importError: String?

    var filtered: [ServerConfig] {
        if searchText.isEmpty { return store.configs }
        let q = searchText.lowercased()
        return store.configs.filter {
            $0.name.lowercased().contains(q) || $0.server.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.tvTextSecondary)
                TextField("Search servers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.tvBody)
                    .foregroundStyle(Color.tvText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.tvSurfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().overlay(Color.tvBorder)

            if let err = importError {
                Text(err)
                    .font(.tvCaption)
                    .foregroundStyle(Color.tvError)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.tvTextSecondary)
                    Text(store.configs.isEmpty ? "No configs yet" : "No results")
                        .font(.tvBody)
                        .foregroundStyle(Color.tvTextSecondary)
                    Spacer()
                }
            } else {
                List(filtered) { cfg in
                    ServerRow(cfg: cfg, isActive: store.activeID == cfg.id) {
                        store.setActive(id: cfg.id)
                    } onDelete: {
                        store.delete(id: cfg.id)
                    }
                    .listRowBackground(
                        store.activeID == cfg.id
                            ? Color.tvPrimaryDim
                            : Color.clear
                    )
                    .listRowSeparatorTint(Color.tvBorder)
                }
                .listStyle(.plain)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { pickFile() } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .help("Add from file")
                Button { pasteText = ""; showPasteSheet = true } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Paste TOML")
                Button { showQRSheet = true } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
                .help("Scan QR")
            }
        }
        .sheet(isPresented: $showPasteSheet) { pasteSheet }
        .sheet(isPresented: $showQRSheet) {
            QRScannerView(onDecoded: { decoded in
                showQRSheet = false
                handleQRPayload(decoded)
            }, onCancel: {
                showQRSheet = false
            })
            .frame(width: 480, height: 360)
        }
    }

    private var pasteSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste TOML config")
                .font(.tvSubtitle)
                .foregroundStyle(Color.tvText)
            TextEditor(text: $pasteText)
                .font(.tvCaption)
                .frame(minWidth: 480, minHeight: 200)
                .background(Color.tvSurfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Cancel") { showPasteSheet = false; importError = nil }
                Button("Import") {
                    do {
                        _ = try store.importTOML(pasteText)
                        importError = nil
                        showPasteSheet = false
                    } catch {
                        importError = error.localizedDescription
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(pasteText.isEmpty)
            }
        }
        .padding(20)
        .background(Color.tvBackground)
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if let tomlType = UTType(filenameExtension: "toml") {
            panel.allowedContentTypes = [tomlType, .plainText]
        } else {
            panel.allowedContentTypes = [.plainText]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            _ = try store.importTOML(text)
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }

    private func handleQRPayload(_ payload: String) {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            guard let data = Data(base64Encoded: trimmed) else {
                throw ConfigParseError.invalidBase64
            }
            guard let toml = String(data: data, encoding: .utf8) else {
                throw ConfigParseError.invalidUTF8
            }
            _ = try store.importTOML(toml)
            importError = nil
        } catch {
            importError = error.localizedDescription
        }
    }
}

private struct ServerRow: View {
    let cfg: ServerConfig
    let isActive: Bool
    let onUse: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(cfg.name)
                        .font(.tvBody)
                        .foregroundStyle(Color.tvText)
                    if isActive {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.tvPrimary)
                    }
                }
                Text("\(cfg.server):\(cfg.port)  ·  \(cfg.strategy)")
                    .font(.tvCaption)
                    .foregroundStyle(Color.tvTextSecondary)
            }
            Spacer()
            if !isActive {
                Button("Use", action: onUse)
                    .buttonStyle(.bordered)
                    .font(.tvCaption)
            }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}
