import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MarketViewModel()
    @StateObject private var browserController = BrowserController()
    @EnvironmentObject var auth: AuthManager

    @State private var selectedTab: TabItem = .markets
    @State private var browserPendingURL: URL? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            Group {
                switch selectedTab {
                case .markets:
                    MarketsTabView(viewModel: viewModel)
                        .environment(\.openInAppBrowser, OpenInAppBrowserAction { url in
                            openInBrowser(url)
                        })
                case .browser:
                    BrowserTabView(
                        browserController: browserController,
                        pendingURL: $browserPendingURL
                    )
                case .wallet:
                    WalletTabView(viewModel: viewModel)
                        .environment(\.openInAppBrowser, OpenInAppBrowserAction { url in
                            openInBrowser(url)
                        })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating tab bar
            FloatingTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .task {
            await viewModel.loadMarkets()
            if let address = auth.walletAddress {
                await viewModel.refreshBalance(walletAddress: address)
            }
            if let wallet = auth.embeddedWallet {
                await viewModel.initializeTrading(wallet: wallet)
            }
        }
    }

    private func openInBrowser(_ url: URL) {
        browserPendingURL = url
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedTab = .browser
        }
    }
}

// MARK: - Environment key for opening links in the in-app browser

struct OpenInAppBrowserAction {
    let handler: (URL) -> Void

    func callAsFunction(_ url: URL) {
        handler(url)
    }
}

private struct OpenInAppBrowserKey: EnvironmentKey {
    static let defaultValue = OpenInAppBrowserAction { _ in }
}

extension EnvironmentValues {
    var openInAppBrowser: OpenInAppBrowserAction {
        get { self[OpenInAppBrowserKey.self] }
        set { self[OpenInAppBrowserKey.self] = newValue }
    }
}
