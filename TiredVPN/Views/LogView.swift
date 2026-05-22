import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LogView: View {
    @EnvironmentObject var tunnel: TunnelManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tunnel log")
                    .font(.headline)
                Spacer()
                Text("\(tunnel.lastLogLines.count) lines")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    exportLogs()
                } label: { Label("Export…", systemImage: "square.and.arrow.up") }
            }

            ScrollView {
                TextEditor(text: .constant(tunnel.lastLogLines.joined(separator: "\n")))
                    .font(.system(.caption, design: .monospaced))
                    .disabled(true)
                    .frame(minHeight: 320)
            }
            .border(Color.secondary.opacity(0.3))
        }
        .padding()
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "tiredvpn-\(Int(Date().timeIntervalSince1970)).log"
        if let txt = UTType("public.plain-text") {
            panel.allowedContentTypes = [txt]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let content = tunnel.lastLogLines.joined(separator: "\n")
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}
