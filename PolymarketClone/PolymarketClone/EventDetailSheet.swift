import SwiftUI
import Charts

struct EventDetailSheet: View {
    let event: Event
    @ObservedObject var viewModel: MarketViewModel
    @Environment(\.dismiss) var dismiss
    @State private var priceHistories: [String: [PricePoint]] = [:]
    @State private var isLoadingChart = true
    @State private var selectedTimeRange = "1W"
    @State private var selectedMarketForBet: Market? = nil
    @State private var selectedOutcomeForBet: String? = nil
    @State private var showBetSheet = false

    let timeRanges = ["1D", "1W", "1M", "6M"]
    private let chartColors: [Color] = [.green, .red, .blue, .orange, .purple, .cyan]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    legendSection
                    chartSection
                    timeRangePicker
                    Divider().padding(.horizontal, 16)
                    outcomesSection
                }
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
            .sheet(isPresented: $showBetSheet) {
                if let market = selectedMarketForBet, let outcome = selectedOutcomeForBet {
                    BetSheetView(
                        market: market,
                        initialOutcome: outcome,
                        eventTitle: event.title,
                        viewModel: viewModel
                    )
                }
            }
        }
        .task { await loadPriceHistories() }
        .onChange(of: selectedTimeRange) { _ in
            Task { await loadPriceHistories() }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let tag = event.primaryTag {
                Text(tag.label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                    Text(event.formattedVolume)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Legend
    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(event.displayOutcomes.prefix(3).enumerated()), id: \.offset) { index, item in
                HStack(spacing: 6) {
                    Circle()
                        .fill(chartColors[index % chartColors.count])
                        .frame(width: 7, height: 7)
                    Text("\(item.displayName):")
                        .font(.subheadline)
                    Text("\(Int(item.price * 100))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Chart
    private var chartSection: some View {
        Group {
            if isLoadingChart {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else if priceHistories.isEmpty {
                Text("No chart data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            } else {
                chartView
            }
        }
    }

    private var chartView: some View {
        Chart {
            ForEach(Array(priceHistories.enumerated()), id: \.offset) { index, entry in
                let color = chartColors[index % chartColors.count]
                ForEach(entry.value) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Price", point.p * 100)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
                // End point dot + label
                if let last = entry.value.last {
                    PointMark(
                        x: .value("Time", last.date),
                        y: .value("Price", last.p * 100)
                    )
                    .foregroundStyle(color)
                    .symbolSize(30)
                    .annotation(position: .trailing, spacing: 4) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(entry.key)
                                .font(.system(size: 9))
                                .foregroundColor(color)
                                .lineLimit(1)
                            Text("\(Int(last.p * 100))%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(color)
                        }
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 9))
            }
        }
        .frame(height: 200)
        .padding(.leading, 16)
        .padding(.trailing, 60)
    }

    // MARK: - Time Range
    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(timeRanges, id: \.self) { range in
                Button {
                    selectedTimeRange = range
                } label: {
                    Text(range)
                        .font(.footnote)
                        .fontWeight(selectedTimeRange == range ? .bold : .regular)
                        .foregroundColor(selectedTimeRange == range ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(selectedTimeRange == range ? Color(.tertiarySystemBackground) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Outcomes
    private var outcomesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Outcomes")
                    .font(.headline)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            LazyVStack(spacing: 0) {
                ForEach(Array(event.displayOutcomes.enumerated()), id: \.offset) { _, item in
                    Button {
                        selectedMarketForBet = item.market
                        selectedOutcomeForBet = item.outcome
                        showBetSheet = true
                    } label: {
                        outcomeRow(
                            imageURL: item.market.image,
                            name: item.displayName,
                            price: item.price
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 60)
                }
            }
        }
    }

    private func outcomeRow(imageURL: String?, name: String, price: Double) -> some View {
        HStack(spacing: 10) {
            if let imageURL = imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle().fill(Color.gray.opacity(0.15))
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 36, height: 36)
            }

            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Text("\(Int(price * 100))%")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Data
    private var apiInterval: String {
        switch selectedTimeRange {
        case "1D": return "1d"
        case "1W": return "1w"
        case "1M": return "1m"
        case "6M": return "6m"
        default: return "1w"
        }
    }

    private func loadPriceHistories() async {
        isLoadingChart = true
        guard let markets = event.markets else {
            isLoadingChart = false
            return
        }

        let topMarkets = Array(markets.prefix(3))
        var histories: [String: [PricePoint]] = [:]

        for market in topMarkets {
            guard let tokenId = market.firstTokenId else { continue }
            let label = market.shortLabel ?? market.parsedOutcomes.first ?? market.question
            do {
                let points = try await NetworkService.shared.fetchPriceHistory(
                    tokenId: tokenId,
                    interval: apiInterval
                )
                if !points.isEmpty {
                    histories[label] = points
                }
            } catch {
                // Skip markets with no price history
            }
        }

        priceHistories = histories
        isLoadingChart = false
    }
}
