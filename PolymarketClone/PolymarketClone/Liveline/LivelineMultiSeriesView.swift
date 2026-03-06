import SwiftUI

/// Displays multiple Liveline chart series stacked in the same frame,
/// with a shared Y-axis (0–100%) and optional scrubbing.
struct LivelineMultiSeriesView: View {
    let series: [(label: String, data: [LivelineDataPoint], color: Color)]
    let isLoading: Bool
    let height: CGFloat

    @State private var scrubX: CGFloat? = nil
    @State private var viewSize: CGSize = .zero

    init(
        series: [(label: String, data: [LivelineDataPoint], color: Color)],
        isLoading: Bool = false,
        height: CGFloat = 200
    ) {
        self.series = series
        self.isLoading = isLoading
        self.height = height
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if isLoading {
                LivelineLoadingView(color: series.first?.color ?? .green)
                    .frame(height: height)
            } else if series.isEmpty || series.allSatisfy({ $0.data.isEmpty }) {
                Text("No chart data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            } else {
                GeometryReader { geo in
                    let size = geo.size

                    // Y-axis labels
                    yAxisLabels(size: size)

                    // Chart area (inset for y-axis)
                    ZStack {
                        // Grid lines
                        gridLines(size: CGSize(width: size.width - 32, height: size.height))

                        // Each series
                        ForEach(Array(series.enumerated()), id: \.offset) { _, s in
                            if !s.data.isEmpty {
                                LivelineChartView(
                                    data: normalizeToSharedScale(s.data),
                                    color: s.color,
                                    lineWidth: 2.5,
                                    showGradient: series.count == 1,
                                    scrubEnabled: false
                                )
                            }
                        }

                        // Shared scrub gesture
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in scrubX = v.location.x }
                                    .onEnded { _ in
                                        withAnimation(.easeOut(duration: 0.2)) { scrubX = nil }
                                    }
                            )

                        // Scrub line + badges
                        if let x = scrubX {
                            scrubOverlay(at: x, size: CGSize(width: size.width - 32, height: size.height))
                        }
                    }
                    .padding(.leading, 32)
                    .onAppear { viewSize = size }
                    .onChange(of: size) { viewSize = $0 }
                }
                .frame(height: height)
            }
        }
    }

    // MARK: - Y Axis

    private func yAxisLabels(size: CGSize) -> some View {
        ForEach([0, 25, 50, 75, 100], id: \.self) { value in
            let padding: CGFloat = 8
            let y = padding + CGFloat(1.0 - Double(value) / 100.0) * (size.height - padding * 2)
            Text("\(value)")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .position(x: 14, y: y)
        }
    }

    // MARK: - Grid

    private func gridLines(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let padding: CGFloat = 8
            for value in [0, 25, 50, 75, 100] {
                let y = padding + CGFloat(1.0 - Double(value) / 100.0) * (canvasSize.height - padding * 2)
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: canvasSize.width, y: y))
                context.stroke(line, with: .color(.secondary.opacity(0.15)), style: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }
        }
    }

    // MARK: - Shared Scale

    /// Normalize data so the chart always maps 0–100 on the Y axis.
    private func normalizeToSharedScale(_ data: [LivelineDataPoint]) -> [LivelineDataPoint] {
        // Values are already in 0–100% range from PricePoint conversion
        return data
    }

    // MARK: - Scrub Overlay

    private func scrubOverlay(at x: CGFloat, size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: size.height)
                .position(x: x, y: size.height / 2)

            // Show value badges for each series
            ForEach(Array(series.enumerated()), id: \.offset) { idx, s in
                if !s.data.isEmpty, let value = interpolatedValue(at: x, data: s.data, chartWidth: size.width) {
                    let padding: CGFloat = 8
                    let y = padding + CGFloat(1.0 - value / 100.0) * (size.height - padding * 2)

                    Circle()
                        .fill(s.color)
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)

                    Text(String(format: "%.0f%%", value))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(s.color.cornerRadius(4))
                        .position(
                            x: min(max(x, 28), size.width - 28),
                            y: max(y - 18 - CGFloat(idx) * 20, 10)
                        )
                }
            }
        }
    }

    private func interpolatedValue(at x: CGFloat, data: [LivelineDataPoint], chartWidth: CGFloat) -> Double? {
        guard data.count >= 2 else { return data.first?.value }

        let padding: CGFloat = 8
        let times = data.map { $0.time.timeIntervalSince1970 }
        let minT = times.min()!
        let maxT = times.max()!
        let tRange = maxT - minT
        guard tRange > 0 else { return data.first?.value }

        // Convert x position back to time
        let fraction = Double((x - padding) / (chartWidth - padding * 2))
        let targetTime = minT + fraction * tRange

        // Find bracketing points
        var leftIdx = 0
        for i in 0..<data.count {
            if data[i].time.timeIntervalSince1970 <= targetTime {
                leftIdx = i
            }
        }
        let rightIdx = min(leftIdx + 1, data.count - 1)

        let leftT = data[leftIdx].time.timeIntervalSince1970
        let rightT = data[rightIdx].time.timeIntervalSince1970
        let range = rightT - leftT

        let lerp: Double
        if range > 0 {
            lerp = (targetTime - leftT) / range
        } else {
            lerp = 0
        }

        return data[leftIdx].value + (data[rightIdx].value - data[leftIdx].value) * lerp
    }
}
