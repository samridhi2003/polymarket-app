import Foundation
import PrivySDK

/// Handles trading on Polymarket using on-device signing via ClobService.
/// No backend proxy needed — the user's embedded wallet signs everything.
@MainActor
class TradingService {
    static let shared = TradingService()
    private init() {}

    private var isInitialized = false

    // MARK: - Initialize

    /// Derive CLOB API keys using the user's embedded wallet
    func initialize(wallet: EmbeddedEthereumWallet) async throws {
        guard !isInitialized else { return }
        _ = try await ClobService.shared.deriveApiKeys(wallet: wallet)
        isInitialized = true
    }

    // MARK: - Place Order

    func placeOrder(
        wallet: EmbeddedEthereumWallet,
        conditionId: String,
        tokenId: String,
        side: OrderSide,
        price: Double,
        size: Double
    ) async throws -> PlaceOrderResult {
        // Ensure we have API keys
        if !isInitialized {
            try await initialize(wallet: wallet)
        }

        // Get market info for negRisk
        let marketInfo = try await ClobService.shared.getMarket(conditionId: conditionId)

        return try await ClobService.shared.placeOrder(
            wallet: wallet,
            tokenId: tokenId,
            price: price,
            size: size,
            side: side,
            tickSize: marketInfo.tickSize,
            negRisk: marketInfo.negRisk
        )
    }
}

// MARK: - Errors

enum TradingError: LocalizedError {
    case networkError
    case serverError(String)
    case noWallet

    var errorDescription: String? {
        switch self {
        case .networkError: return "Network error"
        case .serverError(let msg): return msg
        case .noWallet: return "No wallet available. Please log in first."
        }
    }
}
