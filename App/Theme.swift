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

/// A round avatar: the 3D cartoon portrait in `Assets.xcassets/avatar-<id>` when
/// there is one (me, 前任, 老板, 组员), otherwise the name's initial in a
/// brand-coloured circle. Apple doesn't let apps generate or read Memoji, so to
/// use a real one, export a Memoji sticker as an image and replace `avatar-<id>`.
struct InitialAvatar: View {
    let name: String
    var image: String?
    var size: CGFloat = 46

    var body: some View {
        Group {
            if let image, UIImage(named: image) != nil {
                Image(image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    /// My own portrait.
    static let me = "avatar-me"

    /// A conversation's portrait, by conversation id.
    static func image(for store: ChatStore) -> String { "avatar-\(store.id)" }
}
