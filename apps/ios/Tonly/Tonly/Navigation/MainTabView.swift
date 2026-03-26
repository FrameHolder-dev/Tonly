import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .wallet

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Group {
                    switch tab {
                    case .wallet:
                        WalletHomeView()
                    case .nfts:
                        NFTGalleryView()
                    case .transactions:
                        TransactionListView()
                    case .settings:
                        SettingsView()
                    }
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
        .tint(TonlyTheme.accent)
    }
}
