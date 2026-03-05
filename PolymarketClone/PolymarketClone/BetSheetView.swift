import SwiftUI

struct BetSheetView: View {
    let market: Market
    let initialOutcome: String
    var eventTitle: String = ""
    @ObservedObject var viewModel: MarketViewModel
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedOutcome: String = ""
    @State private var betAmount = ""
    @State private var isPlacingBet = false
    @State private var betPlaced = false
    @State private var errorMsg: String?

    private var outcomes: [String] {
        market.parsedOutcomes
    }

    private var selectedToken: Token? {
        market.tokens.first(where: { $0.outcome == selectedOutcome })
    }

    private var potentialPayout: Double {
        guard let amount = Double(betAmount), let token = selectedToken, token.price > 0 else { return 0 }
        return amount / token.price
    }

    private var profit: Double {
        guard let amount = Double(betAmount) else { return 0 }
        return potentialPayout - amount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        if betPlaced {
                            successView
                        } else {
                            betFormView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(eventTitle.isEmpty ? market.question : eventTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            selectedOutcome = initialOutcome
        }
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(selectedOutcome == "Yes" ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(selectedOutcome == "Yes" ? .green : .red)
            }

            VStack(spacing: 6) {
                Text("Bet Placed!")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("$\(betAmount) on \(selectedOutcome)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                summaryRow(label: "Outcome", value: selectedOutcome, color: selectedOutcome == "Yes" ? .green : .red)
                summaryRow(label: "Amount", value: "$\(betAmount)")
                if let token = selectedToken {
                    summaryRow(label: "Price", value: "\(Int(token.price * 100))¢")
                }
                summaryRow(label: "Potential Return", value: "$\(String(format: "%.2f", potentialPayout))", color: .green)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.body)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Bet Form

    private var betFormView: some View {
        VStack(spacing: 16) {
            // Outcome toggle
            outcomePicker

            // Price cards
            priceCards

            // Amount input
            amountSection

            // Quick amounts
            quickAmounts

            // Payout summary
            if potentialPayout > 0 {
                payoutSummary
            }

            // Error
            if let error = errorMsg {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            }

            // Confirm button
            confirmButton
        }
    }

    // MARK: - Outcome Picker

    private var outcomePicker: some View {
        HStack(spacing: 0) {
            ForEach(outcomes, id: \.self) { outcome in
                let isSelected = selectedOutcome == outcome
                let isYes = outcome == "Yes"

                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectedOutcome = outcome
                        errorMsg = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isYes ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text(outcome)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        isSelected
                            ? (isYes ? Color.green : Color.red)
                            : Color.clear
                    )
                    .foregroundStyle(isSelected ? .white : .secondary)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Price Cards

    private var priceCards: some View {
        HStack(spacing: 10) {
            ForEach(market.tokens) { token in
                let isSelected = token.outcome == selectedOutcome
                let isYes = token.outcome == "Yes"

                VStack(spacing: 4) {
                    Text(token.outcome)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? (isYes ? .green : .red) : .secondary)
                    Text("\(Int(token.price * 100))¢")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                    Text("\(Int(token.price * 100))% chance")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    isSelected ? (isYes ? Color.green.opacity(0.5) : Color.red.opacity(0.5)) : .clear,
                                    lineWidth: 1.5
                                )
                        )
                )
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.25)) {
                        selectedOutcome = token.outcome
                        errorMsg = nil
                    }
                }
            }
        }
    }

    // MARK: - Amount

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Amount")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("Balance: $\(String(format: "%.2f", viewModel.usdcBalance))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                Text("$")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 14)

                TextField("0.00", text: $betAmount)
                    .font(.title3)
                    .fontWeight(.medium)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .padding(.vertical, 14)
                    .padding(.leading, 4)

                if !betAmount.isEmpty {
                    Button {
                        betAmount = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.trailing, 14)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Quick Amounts

    private var quickAmounts: some View {
        HStack(spacing: 8) {
            ForEach([1, 5, 10, 20], id: \.self) { amount in
                Button {
                    betAmount = "\(amount)"
                } label: {
                    Text("$\(amount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            betAmount == "\(amount)"
                                ? (selectedOutcome == "Yes" ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                : Color(.secondarySystemGroupedBackground)
                        )
                        .foregroundStyle(
                            betAmount == "\(amount)"
                                ? (selectedOutcome == "Yes" ? .green : .red)
                                : .secondary
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Button {
                betAmount = String(format: "%.0f", viewModel.usdcBalance)
            } label: {
                Text("Max")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
    }

    // MARK: - Payout Summary

    private var payoutSummary: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Avg price")
                Spacer()
                if let token = selectedToken {
                    Text("\(String(format: "%.1f", token.price * 100))¢")
                        .fontWeight(.medium)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack {
                Text("Shares")
                Spacer()
                Text(String(format: "%.2f", potentialPayout))
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Divider()

            HStack {
                Text("Potential return")
                    .fontWeight(.medium)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(String(format: "%.2f", potentialPayout))")
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    if let amount = Double(betAmount), amount > 0 {
                        Text("(\(String(format: "%.0f", (profit / amount) * 100))%)")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Confirm Button

    private var confirmButton: some View {
        let isYes = selectedOutcome == "Yes"
        let accentColor: Color = isYes ? .green : .red
        let isDisabled = betAmount.isEmpty || Double(betAmount) == nil || isPlacingBet

        return Button {
            Task { await placeBet() }
        } label: {
            HStack(spacing: 8) {
                if isPlacingBet {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: isYes ? "arrow.up.right" : "arrow.down.right")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Buy \(selectedOutcome)")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isDisabled ? Color.gray.opacity(0.3) : accentColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isDisabled)
        .padding(.top, 4)
    }

    // MARK: - Summary Row

    private func summaryRow(label: String, value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }

    // MARK: - Place Bet

    func placeBet() async {
        guard let amount = Double(betAmount), amount > 0, let token = selectedToken else { return }

        isPlacingBet = true
        errorMsg = nil

        guard let wallet = auth.embeddedWallet else {
            errorMsg = "No wallet connected. Please log in first."
            isPlacingBet = false
            return
        }

        // Check balance
        if amount > viewModel.usdcBalance {
            errorMsg = "Insufficient USDC balance. You have $\(String(format: "%.2f", viewModel.usdcBalance))."
            isPlacingBet = false
            return
        }

        do {
            try await viewModel.placeOrder(
                wallet: wallet,
                eventTitle: eventTitle.isEmpty ? market.question : eventTitle,
                market: market,
                outcome: selectedOutcome,
                amount: amount,
                price: token.price
            )
            betPlaced = true
        } catch {
            print("[BetSheet] Order failed: \(error)")
            errorMsg = error.localizedDescription
        }

        isPlacingBet = false
    }
}
