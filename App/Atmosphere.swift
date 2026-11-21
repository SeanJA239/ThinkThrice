import SwiftUI

/// The chat's backdrop follows the demo clock: a pale sky by day and a deep
/// violet night sky at night. Snow falls only while a message in the chat is
/// frozen, so the weather says whether anything is still settling.
struct ChatAtmosphere: View {
    let night: Bool
    let snowing: Bool

    var body: some View {
        ZStack {
            Color(.systemBackground)
            LinearGradient(colors: [Theme.brand.opacity(0.08), .clear], startPoint: .top, endPoint: .center)
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.04, blue: 0.17), Color(red: 0.15, green: 0.11, blue: 0.36)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(colors: [Theme.brand.opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 280)
            }
            .opacity(night ? 1 : 0)
            SnowFall(color: night ? .white : Theme.ice)
                .opacity(snowing ? 1 : 0)
                .animation(.easeInOut(duration: 1.5), value: snowing)
        }
        .accessibilityHidden(true)
    }
}

/// Flakes that drift down and sway, each at its own speed, looping forever.
private struct SnowFall: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let color: Color
    private static let count = 60

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                for i in 0..<Self.count {
                    let speed = 18 + noise(i, 1) * 30
                    let radius = 1 + noise(i, 2) * 2.4
                    let fall = (noise(i, 3) * size.height + t * speed).truncatingRemainder(dividingBy: size.height + 20) - 10
                    let sway = sin(t * (0.4 + noise(i, 4)) + noise(i, 5) * 6.28) * (6 + noise(i, 6) * 10)
                    let x = noise(i, 7) * size.width + sway
                    let rect = CGRect(x: x - radius, y: fall - radius, width: radius * 2, height: radius * 2)
                    canvas.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.35 + 0.5 * noise(i, 8))))
                }
            }
        }
    }
}

/// A stable value in 0..<1 for (index, salt), so particles keep their places between frames.
nonisolated func noise(_ index: Int, _ salt: Int) -> Double {
    let x = sin(Double(index) * 12.9898 + Double(salt) * 78.233) * 43758.5453
    return x - x.rounded(.down)
}
