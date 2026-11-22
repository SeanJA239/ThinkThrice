import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ThinkThriceWidgets: WidgetBundle {
    var body: some Widget {
        HeldLiveActivity()
    }
}

/// `Theme.ice` in the app.
private let ice = Color(red: 0.45, green: 0.82, blue: 0.98)

/// Held messages in the Dynamic Island and on the Lock Screen: a snowflake and
/// the countdown while they cool down, a seal and 「好了」 once they're ready.
/// Tapping opens the app; letting go or sending still goes through the chat.
struct HeldLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HeldActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.08, green: 0.07, blue: 0.2).opacity(0.85))
                .activitySystemActionForegroundColor(ice)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StateIcon(ready: context.isReady)
                        .font(.title2)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(context: context)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                StateIcon(ready: context.isReady)
            } compactTrailing: {
                Countdown(context: context)
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .frame(maxWidth: 56)
            } minimal: {
                StateIcon(ready: context.isReady)
            }
            .keylineTint(ice)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<HeldActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            StateIcon(ready: context.isReady)
                .font(.title2)
                .frame(width: 46, height: 46)
                .background(ice.opacity(0.18), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.title).font(.headline)
                Text(context.subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Countdown(context: context)
                .font(.title2.monospacedDigit().weight(.semibold))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

/// A snowflake while cooling, a seal once ready; swapping between them is the island's animation.
private struct StateIcon: View {
    let ready: Bool

    var body: some View {
        Image(systemName: ready ? "checkmark.seal.fill" : "snowflake")
            .foregroundStyle(ice)
            .contentTransition(.symbolEffect(.replace))
    }
}

/// Counts down on its own, without updates from the app; 「好了」 once it's done.
private struct Countdown: View {
    let context: ActivityViewContext<HeldActivityAttributes>

    var body: some View {
        if !context.isReady, let readyAt = context.state.readyAt {
            Text(timerInterval: Date.now...readyAt, countsDown: true)
        } else {
            Text(context.attributes.english ? "Ready" : "好了").foregroundStyle(ice)
        }
    }
}

private extension ActivityViewContext<HeldActivityAttributes> {
    var isReady: Bool {
        guard let readyAt = state.readyAt else { return true }
        return isStale || readyAt <= .now
    }

    var title: String { attributes.english ? "\(state.heldCount) message\(state.heldCount == 1 ? "" : "s") to \(attributes.peerName)" : "给\(attributes.peerName)的 \(state.heldCount) 条消息" }

    var subtitle: String {
        attributes.english
            ? (isReady ? "Cooled down. Come back for a look" : "Cooling down. No rush to send")
            : (isReady ? "冷静好了，回来再看一眼" : "正在冷静，先别急着发")
    }
}
