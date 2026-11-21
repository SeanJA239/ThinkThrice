import Foundation

/// Every threshold and timing in the app. Tune values here on site.
///
/// Both thresholds default to 0.6: the model side's detector locks at a score of
/// 60/100, and it already treats night differently through its late-night word
/// lists, so day and night share one line (see `Verdict.impulse`).
public struct TimePolicy: Sendable, Equatable {
    /// Night starts at this hour (inclusive), local time.
    public var nightStartHour = 22
    /// Night ends at this hour (exclusive), local time.
    public var nightEndHour = 6
    /// A score at or above the threshold settles the message.
    public var nightThreshold = 0.6
    public var dayThreshold = 0.6
    /// Night messages settle until this hour of the next morning.
    public var morningReleaseHour = 9
    public var morningReleaseMinute = 0
    /// Day messages settle for this long.
    public var daySettleDuration: TimeInterval = 15 * 60
    public var nightRitualQuestions = 3
    public var dayRitualQuestions = 1
    /// Slow breaths on each ritual page before "next" unlocks.
    public var ritualBreaths = 3
    /// Seconds per breath: in for the first half, out for the second.
    public var ritualBreathDuration: TimeInterval = 5
    /// Seconds each ritual page stays before "next" unlocks.
    public var ritualPageWait: TimeInterval { Double(ritualBreaths) * ritualBreathDuration }
    /// Seconds between sentences appearing in the melt editor.
    public var meltRevealInterval: TimeInterval = 1.5
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func isNight(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        if nightStartHour > nightEndHour {
            return hour >= nightStartHour || hour < nightEndHour
        }
        return hour >= nightStartHour && hour < nightEndHour
    }

    public func threshold(at date: Date) -> Double {
        isNight(date) ? nightThreshold : dayThreshold
    }

    public func shouldSettle(score: Double, at date: Date) -> Bool {
        score >= threshold(at: date)
    }

    /// When a message that settles at `date` becomes ready.
    public func settleUntil(from date: Date) -> Date {
        guard isNight(date) else {
            return date.addingTimeInterval(daySettleDuration)
        }
        let release = DateComponents(hour: morningReleaseHour, minute: morningReleaseMinute, second: 0)
        // The next morning release strictly after `date`: same day after midnight, next day before it.
        return calendar.nextDate(after: date, matching: release, matchingPolicy: .nextTime) ?? date.addingTimeInterval(daySettleDuration)
    }

    public func ritualQuestionCount(at date: Date) -> Int {
        isNight(date) ? nightRitualQuestions : dayRitualQuestions
    }
}
