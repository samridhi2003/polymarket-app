import SwiftUI

/// Breathing sine wave animation shown while chart data is loading.
struct LivelineLoadingView: View {
    let color: Color
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let animPhase = CGFloat(time) * 2.0

                for wave in 0..<3 {
                    let opacity = 0.3 - Double(wave) * 0.08
                    let waveOffset = CGFloat(wave) * 0.7
                    let amplitude = size.height * (0.08 + CGFloat(wave) * 0.03)

                    var path = Path()
                    let steps = Int(size.width / 2)
                    for step in 0...steps {
                        let x = CGFloat(step) / CGFloat(steps) * size.width
                        let normalizedX = x / size.width * .pi * 3
                        let y = size.height / 2 + sin(normalizedX + animPhase + waveOffset) * amplitude
                        if step == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    context.stroke(
                        path,
                        with: .color(color.opacity(opacity)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                }
            }
        }
    }
}
