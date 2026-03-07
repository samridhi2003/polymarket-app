import SwiftUI

enum TabItem: Int, CaseIterable {
    case markets
    case browser
    case wallet

    var label: String {
        switch self {
        case .markets: return "Markets"
        case .browser: return "Browse"
        case .wallet: return "Wallet"
        }
    }

    var icon: String {
        switch self {
        case .markets: return "chart.line.uptrend.xyaxis"
        case .browser: return "globe"
        case .wallet: return "wallet.bifold"
        }
    }

    var activeIcon: String {
        switch self {
        case .markets: return "chart.line.uptrend.xyaxis"
        case .browser: return "globe"
        case .wallet: return "wallet.bifold.fill"
        }
    }

    var activeColor: Color {
        switch self {
        case .markets: return .blue
        case .browser: return .purple
        case .wallet: return .green
        }
    }
}
