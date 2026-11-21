import SwiftUI

/// The chat's backdrop follows the demo clock: a pale day sky, and at night a deep
/// blue sky with twinkling stars, so jumping the clock to 1:30 is visible at a glance.
struct ChatAtmosphere: View {
    let night: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [.blue.opacity(0.08), .clear], startPoint: .top, endPoint: .center)
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.05, blue: 0.16), Color(red: 0.10, green: 0.11, blue: 0.30)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(colors: [Color(red: 0.55, green: 0.65, blue: 1).opacity(0.22), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
                StarField()
            }
            .opacity(night ? 1 : 0)
        }
        .accessibilityHidden(true)
    }
}

/// Stars at fixed pseudo-random spots in the top two thirds, each twinkling at its own pace.
private struct StarField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let count = 70

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                for i in 0..<Self.count {
                    let x = noise(i, 1) * size.width
                    let y = noise(i, 2) * size.height * 0.68
                    let radius = 0.6 + noise(i, 3) * 1.4
                    let twinkle = reduceMotion ? 1 : 0.55 + 0.45 * sin(t * (0.6 + noise(i, 4) * 1.6) + noise(i, 5) * 6.28)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    canvas.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.85 * twinkle)))
                }
            }
        }
    }
}

/// A stable value in 0..<1 for (index, salt), so the stars and particles keep their places between frames.
nonisolated func noise(_ index: Int, _ salt: Int) -> Double {
    let x = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453
    return x - x.rounded(.down)
}
