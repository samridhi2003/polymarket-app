import Foundation
import CryptoKit
import PrivySDK

// MARK: - EIP-712 Message Structs

private struct ClobAuthMessage: Encodable, Sendable {
    let address: String
    let timestamp: String
    let nonce: Int
    let message: String
}

private struct OrderMessage: Encodable, Sendable {
    let salt: String
    let maker: String
    let signer: String
    let taker: String
    let tokenId: String
    let makerAmount: String
    let takerAmount: String
    let expiration: String
    let nonce: String
    let feeRateBps: String
    let side: Int
    let signatureType: Int
}

/// Rounding config per tick size (from official Polymarket clob-client)
private struct RoundingConfig {
    let price: Int
    let size: Int
    let amount: Int
}

private let roundingConfigs: [String: RoundingConfig] = [
    "0.1":    RoundingConfig(price: 1, size: 2, amount: 3),
    "0.01":   RoundingConfig(price: 2, size: 2, amount: 4),
    "0.001":  RoundingConfig(price: 3, size: 2, amount: 5),
    "0.0001": RoundingConfig(price: 4, size: 2, amount: 6),
]

/// Native iOS client for Polymarket CLOB API.
/// Signs everything on-device using the user's Privy embedded wallet.
@MainActor
class ClobService {
    static let shared = ClobService()
    private init() {}

    private let clobHost = "https://clob.polymarket.com"

    // Cached API credentials per wallet address
    private var cachedCreds: [String: ClobApiCredentials] = [:]

    // Contract addresses
    private let ctfExchange = "0x4bFb41d5B3570DeFd03C39a9A4D8dE6Bd8B8982E"
    private let negRiskExchange = "0xC5d563A36AE78145C45a50134d48A1215220f80a"
    private let usdcAddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    private let ctfContract = "0x4D97DCd97eC945f40cF65F87097ACe5EA0476045"

    // MARK: - Server Time

    func getServerTime() async throws -> String {
        let url = URL(string: "\(clobHost)/time")!
        let (data, _) = try await URLSession.shared.data(from: url)
        if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return str.replacingOccurrences(of: "\"", with: "")
        }
        throw ClobError.invalidResponse
    }

    // MARK: - L1 Auth: Derive API Keys

    func deriveApiKeys(wallet: EmbeddedEthereumWallet) async throws -> ClobApiCredentials {
        let address = wallet.address

        if let cached = cachedCreds[address.lowercased()] {
            return cached
        }

        let timestamp = try await getServerTime()

        let domain = EthereumRpcRequest.EIP712TypedData.EIP712Domain(
            name: "ClobAuthDomain",
            version: "1",
            chainId: 137
        )
        let types: [String: [EthereumRpcRequest.EIP712TypedData.EIP712Type]] = [
            "ClobAuth": [
                .init("address", type: "address"),
                .init("timestamp", type: "string"),
                .init("nonce", type: "uint256"),
                .init("message", type: "string")
            ]
        ]
        let message = ClobAuthMessage(
            address: address,
            timestamp: timestamp,
            nonce: 0,
            message: "This message attests that I control the given wallet"
        )
        let eip712 = EthereumRpcRequest.EIP712TypedData(
            domain: domain,
            primaryType: "ClobAuth",
            types: types,
            message: message
        )

        let signature = try await wallet.provider.request(
            .ethSignTypedDataV4(address: address, typedData: eip712)
        )

        // POST to create API key
        let url = URL(string: "\(clobHost)/auth/api-key")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue(address, forHTTPHeaderField: "POLY_ADDRESS")
        request.addValue(signature, forHTTPHeaderField: "POLY_SIGNATURE")
        request.addValue(timestamp, forHTTPHeaderField: "POLY_TIMESTAMP")
        request.addValue("0", forHTTPHeaderField: "POLY_NONCE")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClobError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[CLOB] Create API key failed (\(httpResponse.statusCode)): \(errorStr)")

            return try await deriveExistingApiKeys(
                wallet: wallet,
                address: address,
                timestamp: timestamp,
                signature: signature
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = json["apiKey"] as? String ?? json["key"] as? String,
              let secret = json["secret"] as? String,
              let passphrase = json["passphrase"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("[CLOB] Unexpected API key response: \(raw)")
            throw ClobError.invalidResponse
        }

        let creds = ClobApiCredentials(apiKey: apiKey, secret: secret, passphrase: passphrase)
        cachedCreds[address.lowercased()] = creds
        return creds
    }

    private func deriveExistingApiKeys(
        wallet: EmbeddedEthereumWallet,
        address: String,
        timestamp: String,
        signature: String
    ) async throws -> ClobApiCredentials {
        let url = URL(string: "\(clobHost)/auth/derive-api-key")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(address, forHTTPHeaderField: "POLY_ADDRESS")
        request.addValue(signature, forHTTPHeaderField: "POLY_SIGNATURE")
        request.addValue(timestamp, forHTTPHeaderField: "POLY_TIMESTAMP")
        request.addValue("0", forHTTPHeaderField: "POLY_NONCE")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClobError.authFailed(errorStr)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let apiKey = json["apiKey"] as? String ?? json["key"] as? String,
              let secret = json["secret"] as? String,
              let passphrase = json["passphrase"] as? String else {
            throw ClobError.invalidResponse
        }

        let creds = ClobApiCredentials(apiKey: apiKey, secret: secret, passphrase: passphrase)
        cachedCreds[wallet.address.lowercased()] = creds
        return creds
    }

    // MARK: - L2 Auth: HMAC Headers

    func buildL2Headers(
        creds: ClobApiCredentials,
        address: String,
        method: String,
        path: String,
        body: String? = nil
    ) -> [String: String] {
        let timestamp = String(Int(Date().timeIntervalSince1970))

        var message = timestamp + method + path
        if let body = body {
            message += body
        }

        let signature = hmacSHA256(secret: creds.secret, message: message)

        return [
            "POLY_ADDRESS": address,
            "POLY_API_KEY": creds.apiKey,
            "POLY_PASSPHRASE": creds.passphrase,
            "POLY_TIMESTAMP": timestamp,
            "POLY_SIGNATURE": signature
        ]
    }

    private func hmacSHA256(secret: String, message: String) -> String {
        let standardBase64 = secret
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let secretData = Data(base64Encoded: standardBase64) else {
            return ""
        }

        let key = SymmetricKey(data: secretData)
        let messageData = Data(message.utf8)
        let mac = HMAC<SHA256>.authenticationCode(for: messageData, using: key)

        return Data(mac)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
    }

    // MARK: - Place Order

    func placeOrder(
        wallet: EmbeddedEthereumWallet,
        tokenId: String,
        price: Double,
        size: Double,
        side: OrderSide,
        tickSize: String = "0.01",
        negRisk: Bool = false,
        orderType: String = "GTC"
    ) async throws -> PlaceOrderResult {
        let address = wallet.address
        let creds = try await deriveApiKeys(wallet: wallet)

        // Get rounding config for this tick size
        let roundConfig = roundingConfigs[tickSize] ?? RoundingConfig(price: 2, size: 2, amount: 4)

        // Round price to tick size precision
        let roundedPrice = roundNormal(price, decimals: roundConfig.price)

        // Calculate amounts with proper rounding (matching official clob-client)
        // CLOB enforces: makerAmount max (amount) decimals, takerAmount max (size) decimals
        let makerAmount: String
        let takerAmount: String

        if side == .buy {
            let rawTakerAmt = roundDown(size, decimals: roundConfig.size)
            let rawMakerAmt = fixAmountPrecision(rawTakerAmt * roundedPrice, decimals: roundConfig.amount)
            makerAmount = toWei(rawMakerAmt, decimals: roundConfig.amount)
            takerAmount = toWei(rawTakerAmt, decimals: roundConfig.size)
        } else {
            let rawMakerAmt = roundDown(size, decimals: roundConfig.size)
            let rawTakerAmt = fixAmountPrecision(rawMakerAmt * roundedPrice, decimals: roundConfig.amount)
            makerAmount = toWei(rawMakerAmt, decimals: roundConfig.size)
            takerAmount = toWei(rawTakerAmt, decimals: roundConfig.amount)
        }

        // Generate salt (matching official client: Math.round(Math.random() * Date.now()))
        let salt = Int(Double.random(in: 0..<1) * Date().timeIntervalSince1970 * 1000)
        let saltString = String(salt)
        let sideValue = side == .buy ? 0 : 1

        let verifyingContract = negRisk ? negRiskExchange : ctfExchange

        // Sign order via Privy (EIP-712)
        let orderDomain = EthereumRpcRequest.EIP712TypedData.EIP712Domain(
            name: "Polymarket CTF Exchange",
            version: "1",
            chainId: 137,
            verifyingContract: verifyingContract
        )
        let orderTypes: [String: [EthereumRpcRequest.EIP712TypedData.EIP712Type]] = [
            "Order": [
                .init("salt", type: "uint256"),
                .init("maker", type: "address"),
                .init("signer", type: "address"),
                .init("taker", type: "address"),
                .init("tokenId", type: "uint256"),
                .init("makerAmount", type: "uint256"),
                .init("takerAmount", type: "uint256"),
                .init("expiration", type: "uint256"),
                .init("nonce", type: "uint256"),
                .init("feeRateBps", type: "uint256"),
                .init("side", type: "uint8"),
                .init("signatureType", type: "uint8")
            ]
        ]
        let orderMessage = OrderMessage(
            salt: saltString,
            maker: address,
            signer: address,
            taker: "0x0000000000000000000000000000000000000000",
            tokenId: tokenId,
            makerAmount: makerAmount,
            takerAmount: takerAmount,
            expiration: "0",
            nonce: "0",
            feeRateBps: "0",
            side: sideValue,
            signatureType: 0
        )
        let orderEip712 = EthereumRpcRequest.EIP712TypedData(
            domain: orderDomain,
            primaryType: "Order",
            types: orderTypes,
            message: orderMessage
        )

        let orderSignature = try await wallet.provider.request(
            .ethSignTypedDataV4(address: address, typedData: orderEip712)
        )

        // Build POST body (matching official clob-client orderToJson format)
        let orderBody: [String: Any] = [
            "order": [
                "salt": salt,  // number, not string
                "maker": address,
                "signer": address,
                "taker": "0x0000000000000000000000000000000000000000",
                "tokenId": tokenId,
                "makerAmount": makerAmount,
                "takerAmount": takerAmount,
                "expiration": "0",
                "nonce": "0",
                "feeRateBps": "0",
                "side": side == .buy ? "BUY" : "SELL",
                "signatureType": 0,
                "signature": orderSignature
            ],
            "owner": creds.apiKey,
            "orderType": orderType
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: orderBody, options: [.sortedKeys])
        let bodyString = String(data: bodyData, encoding: .utf8)!
        print("[CLOB] Order request body: \(bodyString)")

        // Build L2 HMAC headers
        let headers = buildL2Headers(
            creds: creds,
            address: address,
            method: "POST",
            path: "/order",
            body: bodyString
        )

        // POST order
        let url = URL(string: "\(clobHost)/order")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = bodyData

        // Retry loop: CLOB may return 425 "service not ready" after balance/allowance update
        var lastError: Error = ClobError.invalidResponse
        for attempt in 0..<3 {
            if attempt > 0 {
                print("[CLOB] Retrying order (attempt \(attempt + 1))...")
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            let rawResponse = String(data: data, encoding: .utf8) ?? ""
            print("[CLOB] Order response (\(statusCode)): \(rawResponse)")

            // Handle non-JSON responses (e.g. 425 "service not ready")
            guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                if statusCode == 425 {
                    lastError = ClobError.orderFailed("Service not ready, retrying...")
                    continue
                }
                throw ClobError.orderFailed(rawResponse.isEmpty ? "Invalid response" : rawResponse)
            }

            if statusCode != 200 {
                let errorMsg = json["error"] as? String ?? json["errorMsg"] as? String ?? json["message"] as? String ?? "Order failed"
                if statusCode == 425 {
                    lastError = ClobError.orderFailed(errorMsg)
                    continue
                }
                throw ClobError.orderFailed(errorMsg)
            }

            // Check for error message even in 200 responses
            if let errorMsg = json["error"] as? String ?? json["errorMsg"] as? String, !errorMsg.isEmpty {
                throw ClobError.orderFailed(errorMsg)
            }

            let success = json["success"] as? Bool ?? (json["orderID"] != nil)
            let status = json["status"] as? String

            if json["success"] as? Bool == false {
                throw ClobError.orderFailed(status ?? "Order was not accepted")
            }

            return PlaceOrderResult(
                success: success,
                orderId: json["orderID"] as? String,
                status: status
            )
        }

        throw lastError
    }

    // MARK: - Update Balance/Allowance Cache

    /// Tell the CLOB to refresh its cached view of the user's on-chain balance/allowance.
    /// Must be called after on-chain approvals and before placing orders.
    func updateBalanceAllowance(
        wallet: EmbeddedEthereumWallet,
        assetType: String,   // "COLLATERAL" or "CONDITIONAL"
        tokenId: String? = nil
    ) async throws {
        let creds = try await deriveApiKeys(wallet: wallet)
        let address = wallet.address

        var urlString = "\(clobHost)/balance-allowance/update?asset_type=\(assetType)&signature_type=0"
        if let tokenId = tokenId {
            urlString += "&token_id=\(tokenId)"
        }

        let headers = buildL2Headers(
            creds: creds,
            address: address,
            method: "GET",
            path: "/balance-allowance/update"
        )

        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as? HTTPURLResponse
        let raw = String(data: data, encoding: .utf8) ?? ""
        print("[CLOB] updateBalanceAllowance(\(assetType)) response (\(httpResponse?.statusCode ?? 0)): \(raw)")
    }

    // MARK: - Get Market Info

    func getMarket(conditionId: String) async throws -> MarketInfo {
        let url = URL(string: "\(clobHost)/markets/\(conditionId)")!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClobError.invalidResponse
        }

        return MarketInfo(
            conditionId: conditionId,
            tickSize: json["minimum_tick_size"] as? String ?? "0.01",
            negRisk: json["neg_risk"] as? Bool ?? false
        )
    }

    // MARK: - Rounding Helpers (matching official clob-client)

    private func roundNormal(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return (value * factor).rounded() / factor
    }

    private func roundDown(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return floor(value * factor) / factor
    }

    private func roundUp(_ value: Double, decimals: Int) -> Double {
        let factor = pow(10.0, Double(decimals))
        return ceil(value * factor) / factor
    }

    /// Fix floating-point noise in amount products (matching official clob-client logic).
    /// First tries roundUp at extra precision to snap float noise to the correct value,
    /// then falls back to roundDown if still too many decimals.
    /// e.g., 6.6 * 0.15 = 0.989999... → roundUp(_, 8) = 0.99 → 2 decimals ≤ 4 → done
    private func fixAmountPrecision(_ value: Double, decimals: Int) -> Double {
        // Try roundUp with extra headroom (decimals + 4) to fix float drift
        let snapped = roundUp(value, decimals: decimals + 4)
        // Check if snapped value fits within required precision
        let factor = pow(10.0, Double(decimals))
        let check = snapped * factor
        if abs(check - check.rounded()) < 0.0001 {
            // Snapped cleanly to required precision
            return (check.rounded()) / factor
        }
        // Fallback: round down to required precision
        return roundDown(value, decimals: decimals)
    }

    /// Convert a decimal amount to wei string (6 decimals for USDC/tokens)
    /// Quantizes to the specified number of raw decimal places to avoid floating-point drift.
    /// e.g., decimals=2 means the raw value has max 2 decimal places → wei is a multiple of 10000
    private func toWei(_ amount: Double, decimals: Int = 6) -> String {
        // First quantize to the allowed precision to kill floating-point noise
        let factor = pow(10.0, Double(decimals))
        let quantized = floor(amount * factor) / factor
        // Then convert to wei (1e6) with rounding to handle remaining float fuzz
        let wei = Int((quantized * 1_000_000).rounded())
        return String(wei)
    }

}

// MARK: - Models

struct ClobApiCredentials {
    let apiKey: String
    let secret: String
    let passphrase: String
}

enum OrderSide {
    case buy, sell
}

struct PlaceOrderResult {
    let success: Bool
    let orderId: String?
    let status: String?
}

struct MarketInfo {
    let conditionId: String
    let tickSize: String
    let negRisk: Bool
}

enum ClobError: LocalizedError {
    case invalidResponse
    case authFailed(String)
    case orderFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from CLOB API"
        case .authFailed(let msg): return "Auth failed: \(msg)"
        case .orderFailed(let msg): return "Order failed: \(msg)"
        }
    }
}
