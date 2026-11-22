import CalmCore
import SwiftUI

/// My profile, opened from the avatar at the top left of 聊天: a centred avatar
/// and name, a row of this week's numbers, my status, and what I've earned.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var profileName = tr("我", "Me")
    @AppStorage("profileBio") private var bio = tr("说话之前，先想三遍。", "Think three times before you speak.")
    @AppStorage("globalStatus") private var globalStatus = ChatStore.MyStatus.auto.rawValue
    @State private var editing = false

    var body: some View {
        let week = app.stats.stats(calendar: app.policy.calendar).weeks(endingAt: app.now).this
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        InitialAvatar(name: profileName, image: InitialAvatar.me, size: 96)
                            .padding(4)
                            .overlay(Circle().stroke(Theme.gradient, lineWidth: 3))
                        Text(profileName).font(.title.weight(.bold))
                        Text(bio).font(.subheadline).foregroundStyle(.secondary)
                        Label {
                            Text(status.label)
                        } icon: {
                            Image(systemName: status.symbol).foregroundStyle(status.color)
                        }
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(Theme.brand.opacity(0.2)), in: .capsule)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 0) {
                        number("\(week.score)", tr("三思指数", "ThinkThrice score"))
                        Divider().frame(height: 32)
                        number("\(week.count(.letGo))", tr("本周放下", "Let go this week"))
                        Divider().frame(height: 32)
                        number("\(week.count(.cooled))", tr("主动冷静", "Cooldowns"))
                    }
                    .padding(.vertical, 14)
                    .background(.background.secondary, in: .rect(cornerRadius: 18))

                    HStack(spacing: 10) {
                        Button { editing = true } label: {
                            Text(tr("编辑资料", "Edit profile")).frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .buttonStyle(.glassProminent)
                        ShareLink(item: tr("我在用 ThinkThrice：发送之前，先想三遍。", "I use ThinkThrice: think three times before you send."), preview: SharePreview("ThinkThrice", image: Image("logo"))) {
                            Image(systemName: "square.and.arrow.up").padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("我的状态", "My status")).font(.headline)
                        Picker(tr("我的状态", "My status"), selection: $globalStatus) {
                            ForEach(ChatStore.MyStatus.allCases) { s in
                                Text(s.label).tag(s.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text(tr("对所有人显示；在某个聊天里也可以单独设置。", "Shown to everyone; you can also set it per chat."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("成就", "Badges")).font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                badge(tr("第一次放下", "First let-go"), "wind", earned: week.count(.letGo) > 0)
                                badge(tr("改写高手", "Rewriter"), "pencil.and.scribble", earned: week.count(.rewroteCalm) >= 3)
                                badge(tr("深夜不发", "Slept on it"), "moon.stars.fill", earned: week.count(.waitedSent) > 0)
                                badge(tr("主动冷静", "Cooldowns"), "snowflake", earned: week.count(.cooled) > 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .navigationTitle(tr("个人主页", "Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("完成", "Done")) { dismiss() }
                }
            }
            .alert(tr("编辑资料", "Edit profile"), isPresented: $editing) {
                TextField(tr("名字", "Name"), text: $profileName)
                TextField(tr("签名", "Bio"), text: $bio)
                Button(tr("好", "OK")) {}
            }
        }
    }

    private var status: ChatStore.MyStatus { ChatStore.MyStatus(rawValue: globalStatus) ?? .auto }

    private func number(_ value: String, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Tappable, with press feedback, but there is no badge detail page yet.
    private func badge(_ title: String, _ icon: String, earned: Bool) -> some View {
        Button { Haptics.tick() } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(earned ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.tertiary))
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.interactive(), in: .circle)
                Text(title).font(.caption).foregroundStyle(earned ? .primary : .secondary)
            }
            .frame(width: 84)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(earned ? tr("已获得", "Earned") : tr("未获得", "Not earned yet"))
    }
}
