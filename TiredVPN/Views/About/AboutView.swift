import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            VStack(spacing: 4) {
                Text("TiredVPN")
                    .font(.tvTitle)
                    .foregroundStyle(Color.tvText)
                Text("v\(version) (\(build))")
                    .font(.tvCaption)
                    .foregroundStyle(Color.tvTextSecondary)
            }
            .padding(.top, 16)

            Text("Self-hosted. No subscriptions. No logs.")
                .font(.tvBody)
                .foregroundStyle(Color.tvTextSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, 12)

            Link(destination: URL(string: "https://github.com/tiredvpn")!) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                    Text("GitHub")
                }
                .font(.tvBody)
                .foregroundStyle(Color.tvPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    Capsule().strokeBorder(Color.tvPrimary.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
