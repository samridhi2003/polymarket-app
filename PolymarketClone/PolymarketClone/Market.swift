import Foundation

// MARK: - Tag
struct Tag: Codable, Identifiable, Hashable {
    let id: String
    let label: String
    let slug: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(slug)
    }

    static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.slug == rhs.slug
    }
}

// MARK: - Event
struct Event: Codable, Identifiable {
    let id: String
    let title: String
    let slug: String
    let active: Bool?
    let closed: Bool?
    let image: String?
    let icon: String?
    let volume: Double?
    let volume24hr: Double?
    let liquidity: Double?
    let markets: [Market]?
    let tags: [Tag]?

    var topMarket: Market? { markets?.first }
    var primaryTag: Tag? { tags?.first }

    var formattedVolume: String {
        guard let vol = volume else { return "$0" }
        if vol >= 1_000_000 { return "$\(String(format: "%.1fM", vol / 1_000_000))" }
        if vol >= 1_000 { return "$\(String(format: "%.0fK", vol / 1_000))" }
        return "$\(String(format: "%.0f", vol))"
    }

    /// Whether this event has multiple markets (multi-outcome event like "Who will win?")
    var isMultiMarket: Bool {
        (markets?.count ?? 0) > 1
    }

    /// For multi-market events: one entry per market showing the "Yes" price (= probability of that outcome)
    /// For single-market events: show all outcomes
    var displayOutcomes: [(market: Market, outcome: String, price: Double, displayName: String)] {
        guard let markets = markets else { return [] }

        if isMultiMarket {
            // Multi-market: show each sub-market's "Yes" price as the probability
            // e.g., "200-219 tweets" at 48% means 48% chance of that range
            return markets.compactMap { market in
                // Find the "Yes" outcome price — this is the probability of this outcome
                let yesPrice = market.outcomesPaired.first(where: { $0.outcome == "Yes" })?.price
                    ?? market.parsedPrices.first
                    ?? 0
                let name = market.shortLabel ?? market.question
                return (market: market, outcome: "Yes", price: yesPrice, displayName: name)
            }
            .sorted { $0.price > $1.price }
        } else {
            // Single market: show all outcomes
            return markets.flatMap { market in
                market.outcomesPaired.map {
                    (market: market, outcome: $0.outcome, price: $0.price, displayName: $0.outcome)
                }
            }
            .sorted { $0.price > $1.price }
        }
    }
}

// MARK: - Market
struct Market: Codable, Identifiable {
    let id: String
    let question: String
    let endDateIso: String?
    let active: Bool?
    let closed: Bool?
    let enableOrderBook: Bool?
    let conditionId: String?
    let outcomes: String?
    let outcomePrices: String?
    let image: String?
    let icon: String?
    let clobTokenIds: String?  // JSON-encoded string array, like outcomes
    let groupItemTitle: String?

    enum CodingKeys: String, CodingKey {
        case id, question, endDateIso, active, closed
        case enableOrderBook, conditionId, outcomes, outcomePrices
        case image, icon, clobTokenIds, groupItemTitle
    }

    /// Parse clobTokenIds from JSON string to array
    var parsedClobTokenIds: [String] {
        guard let raw = clobTokenIds,
              let data = raw.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arr
    }

    /// First clob token ID (typically the "Yes" outcome)
    var firstTokenId: String? {
        parsedClobTokenIds.first
    }

    /// Get the clob token ID for a specific outcome (e.g. "Yes" or "No")
    func tokenId(for outcome: String) -> String? {
        let outcomes = parsedOutcomes
        let tokenIds = parsedClobTokenIds
        guard let index = outcomes.firstIndex(of: outcome),
              index < tokenIds.count else { return nil }
        return tokenIds[index]
    }

    /// Short label for multi-market events (e.g., "December 31, 2025" or extracted from question)
    var shortLabel: String? {
        if let title = groupItemTitle, !title.isEmpty {
            return title
        }
        // Try to extract a meaningful short name from the question
        // e.g., "Will X happen?" → "X"
        return nil
    }

    var parsedOutcomes: [String] {
        guard let outcomes = outcomes,
              let data = outcomes.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arr
    }

    var parsedPrices: [Double] {
        guard let outcomePrices = outcomePrices,
              let data = outcomePrices.data(using: .utf8),
              let arr = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return arr.compactMap { Double($0) }
    }

    var outcomesPaired: [(outcome: String, price: Double)] {
        zip(parsedOutcomes, parsedPrices).map { ($0, $1) }
    }

    var tokens: [Token] {
        outcomesPaired.map { Token(outcome: $0.outcome, price: $0.price) }
    }
}

// MARK: - Token
struct Token: Identifiable {
    let id = UUID()
    let outcome: String
    let price: Double
}

// MARK: - Price History
struct PricePoint: Codable, Identifiable {
    var id: Int { t }
    let t: Int      // timestamp
    let p: Double   // price

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(t))
    }
}

struct PriceHistory: Codable {
    let history: [PricePoint]
}

// MARK: - Position (for Wallet)
struct Position: Identifiable, Hashable {
    static func == (lhs: Position, rhs: Position) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: UUID
    let eventTitle: String
    let marketQuestion: String
    let outcome: String
    let amount: Double       // initial cost basis
    let avgPrice: Double
    let currentPrice: Double
    let marketImage: String?
    let conditionId: String?
    let tokenId: String?
    let shares: Double?      // from API: number of shares
    let _currentValue: Double? // from API: pre-computed current value
    let _cashPnl: Double?     // from API: pre-computed PnL
    let _percentPnl: Double?  // from API: pre-computed PnL %
    let eventSlug: String?

    init(eventTitle: String, marketQuestion: String, outcome: String, amount: Double, avgPrice: Double, currentPrice: Double, marketImage: String?, conditionId: String? = nil, tokenId: String? = nil, shares: Double? = nil, currentValue: Double? = nil, cashPnl: Double? = nil, percentPnl: Double? = nil, eventSlug: String? = nil) {
        self.id = UUID()
        self.eventTitle = eventTitle
        self.marketQuestion = marketQuestion
        self.outcome = outcome
        self.amount = amount
        self.avgPrice = avgPrice
        self.currentPrice = currentPrice
        self.marketImage = marketImage
        self.conditionId = conditionId
        self.tokenId = tokenId
        self.shares = shares
        self._currentValue = currentValue
        self._cashPnl = cashPnl
        self._percentPnl = percentPnl
        self.eventSlug = eventSlug
    }

    var numShares: Double {
        if let s = shares, s > 0 { return s }
        guard avgPrice > 0 else { return 0 }
        return amount / avgPrice
    }

    var currentValue: Double {
        if let v = _currentValue, v > 0 { return v }
        return numShares * currentPrice
    }

    var pnl: Double {
        if let p = _cashPnl { return p }
        return currentValue - amount
    }

    var pnlPercent: Double {
        if let p = _percentPnl { return p }
        guard amount > 0 else { return 0 }
        return (pnl / amount) * 100
    }
}
