import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LogView: View {
    @EnvironmentObject var tunnel: TunnelManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tunnel log")
                    .font(.tvSubtitle)
                    .foregroundStyle(Color.tvText)
                Spacer()
                Text("\(tunnel.lastLogLines.count) lines")
                    .font(.tvCaption)
                    .foregroundStyle(Color.tvTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().overlay(Color.tvBorder)

            ScrollView {
                TextEditor(text: .constant(tunnel.lastLogLines.joined(separator: "\n")))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.tvText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .disabled(true)
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .padding(12)
            }
            .background(Color.tvSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(16)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    exportLogs()
                } label: {
                    Label("Export...", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "tiredvpn-\(Int(Date().timeIntervalSince1970)).log"
        if let txt = UTType("public.plain-text") {
            panel.allowedContentTypes = [txt]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? tunnel.lastLogLines.joined(separator: "\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }
}
