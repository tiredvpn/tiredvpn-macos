import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ConfigsView: View {
    @EnvironmentObject var store: ConfigStore
    @State private var showPasteSheet = false
    @State private var showQRSheet = false
    @State private var pasteText = ""
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    pickFile()
                } label: { Label("Add from file…", systemImage: "doc.badge.plus") }

                Button {
                    pasteText = ""
                    showPasteSheet = true
                } label: { Label("Paste TOML", systemImage: "doc.on.clipboard") }

                Button {
                    showQRSheet = true
                } label: { Label("Scan QR", systemImage: "qrcode.viewfinder") }

                Spacer()
            }
            .padding()

            if let err = importError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }

            if store.configs.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(store.configs) { cfg in
                        row(cfg)
                    }
                }
            }
        }
        .sheet(isPresented: $showPasteSheet) {
            pasteSheet
        }
        .sheet(isPresented: $showQRSheet) {
            QRScannerView { decoded in
                showQRSheet = false
                handleQRPayload(decoded)
            } onCancel: {
                showQRSheet = false
            }
            .frame(width: 480, height: 360)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No server configs yet")
                .font(.headline)
            Text("Add a `.toml` file, paste a TOML config, or scan a QR code from your server.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ cfg: ServerConfig) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(cfg.name).font(.headline)
                    if cfg.id == store.activeID {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    }
                }
                Text("\(cfg.server):\(cfg.port)  ·  \(cfg.strategy)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if cfg.id != store.activeID {
                Button("Use") { store.setActive(id: cfg.id) }
                    .buttonStyle(.bordered)
            }
            Button(role: .destructive) {
                store.delete(id: cfg.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }

    private var pasteSheet: some View {
        VStack(alignment: .leading) {
            Text("Paste TOML config").font(.headline)
            TextEditor(text: $pasteText)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.3))
                .frame(minWidth: 480, minHeight: 240)
            HStack {
                Spacer()
                Button("Cancel") { showPasteSheet = false }
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
        .padding()
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

    /// QR payload is base64(toml_bytes). Decode then hand off to importTOML.
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
