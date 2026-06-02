import SwiftUI

enum NavItem: String, CaseIterable, Hashable {
    case dashboard = "Dashboard"
    case servers   = "Servers"
    case settings  = "Settings"
    case about     = "About"

    var symbol: String {
        switch self {
        case .dashboard: return "house"
        case .servers:   return "server.rack"
        case .settings:  return "gearshape"
        case .about:     return "info.circle"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: NavItem

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Text("TiredVPN")
                    .font(.tvSubtitle)
                    .foregroundStyle(Color.tvText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)

            ForEach(NavItem.allCases, id: \.self) { item in
                SidebarRow(item: item, isSelected: selection == item)
                    .onTapGesture { selection = item }
            }

            Spacer()

            Text("v\(version)")
                .font(.tvCaption)
                .foregroundStyle(Color.tvTextSecondary)
                .padding(.bottom, 16)
        }
        .background(Color.tvSurface)
    }
}

private struct SidebarRow: View {
    let item: NavItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbol)
                .frame(width: 18)
                .foregroundStyle(isSelected ? Color.tvPrimary : Color.tvTextSecondary)
            Text(item.rawValue)
                .font(.tvBody)
                .foregroundStyle(isSelected ? Color.tvText : Color.tvTextSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.tvPrimaryDim : Color.clear)
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}
