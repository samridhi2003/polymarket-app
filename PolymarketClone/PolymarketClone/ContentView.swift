import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = MarketViewModel()
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        TabView {
            MarketsTabView(viewModel: viewModel)
                .tabItem {
                    Label("Markets", systemImage: "chart.line.uptrend.xyaxis")
                }

            WalletTabView(viewModel: viewModel)
                .tabItem {
                    Label("Wallet", systemImage: "wallet.bifold")
                }
        }
        .tint(.blue)
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
}
