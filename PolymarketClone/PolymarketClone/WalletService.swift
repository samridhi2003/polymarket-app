import Foundation
import PrivySDK

/// Handles on-chain interactions via Privy's embedded wallet provider on Polygon
@MainActor
class WalletService {
    static let shared = WalletService()
    private init() {}

    // Polygon chain
    private let chainId = "0x89" // 137
    private let polygonRPC = "https://polygon-bor-rpc.publicnode.com"

    // USDC.e on Polygon
    private let usdcAddress = "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174"
    private let usdcDecimals: Int = 6

    // MARK: - USDC Balance

    /// Fetch USDC.e balance for the given address using a public RPC (no signing needed)
    func getUSDCBalance(for address: String) async throws -> Double {
        // balanceOf(address) selector = 0x70a08231
        // Pad address to 32 bytes
        let paddedAddress = address.lowercased().replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        let data = "0x70a08231" + paddedAddress

        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [
                ["to": usdcAddress, "data": data],
                "latest"
            ],
            "id": 1
        ]

        guard let url = URL(string: polygonRPC) else { throw WalletError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let result = json["result"] as? String else {
            throw WalletError.invalidResponse
        }

        // Parse hex balance
        let hexStr = result.replacingOccurrences(of: "0x", with: "")
        guard let balance = UInt64(hexStr, radix: 16) else { return 0 }
        return Double(balance) / pow(10.0, Double(usdcDecimals))
    }

    // MARK: - Send USDC

    /// Send USDC.e via Privy embedded wallet provider
    func sendUSDC(
        from wallet: EmbeddedEthereumWallet,
        to recipient: String,
        amount: Double
    ) async throws -> String {
        // Convert amount to smallest unit (6 decimals)
        let rawAmount = UInt64(amount * pow(10.0, Double(usdcDecimals)))
        let hexAmount = String(rawAmount, radix: 16).leftPadded(toLength: 64, withPad: "0")

        // transfer(address,uint256) selector = 0xa9059cbb
        let paddedRecipient = recipient.lowercased().replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        let txData = "0xa9059cbb" + paddedRecipient + hexAmount

        let transaction = EthereumRpcRequest.UnsignedEthTransaction(
            from: wallet.address,
            to: usdcAddress,
            data: txData,
            chainId: .hexadecimalNumber(chainId)
        )

        let txHash = try await wallet.provider.request(
            .ethSendTransaction(transaction: transaction)
        )

        return txHash
    }

    // MARK: - Native POL/MATIC Balance

    func getNativeBalance(for address: String) async throws -> Double {
        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getBalance",
            "params": [address, "latest"],
            "id": 1
        ]

        guard let url = URL(string: polygonRPC) else { throw WalletError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let result = json["result"] as? String else {
            throw WalletError.invalidResponse
        }

        let hexStr = result.replacingOccurrences(of: "0x", with: "")
        guard let balance = UInt64(hexStr, radix: 16) else { return 0 }
        return Double(balance) / 1e18 // 18 decimals for POL/MATIC
    }

    // MARK: - USDC Approval

    /// Check current USDC allowance for a spender
    func getUSDCAllowance(owner: String, spender: String) async throws -> Double {
        // allowance(address,address) selector = 0xdd62ed3e
        let paddedOwner = owner.lowercased().replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        let paddedSpender = spender.lowercased().replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        let data = "0xdd62ed3e" + paddedOwner + paddedSpender

        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [
                ["to": usdcAddress, "data": data],
                "latest"
            ],
            "id": 1
        ]

        guard let url = URL(string: polygonRPC) else { throw WalletError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw WalletError.invalidResponse
        }

        if json["error"] != nil {
            return 0
        }

        guard let result = json["result"] as? String else {
            return 0
        }

        let hexStr = result.replacingOccurrences(of: "0x", with: "").drop { $0 == "0" }
        // If hex string is too large for UInt64 (e.g. max uint256 approval), treat as unlimited
        if hexStr.count > 16 {
            return Double.greatestFiniteMagnitude
        }
        guard let allowance = UInt64(String(hexStr), radix: 16) else { return 0 }
        return Double(allowance) / pow(10.0, Double(usdcDecimals))
    }

    /// Approve USDC spending for a spender (e.g. CTF Exchange) if needed
    func ensureUSDCApproval(
        wallet: EmbeddedEthereumWallet,
        spender: String,
        amount: Double
    ) async throws {
        let currentAllowance = try await getUSDCAllowance(owner: wallet.address, spender: spender)

        if currentAllowance >= amount {
            return
        }

        // Approve max uint256 so we don't need to re-approve each time
        // approve(address,uint256) selector = 0x095ea7b3
        let paddedSpender = spender.lowercased().replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        // Max uint256 = ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        let maxAmount = String(repeating: "f", count: 64)
        let txData = "0x095ea7b3" + paddedSpender + maxAmount

        let transaction = EthereumRpcRequest.UnsignedEthTransaction(
            from: wallet.address,
            to: usdcAddress,
            data: txData,
            chainId: .hexadecimalNumber(chainId)
        )

        let txHash = try await wallet.provider.request(
            .ethSendTransaction(transaction: transaction)
        )
        // Wait for confirmation (poll for receipt)
        try await waitForTransaction(txHash: txHash)
    }

    /// Poll until a transaction is mined
    private func waitForTransaction(txHash: String) async throws {
        guard let url = URL(string: polygonRPC) else { throw WalletError.invalidURL }

        for _ in 0..<30 { // up to ~60 seconds
            try await Task.sleep(nanoseconds: 2_000_000_000)

            let params: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "eth_getTransactionReceipt",
                "params": [txHash],
                "id": 1
            ]

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: params)

            let (responseData, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                continue
            }

            // result is null while pending
            if let receipt = json["result"] as? [String: Any] {
                let status = receipt["status"] as? String
                if status == "0x1" {
                    return // Success
                } else {
                    throw WalletError.transactionFailed
                }
            }
        }

        throw WalletError.transactionTimeout
    }

    // MARK: - ERC-1155 Approval (Conditional Tokens)

    /// Check if the exchange is approved as an operator on the CTF contract
    func isApprovedForAll(owner: String, operator operatorAddr: String, contract: String) async throws -> Bool {
        // isApprovedForAll(address,address) selector = 0xe985e9c5
        let paddedOwner = owner.lowercased().replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        let paddedOperator = operatorAddr.lowercased().replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        let data = "0xe985e9c5" + paddedOwner + paddedOperator

        let params: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_call",
            "params": [
                ["to": contract, "data": data],
                "latest"
            ],
            "id": 1
        ]

        guard let url = URL(string: polygonRPC) else { throw WalletError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (responseData, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw WalletError.invalidResponse
        }

        if json["error"] != nil {
            return false
        }

        guard let result = json["result"] as? String else {
            return false
        }

        // Result is 0x...0001 for true, 0x...0000 for false
        let hexStr = result.replacingOccurrences(of: "0x", with: "")
        return hexStr.hasSuffix("1")
    }

    /// Call setApprovalForAll on an ERC-1155 contract to approve an operator
    func ensureApprovalForAll(
        wallet: EmbeddedEthereumWallet,
        operator operatorAddr: String,
        contract: String
    ) async throws {
        let approved = try await isApprovedForAll(owner: wallet.address, operator: operatorAddr, contract: contract)
        if approved { return }

        // setApprovalForAll(address,bool) selector = 0xa22cb465
        let paddedOperator = operatorAddr.lowercased().replacingOccurrences(of: "0x", with: "").leftPadded(toLength: 64, withPad: "0")
        let paddedTrue = "0000000000000000000000000000000000000000000000000000000000000001"
        let txData = "0xa22cb465" + paddedOperator + paddedTrue

        let transaction = EthereumRpcRequest.UnsignedEthTransaction(
            from: wallet.address,
            to: contract,
            data: txData,
            chainId: .hexadecimalNumber(chainId)
        )

        let txHash = try await wallet.provider.request(
            .ethSendTransaction(transaction: transaction)
        )
        try await waitForTransaction(txHash: txHash)
    }

    // MARK: - Sign Message

    func personalSign(
        wallet: EmbeddedEthereumWallet,
        message: String
    ) async throws -> String {
        let result = try await wallet.provider.request(
            .personalSign(message: message, address: wallet.address)
        )
        return result
    }
}

// MARK: - Errors

enum WalletError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noWallet
    case insufficientBalance
    case transactionFailed
    case transactionTimeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid RPC URL"
        case .invalidResponse: return "Invalid response from blockchain"
        case .noWallet: return "No wallet available"
        case .insufficientBalance: return "Insufficient balance"
        case .transactionFailed: return "Transaction failed on-chain"
        case .transactionTimeout: return "Transaction confirmation timed out"
        }
    }
}

// MARK: - Helpers

extension String {
    func leftPadded(toLength length: Int, withPad pad: Character) -> String {
        if count >= length { return self }
        return String(repeating: pad, count: length - count) + self
    }
}
