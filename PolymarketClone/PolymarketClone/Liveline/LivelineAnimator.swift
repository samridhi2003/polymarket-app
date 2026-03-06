import SwiftUI
import Combine

/// Drives smooth interpolation between old and new data sets at 60fps.
final class LivelineAnimator: ObservableObject {
    @Published var displayPoints: [CGPoint] = []
    @Published var progress: Double = 1.0

    private var fromPoints: [CGPoint] = []
    private var toPoints: [CGPoint] = []
    private var displayLink: CADisplayLink?
    private var animationStart: CFTimeInterval = 0
    private let animationDuration: CFTimeInterval = 0.45

    deinit {
        displayLink?.invalidate()
    }

    /// Animate from current displayed points to new target points.
    func animate(to newPoints: [CGPoint]) {
        fromPoints = displayPoints.isEmpty ? newPoints : displayPoints
        toPoints = normalizeCount(from: fromPoints, to: newPoints)
        fromPoints = normalizeCount(from: toPoints, to: fromPoints)

        progress = 0
        animationStart = CACurrentMediaTime()

        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    /// Immediately set points without animation.
    func set(_ points: [CGPoint]) {
        displayLink?.invalidate()
        displayLink = nil
        displayPoints = points
        progress = 1.0
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - animationStart
        let t = min(elapsed / animationDuration, 1.0)
        let eased = easeInOutCubic(t)

        displayPoints = zip(fromPoints, toPoints).map { from, to in
            CGPoint(
                x: from.x + (to.x - from.x) * eased,
                y: from.y + (to.y - from.y) * eased
            )
        }

        progress = eased

        if t >= 1.0 {
            displayLink?.invalidate()
            displayLink = nil
            displayPoints = toPoints
            progress = 1.0
        }
    }

    private func easeInOutCubic(_ t: Double) -> Double {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    /// Make both arrays the same count by linearly interpolating the shorter one.
    private func normalizeCount(from source: [CGPoint], to target: [CGPoint]) -> [CGPoint] {
        guard !source.isEmpty else { return target }
        if source.count == target.count { return source }

        var result: [CGPoint] = []
        let targetCount = target.count
        for i in 0..<targetCount {
            let fraction = Double(i) / Double(max(targetCount - 1, 1))
            let srcIndex = fraction * Double(max(source.count - 1, 1))
            let lower = Int(srcIndex)
            let upper = min(lower + 1, source.count - 1)
            let lerp = srcIndex - Double(lower)
            let pt = CGPoint(
                x: source[lower].x + (source[upper].x - source[lower].x) * lerp,
                y: source[lower].y + (source[upper].y - source[lower].y) * lerp
            )
            result.append(pt)
        }
        return result
    }
}
