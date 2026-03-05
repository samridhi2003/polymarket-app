import Foundation
import Combine
import PrivySDK

@MainActor
class MarketViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var markets: [Market] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var selectedTag: Tag? = nil
    @Published var searchText: String = ""
    @Published var positions: [Position] = []
    @Published var usdcBalance: Double = 0
    @Published var nativeBalance: Double = 0
    @Published var isLoadingBalance = false
    @Published var tradingInitialized = false

    /// Trending = top 3 by volume (already sorted by API)
    var trendingEvents: [Event] {
        Array(events.prefix(3))
    }

    var allTags: [Tag] {
        var seen = Set<String>()
        var tags: [Tag] = []
        for event in events {
            for tag in event.tags ?? [] {
                if !seen.contains(tag.slug) {
                    seen.insert(tag.slug)
                    tags.append(tag)
                }
            }
        }
        return tags
    }

    var filteredEvents: [Event] {
        var result = events

        if let tag = selectedTag {
            result = result.filter { event in
                event.tags?.contains(where: { $0.slug == tag.slug }) ?? false
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.title.lowercased().contains(query) }
        }

        return result
    }

    func loadMarkets() async {
        isLoading = true
        errorMessage = nil

        do {
            let events = try await NetworkService.shared.fetchEvents()
            self.events = events
            self.markets = events.flatMap { $0.markets ?? [] }
        } catch let decodingError as DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                errorMessage = "Missing key '\(key.stringValue)' in \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .typeMismatch(let type, let context):
                errorMessage = "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            case .valueNotFound(let type, let context):
                errorMessage = "Null value for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
            default:
                errorMessage = "Decoding error: \(decodingError.localizedDescription)"
            }
            print("Decoding error: \(decodingError)")
        } catch {
            errorMessage = "Failed to load markets: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Wallet

    func refreshBalance(walletAddress: String) async {
        isLoadingBalance = true
        do {
            usdcBalance = try await WalletService.shared.getUSDCBalance(for: walletAddress)
            nativeBalance = try await WalletService.shared.getNativeBalance(for: walletAddress)
        } catch {
            print("Failed to fetch balance: \(error)")
        }

        // Fetch positions from Polymarket Data API
        do {
            let apiPositions = try await NetworkService.shared.fetchPositions(walletAddress: walletAddress)
            positions = apiPositions
        } catch {
            print("Failed to fetch positions: \(error)")
        }

        isLoadingBalance = false
    }

    func initializeTrading(wallet: EmbeddedEthereumWallet) async {
        guard !tradingInitialized else { return }
        do {
            try await TradingService.shared.initialize(wallet: wallet)
            tradingInitialized = true
        } catch {
            print("Failed to initialize trading: \(error)")
        }
    }

    // MARK: - Trading

    func placeOrder(
        wallet: EmbeddedEthereumWallet,
        eventTitle: String,
        market: Market,
        outcome: String,
        amount: Double,
        price: Double
    ) async throws {
        guard let conditionId = market.conditionId else {
            throw TradingError.serverError("Market missing conditionId")
        }

        // Get market info first to determine negRisk
        let marketInfo = try await ClobService.shared.getMarket(conditionId: conditionId)

        // Determine the correct tokenId and side for the CLOB
        // For neg_risk (multi-outcome) markets: only the Yes token has an orderbook.
        //   "Buy Yes" → BUY on Yes token at yesPrice
        //   "Buy No"  → SELL on Yes token at yesPrice (complement)
        // For binary markets: both tokens have orderbooks, always BUY.
        let tokenId: String
        let side: OrderSide
        let orderPrice: Double

        if marketInfo.negRisk {
            // Always use the Yes token (first token) for neg_risk markets
            guard let yesTokenId = market.tokenId(for: "Yes") ?? market.firstTokenId else {
                throw TradingError.serverError("No Yes token ID found for market")
            }
            tokenId = yesTokenId

            if outcome == "Yes" {
                side = .buy
                orderPrice = price
            } else {
                // "Buy No" = SELL the Yes token
                // No price = 1 - yesPrice, so yesPrice = 1 - noPrice
                side = .sell
                orderPrice = 1.0 - price
            }
        } else {
            // Binary market: use the token for the selected outcome
            guard let outcomeTokenId = market.tokenId(for: outcome) else {
                throw TradingError.serverError("No token ID found for outcome '\(outcome)'")
            }
            tokenId = outcomeTokenId
            side = .buy
            orderPrice = price
        }

        guard orderPrice > 0 && orderPrice < 1 else {
            throw TradingError.serverError("Invalid price \(orderPrice). Must be between 0 and 1.")
        }

        let size = amount / orderPrice

        // Ensure USDC is approved for the exchange contracts
        // For neg_risk markets, approve BOTH exchanges (CLOB checks the CTF exchange too)
        let ctfExchange = "0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E"
        let negRiskExchange = "0xC5d563A36AE78145C45a50134d48A1215220f80a"
        let negRiskAdapter = "0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296"
        let ctfContract = "0x4D97DCd97eC945f40cF65F87097ACe5EA0476045"

        // 1. Approve USDC spending on all three contracts
        try await WalletService.shared.ensureUSDCApproval(
            wallet: wallet,
            spender: ctfExchange,
            amount: amount
        )
        try await WalletService.shared.ensureUSDCApproval(
            wallet: wallet,
            spender: negRiskExchange,
            amount: amount
        )
        try await WalletService.shared.ensureUSDCApproval(
            wallet: wallet,
            spender: negRiskAdapter,
            amount: amount
        )

        // 2. Approve conditional tokens (ERC-1155) on CTF contract for all three operators
        try await WalletService.shared.ensureApprovalForAll(
            wallet: wallet,
            operator: ctfExchange,
            contract: ctfContract
        )
        try await WalletService.shared.ensureApprovalForAll(
            wallet: wallet,
            operator: negRiskExchange,
            contract: ctfContract
        )
        try await WalletService.shared.ensureApprovalForAll(
            wallet: wallet,
            operator: negRiskAdapter,
            contract: ctfContract
        )

        let result = try await TradingService.shared.placeOrder(
            wallet: wallet,
            conditionId: conditionId,
            tokenId: tokenId,
            side: side,
            price: orderPrice,
            size: size
        )

        if result.success {
            let position = Position(
                eventTitle: eventTitle,
                marketQuestion: market.question,
                outcome: outcome,
                amount: amount,
                avgPrice: price,
                currentPrice: price,
                marketImage: market.image,
                conditionId: conditionId,
                tokenId: tokenId
            )
            positions.append(position)

            await refreshBalance(walletAddress: wallet.address)
        } else {
            throw TradingError.serverError(result.status ?? "Order was not successful")
        }
    }

    // MARK: - Sell Position

    func sellPosition(
        wallet: EmbeddedEthereumWallet,
        position: Position,
        conditionId: String,
        tokenId: String
    ) async throws {
        let marketInfo = try await ClobService.shared.getMarket(conditionId: conditionId)

        let shares = position.numShares
        let sellPrice = position.currentPrice

        guard sellPrice > 0 && sellPrice < 1 else {
            throw TradingError.serverError("Invalid sell price \(sellPrice)")
        }

        // Ensure approvals are set (same as buy flow)
        let ctfExchange = "0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E"
        let negRiskExchange = "0xC5d563A36AE78145C45a50134d48A1215220f80a"
        let negRiskAdapter = "0xd91E80cF2E7be2e162c6513ceD06f1dD0dA35296"
        let ctfContract = "0x4D97DCd97eC945f40cF65F87097ACe5EA0476045"

        try await WalletService.shared.ensureApprovalForAll(
            wallet: wallet,
            operator: ctfExchange,
            contract: ctfContract
        )
        try await WalletService.shared.ensureApprovalForAll(
            wallet: wallet,
            operator: negRiskExchange,
            contract: ctfContract
        )
        try await WalletService.shared.ensureApprovalForAll(
            wallet: wallet,
            operator: negRiskAdapter,
            contract: ctfContract
        )

        // For selling, we place a SELL order on the CLOB
        // For negRisk markets where user bought "Yes": SELL the Yes token
        // For negRisk markets where user bought "No": BUY the Yes token (to close the short)
        // For binary markets: SELL the outcome token
        let orderSide: OrderSide
        let orderTokenId: String
        let orderPrice: Double

        if marketInfo.negRisk {
            let yesTokenId = tokenId // We stored the token used for the original order
            orderTokenId = yesTokenId

            if position.outcome == "Yes" {
                orderSide = .sell
                orderPrice = sellPrice
            } else {
                // Closing a "No" position (which was originally a SELL on Yes token)
                // means we BUY the Yes token back
                orderSide = .buy
                orderPrice = 1.0 - sellPrice
            }
        } else {
            orderTokenId = tokenId
            orderSide = .sell
            orderPrice = sellPrice
        }

        let result = try await ClobService.shared.placeOrder(
            wallet: wallet,
            tokenId: orderTokenId,
            price: orderPrice,
            size: shares,
            side: orderSide,
            tickSize: marketInfo.tickSize,
            negRisk: marketInfo.negRisk
        )

        if result.success {
            positions.removeAll { $0.id == position.id }
            await refreshBalance(walletAddress: wallet.address)
        } else {
            throw TradingError.serverError(result.status ?? "Sell order was not successful")
        }
    }

    /// Fallback: add a mock position (when trading isn't set up)
    func addPosition(eventTitle: String, marketQuestion: String, outcome: String, amount: Double, price: Double, marketImage: String?) {
        let position = Position(
            eventTitle: eventTitle,
            marketQuestion: marketQuestion,
            outcome: outcome,
            amount: amount,
            avgPrice: price,
            currentPrice: price,
            marketImage: marketImage
        )
        positions.append(position)
        usdcBalance -= amount
    }
}
