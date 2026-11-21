import UIKit

/// One haptic per moment in the settle flow, so each state change is felt on the phone.
enum Haptics {
    /// A message goes out normally.
    static func sent() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A message is held: a heavy hit, then a short rigid "crack" of ice.
    static func freeze() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task {
            try? await Task.sleep(for: .milliseconds(140))
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        }
    }

    /// A held message finally goes out.
    static func delivered() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Letting go: a soft, fading touch.
    static func dissolve() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// Small steps: a ritual page unlocking, a sentence thawing.
    static func tick() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
