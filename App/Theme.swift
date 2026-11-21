import SwiftUI

/// ThinkThrice's one brand colour, the indigo-violet of the night sky and the
/// header avatar. Sent bubbles, the tint, avatars and charts all use it.
enum Theme {
    static let brand = Color(red: 0.39, green: 0.33, blue: 0.93)
    static let brandDeep = Color(red: 0.27, green: 0.20, blue: 0.75)
    static let gradient = LinearGradient(colors: [Color(red: 0.52, green: 0.43, blue: 1), brandDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    /// Held messages and everything about freezing.
    static let ice = Color(red: 0.45, green: 0.82, blue: 0.98)
}

/// An initial in a brand-coloured circle, used for contacts and for me.
struct InitialAvatar: View {
    let name: String
    var size: CGFloat = 46

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Theme.gradient, in: .circle)
            .accessibilityHidden(true)
    }
}
