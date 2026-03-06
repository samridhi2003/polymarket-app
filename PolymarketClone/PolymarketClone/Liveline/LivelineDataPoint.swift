import Foundation

/// A single data point for the Liveline chart.
struct LivelineDataPoint: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let value: Double

    static func == (lhs: LivelineDataPoint, rhs: LivelineDataPoint) -> Bool {
        lhs.time == rhs.time && lhs.value == rhs.value
    }
}

/// Convenience to convert PricePoint → LivelineDataPoint
extension PricePoint {
    var livelinePoint: LivelineDataPoint {
        LivelineDataPoint(time: date, value: p * 100) // convert 0-1 → 0-100%
    }
}
