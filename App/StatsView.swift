import CalmCore
import Charts
import SwiftUI

/// 「三思」: progress in thinking twice. Holding fewer messages, and rewriting,
/// waiting or letting go of the held ones, all count as progress. The page opens
/// with the week in words (`ThinkReview`), then highlights, then the numbers.
struct StatsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let _ = app.clockRevision
        let stats = app.stats.stats(calendar: app.policy.calendar)
        let weeks = stats.weeks(endingAt: app.now)
        let days = stats.daily(days: 14, endingAt: app.now)
        let review = stats.review(endingAt: app.now)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ReviewCard(review: review)
                    if !review.insights.isEmpty {
                        SectionTitle("亮点")
                        VStack(spacing: 10) {
                            ForEach(review.insights, id: \.kind) { InsightRow(insight: $0) }
                        }
                    }
                    SectionTitle("数据")
                    ScoreCard(this: weeks.this, last: weeks.last)
                    tiles(this: weeks.this, last: weeks.last)
                    DailyChart(days: days)
                    ExitsCard(summary: weeks.this)
                    if app.stats.seededExample {
                        Text("前 14 天是示例数据，方便演示；可以在「设置」里清除。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("三思")
        }
    }

    private func tiles(this: ThinkStats.Summary, last: ThinkStats.Summary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            StatTile(title: "被冻住", value: this.count(.held), last: last.count(.held), icon: "snowflake", fewerIsBetter: true)
            StatTile(title: "改写", value: this.count(.rewroteCalm) + this.count(.rewroteStill), last: last.count(.rewroteCalm) + last.count(.rewroteStill), icon: "pencil.and.scribble")
            StatTile(title: "放下", value: this.count(.letGo), last: last.count(.letGo), icon: "wind")
            StatTile(title: "冷静 / 等到早上", value: this.count(.cooled) + this.count(.waitedSent), last: last.count(.cooled) + last.count(.waitedSent), icon: "moon.zzz")
        }
    }
}

/// The week's 「三思指数」 as a ring, with the change from last week.
private struct ScoreCard: View {
    let this: ThinkStats.Summary
    let last: ThinkStats.Summary

    var body: some View {
        let delta = this.score - last.score
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Theme.brand.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: Double(this.score) / 100)
                    .stroke(Theme.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(this.score)").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("三思指数").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 6) {
                Text("本周").font(.subheadline).foregroundStyle(.secondary)
                Label(delta >= 0 ? "比上周 +\(delta)" : "比上周 \(delta)", systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.headline)
                    .foregroundStyle(delta >= 0 ? .green : .orange)
                Text("放下、改写和等待越多，指数越高。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(.background, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

private struct StatTile: View {
    let title: String
    let value: Int
    let last: Int
    let icon: String
    var fewerIsBetter = false

    var body: some View {
        let better = fewerIsBetter ? value <= last : value >= last
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(value)").font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(value == last ? "和上周一样" : "上周 \(last)")
                .font(.caption)
                .foregroundStyle(value == last ? AnyShapeStyle(.secondary) : better ? AnyShapeStyle(.green) : AnyShapeStyle(.orange))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.background, in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}

/// Messages written per day for two weeks: sent straight away, or frozen.
private struct DailyChart: View {
    let days: [(day: Date, summary: ThinkStats.Summary)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近 14 天").font(.headline)
            Chart {
                ForEach(days, id: \.day) { day in
                    BarMark(x: .value("日期", day.day, unit: .day), y: .value("条数", day.summary.count(.sentDirectly)))
                        .foregroundStyle(by: .value("类型", "直接发出"))
                    BarMark(x: .value("日期", day.day, unit: .day), y: .value("条数", day.summary.count(.held)))
                        .foregroundStyle(by: .value("类型", "被冻住"))
                }
            }
            .chartForegroundStyleScale(["直接发出": Theme.brand.opacity(0.35), "被冻住": Theme.ice])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                }
            }
            .frame(height: 170)
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 22))
    }
}

/// How this week's frozen messages ended, most reflective first.
private struct ExitsCard: View {
    let summary: ThinkStats.Summary

    var body: some View {
        let rows: [(String, Int, Color)] = [
            ("放下", summary.count(.letGo), .green),
            ("改写后发出", summary.count(.rewroteCalm), .teal),
            ("等它冷静下来", summary.count(.waitedSent), Theme.brand),
            ("走完仪式仍发出", summary.count(.ritualSent), .orange),
        ]
        let maxValue = max(1, rows.map(\.1).max() ?? 1)
        VStack(alignment: .leading, spacing: 12) {
            Text("被冻住之后").font(.headline)
            ForEach(rows, id: \.0) { title, value, color in
                HStack(spacing: 10) {
                    Text(title).font(.subheadline).frame(width: 104, alignment: .leading)
                    GeometryReader { geo in
                        Capsule().fill(color.gradient)
                            .frame(width: max(6, geo.size.width * Double(value) / Double(maxValue)))
                    }
                    .frame(height: 10)
                    Text("\(value)").font(.subheadline.monospacedDigit()).frame(width: 28, alignment: .trailing)
                }
            }
            Text("放下和改写越多，说明越会给自己留余地。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 22))
    }
}

/// The week in words, like the top of an Apple weekly summary.
private struct ReviewCard: View {
    let review: ThinkReview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("本周回顾", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(review.headline)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(review.detail)
                .font(.body)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Text(review.closing)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Theme.gradient, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

private struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title3.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}

/// One highlight: an icon, a short title and one sentence.
private struct InsightRow: View {
    let insight: ThinkInsight

    var body: some View {
        let (icon, color) = Self.style(insight.kind)
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(color.gradient, in: .circle)
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(.headline)
                Text(insight.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private static func style(_ kind: ThinkInsight.Kind) -> (String, Color) {
        switch kind {
        case .calmStreak: ("leaf.fill", .green)
        case .letGo: ("wind", .teal)
        case .rewrite: ("pencil.and.scribble", Theme.brand)
        case .tookTime: ("moon.zzz.fill", .indigo)
        case .tryWaiting: ("sunrise.fill", .orange)
        }
    }
}
