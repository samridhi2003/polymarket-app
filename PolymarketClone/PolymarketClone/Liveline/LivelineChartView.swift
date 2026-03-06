import SwiftUI

struct LivelineChartView: View {
    let data: [LivelineDataPoint]
    let color: Color
    let lineWidth: CGFloat
    let showGradient: Bool
    let scrubEnabled: Bool

    @StateObject private var animator = LivelineAnimator()
    @State private var scrubLocation: CGFloat? = nil
    @State private var chartSize: CGSize = .zero

    init(
        data: [LivelineDataPoint],
        color: Color = .green,
        lineWidth: CGFloat = 2.5,
        showGradient: Bool = true,
        scrubEnabled: Bool = true
    ) {
        self.data = data
        self.color = color
        self.lineWidth = lineWidth
        self.showGradient = showGradient
        self.scrubEnabled = scrubEnabled
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // Canvas chart
                Canvas { context, canvasSize in
                    guard animator.displayPoints.count >= 2 else { return }
                    drawChart(context: context, size: canvasSize)
                }

                // Scrub overlay
                if scrubEnabled, let loc = scrubLocation {
                    scrubOverlay(at: loc, size: size)
                }
            }
            .contentShape(Rectangle())
            .gesture(scrubEnabled ? scrubGesture(in: size) : nil)
            .onAppear {
                chartSize = size
                let pts = mapToCanvas(data: data, size: size)
                animator.set(pts)
            }
            .onChange(of: data) { newData in
                chartSize = size
                let pts = mapToCanvas(data: newData, size: size)
                animator.animate(to: pts)
            }
            .onChange(of: size) { newSize in
                chartSize = newSize
                let pts = mapToCanvas(data: data, size: newSize)
                animator.set(pts)
            }
        }
    }

    // MARK: - Drawing

    private func drawChart(context: GraphicsContext, size: CGSize) {
        let points = animator.displayPoints
        let path = catmullRomPath(points: points)

        // Gradient fill
        if showGradient {
            var fillPath = path
            if let last = points.last, let first = points.first {
                fillPath.addLine(to: CGPoint(x: last.x, y: size.height))
                fillPath.addLine(to: CGPoint(x: first.x, y: size.height))
                fillPath.closeSubpath()
            }

            let gradient = Gradient(colors: [
                color.opacity(0.35),
                color.opacity(0.08),
                color.opacity(0.0)
            ])
            context.fill(
                fillPath,
                with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height))
            )
        }

        // Glow
        context.stroke(
            path,
            with: .color(color.opacity(0.3)),
            style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round, lineJoin: .round)
        )

        // Main line
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )

        // End dot
        if let last = points.last {
            let dotRadius: CGFloat = 4
            let dotRect = CGRect(
                x: last.x - dotRadius,
                y: last.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(color))

            // Outer glow ring
            let glowRadius: CGFloat = 7
            let glowRect = CGRect(
                x: last.x - glowRadius,
                y: last.y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )
            context.stroke(
                Path(ellipseIn: glowRect),
                with: .color(color.opacity(0.3)),
                style: StrokeStyle(lineWidth: 2)
            )
        }
    }

    // MARK: - Catmull-Rom Spline

    private func catmullRomPath(points: [CGPoint], alpha: CGFloat = 0.5) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }

        path.move(to: points[0])

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for i in 0..<points.count - 1 {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[min(i + 1, points.count - 1)]
            let p3 = points[min(i + 2, points.count - 1)]

            let d1 = distance(p0, p1)
            let d2 = distance(p1, p2)
            let d3 = distance(p2, p3)

            let d1a = pow(d1, alpha)
            let d2a = pow(d2, alpha)
            let d3a = pow(d3, alpha)

            var b1 = CGPoint.zero
            if d1a > 1e-6 && d2a > 1e-6 {
                b1 = CGPoint(
                    x: (d1a * d1a * p2.x - d2a * d2a * p0.x + (2 * d1a * d1a + 3 * d1a * d2a + d2a * d2a) * p1.x) / (3 * d1a * (d1a + d2a)),
                    y: (d1a * d1a * p2.y - d2a * d2a * p0.y + (2 * d1a * d1a + 3 * d1a * d2a + d2a * d2a) * p1.y) / (3 * d1a * (d1a + d2a))
                )
            } else {
                b1 = p1
            }

            var b2 = CGPoint.zero
            if d3a > 1e-6 && d2a > 1e-6 {
                b2 = CGPoint(
                    x: (d3a * d3a * p1.x - d2a * d2a * p3.x + (2 * d3a * d3a + 3 * d3a * d2a + d2a * d2a) * p2.x) / (3 * d3a * (d3a + d2a)),
                    y: (d3a * d3a * p1.y - d2a * d2a * p3.y + (2 * d3a * d3a + 3 * d3a * d2a + d2a * d2a) * p2.y) / (3 * d3a * (d3a + d2a))
                )
            } else {
                b2 = p2
            }

            path.addCurve(to: p2, control1: b1, control2: b2)
        }

        return path
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Data Mapping

    private func mapToCanvas(data: [LivelineDataPoint], size: CGSize) -> [CGPoint] {
        guard data.count >= 2 else {
            return data.map { _ in CGPoint(x: size.width / 2, y: size.height / 2) }
        }

        let padding: CGFloat = 8
        let times = data.map { $0.time.timeIntervalSince1970 }
        let values = data.map { $0.value }

        let minT = times.min()!
        let maxT = times.max()!
        let minV = values.min()!
        let maxV = values.max()!

        let tRange = maxT - minT
        let vRange = maxV - minV
        let effectiveVRange = vRange < 0.01 ? 1.0 : vRange

        return data.map { point in
            let x = padding + (tRange > 0
                ? CGFloat((point.time.timeIntervalSince1970 - minT) / tRange) * (size.width - padding * 2)
                : size.width / 2)
            let y = padding + CGFloat(1.0 - (point.value - minV) / effectiveVRange) * (size.height - padding * 2)
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Scrub

    private func scrubGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                scrubLocation = max(0, min(value.location.x, size.width))
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    scrubLocation = nil
                }
            }
    }

    private func scrubOverlay(at x: CGFloat, size: CGSize) -> some View {
        let scrubData = scrubValue(at: x, size: size)
        return ZStack {
            // Vertical line
            Rectangle()
                .fill(color.opacity(0.4))
                .frame(width: 1, height: size.height)
                .position(x: x, y: size.height / 2)

            // Dot on line
            if let point = scrubData.point {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                    .shadow(color: color.opacity(0.5), radius: 4)
                    .position(x: point.x, y: point.y)
            }

            // Value badge
            if let value = scrubData.value {
                Text(String(format: "%.1f%%", value))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.cornerRadius(6))
                    .position(
                        x: min(max(x, 30), size.width - 30),
                        y: max((scrubData.point?.y ?? 20) - 24, 14)
                    )
            }
        }
    }

    private func scrubValue(at x: CGFloat, size: CGSize) -> (value: Double?, point: CGPoint?) {
        let points = animator.displayPoints
        guard points.count >= 2 else { return (nil, nil) }

        // Find the two bracketing points
        var leftIdx = 0
        for i in 0..<points.count {
            if points[i].x <= x { leftIdx = i }
        }
        let rightIdx = min(leftIdx + 1, points.count - 1)

        let left = points[leftIdx]
        let right = points[rightIdx]

        let fraction: CGFloat
        if right.x - left.x > 0.01 {
            fraction = (x - left.x) / (right.x - left.x)
        } else {
            fraction = 0
        }

        let y = left.y + (right.y - left.y) * fraction
        let point = CGPoint(x: x, y: y)

        // Reverse map y → value
        guard data.count >= 2 else { return (nil, point) }
        let values = data.map { $0.value }
        let minV = values.min()!
        let maxV = values.max()!
        let vRange = maxV - minV
        let effectiveVRange = vRange < 0.01 ? 1.0 : vRange
        let padding: CGFloat = 8
        let normalizedY = (y - padding) / (size.height - padding * 2)
        let value = maxV - normalizedY * effectiveVRange

        return (value, point)
    }
}
