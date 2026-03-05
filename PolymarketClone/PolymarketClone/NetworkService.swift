import Foundation

class NetworkService {
    static let shared = NetworkService()
    private init() {}

    private let baseURL = "https://gamma-api.polymarket.com"
    private let clobURL = "https://clob.polymarket.com"

    func fetchEvents() async throws -> [Event] {
        guard let url = URL(string: "\(baseURL)/events?active=true&closed=false&limit=20&order=volume24hr&ascending=false") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Event].self, from: data)
    }

    private let dataURL = "https://data-api.polymarket.com"

    /// Fetch current positions for a wallet address from Polymarket Data API
    func fetchPositions(walletAddress: String) async throws -> [Position] {
        guard let url = URL(string: "\(dataURL)/positions?user=\(walletAddress)&sizeThreshold=0&limit=100&sortBy=CURRENT&sortDirection=DESC") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let raw = try JSONSerialization.jsonObject(with: data)

        guard let items = raw as? [[String: Any]] else {
            print("[Network] Positions response not an array")
            return []
        }

        return items.compactMap { item -> Position? in
            guard let title = item["title"] as? String,
                  let outcome = item["outcome"] as? String,
                  let conditionId = item["conditionId"] as? String,
                  let asset = item["asset"] as? String else { return nil }

            let size = (item["size"] as? Double) ?? Double(item["size"] as? String ?? "") ?? 0
            guard size > 0 else { return nil }

            let avgPrice = (item["avgPrice"] as? Double) ?? Double(item["avgPrice"] as? String ?? "") ?? 0
            let curPrice = (item["curPrice"] as? Double) ?? Double(item["curPrice"] as? String ?? "") ?? 0
            let initialValue = (item["initialValue"] as? Double) ?? Double(item["initialValue"] as? String ?? "") ?? 0
            let currentValue = (item["currentValue"] as? Double) ?? Double(item["currentValue"] as? String ?? "") ?? 0
            let cashPnl = (item["cashPnl"] as? Double) ?? Double(item["cashPnl"] as? String ?? "") ?? 0
            let percentPnl = (item["percentPnl"] as? Double) ?? Double(item["percentPnl"] as? String ?? "") ?? 0
            let icon = item["icon"] as? String
            let slug = item["eventSlug"] as? String

            return Position(
                eventTitle: title,
                marketQuestion: title,
                outcome: outcome,
                amount: initialValue,
                avgPrice: avgPrice,
                currentPrice: curPrice,
                marketImage: icon,
                conditionId: conditionId,
                tokenId: asset,
                shares: size,
                currentValue: currentValue,
                cashPnl: cashPnl,
                percentPnl: percentPnl,
                eventSlug: slug
            )
        }
    }

    /// Fetch price history using CLOB token ID (not conditionId)
    func fetchPriceHistory(tokenId: String, interval: String = "1w", fidelity: Int = 60) async throws -> [PricePoint] {
        guard let url = URL(string: "\(clobURL)/prices-history?market=\(tokenId)&interval=\(interval)&fidelity=\(fidelity)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(PriceHistory.self, from: data)
        return response.history
    }
}
