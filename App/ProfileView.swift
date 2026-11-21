import CalmCore
import SwiftUI

/// My profile, opened from the avatar at the top left of 聊天: a centred avatar
/// and name, a row of this week's numbers, my status, and what I've earned.
struct ProfileView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage("profileName") private var profileName = "我"
    @AppStorage("profileBio") private var bio = "说话之前，先想三遍。"
    @AppStorage("globalStatus") private var globalStatus = ChatStore.MyStatus.auto.rawValue
    @State private var editing = false

    var body: some View {
        let week = app.stats.stats(calendar: app.policy.calendar).weeks(endingAt: app.now).this
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        InitialAvatar(name: profileName, size: 96)
                            .padding(4)
                            .overlay(Circle().stroke(Theme.gradient, lineWidth: 3))
                        Text(profileName).font(.title.weight(.bold))
                        Text(bio).font(.subheadline).foregroundStyle(.secondary)
                        Label {
                            Text(status.label)
                        } icon: {
                            Image(systemName: status.symbol).foregroundStyle(Theme.brand)
                        }
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(Theme.brand.opacity(0.2)), in: .capsule)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 0) {
                        number("\(week.score)", "三思指数")
                        Divider().frame(height: 32)
                        number("\(week.count(.letGo))", "本周放下")
                        Divider().frame(height: 32)
                        number("\(week.count(.cooled))", "主动冷静")
                    }
                    .padding(.vertical, 14)
                    .background(.background.secondary, in: .rect(cornerRadius: 18))

                    HStack(spacing: 10) {
                        Button { editing = true } label: {
                            Text("编辑资料").frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .buttonStyle(.glassProminent)
                        ShareLink(item: "我在用 ThinkThrice：发送之前，先想三遍。") {
                            Image(systemName: "square.and.arrow.up").padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("我的状态").font(.headline)
                        Picker("我的状态", selection: $globalStatus) {
                            ForEach(ChatStore.MyStatus.allCases) { s in
                                Text(s.label).tag(s.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("对所有人显示；在某个聊天里也可以单独设置。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("成就").font(.headline)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                badge("第一次放下", "wind", earned: week.count(.letGo) > 0)
                                badge("改写高手", "pencil.and.scribble", earned: week.count(.rewroteCalm) >= 3)
                                badge("深夜不发", "moon.stars.fill", earned: week.count(.waitedSent) > 0)
                                badge("主动冷静", "snowflake", earned: week.count(.cooled) > 0)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .navigationTitle("个人主页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("编辑资料", isPresented: $editing) {
                TextField("名字", text: $profileName)
                TextField("签名", text: $bio)
                Button("好") {}
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

    private func badge(_ title: String, _ icon: String, earned: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(earned ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.tertiary))
                .frame(width: 56, height: 56)
                .glassEffect(.regular, in: .circle)
            Text(title).font(.caption).foregroundStyle(earned ? .primary : .secondary)
        }
        .frame(width: 84)
        .accessibilityElement(children: .combine)
        .accessibilityValue(earned ? "已获得" : "未获得")
    }
}
