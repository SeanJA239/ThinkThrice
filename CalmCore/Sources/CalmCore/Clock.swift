import Foundation

/// The app's notion of "now". Named `CalmClock` because `Clock` is a Swift standard library protocol.
public protocol CalmClock: Sendable {
    var now: Date { get }
}

public struct SystemClock: CalmClock {
    public init() {}
    public var now: Date { Date() }
}

/// A clock the demo can move: it runs at real speed from an offset that
/// `jump(toNextHour:minute:)` and `advance(by:)` change.
public final class DemoClock: CalmClock, @unchecked Sendable {
    // @unchecked Sendable: `offset` is only read and written under `lock`.
    private let lock = NSLock()
    private var offset: TimeInterval = 0
    private let realNow: @Sendable () -> Date
    private let calendar: Calendar

    public init(calendar: Calendar = .current, realNow: @escaping @Sendable () -> Date = { Date() }) {
        self.calendar = calendar
        self.realNow = realNow
    }

    public var now: Date {
        lock.lock()
        defer { lock.unlock() }
        return realNow().addingTimeInterval(offset)
    }

    /// How far the demo clock is ahead of real time. Notifications use it to fire at the real equivalent.
    public var offsetFromRealTime: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return offset
    }

    public var isShifted: Bool { offsetFromRealTime != 0 }

    public func set(to date: Date) {
        lock.lock()
        defer { lock.unlock() }
        offset = date.timeIntervalSince(realNow())
    }

    /// Moves forward to the next time the wall clock shows `hour:minute`.
    public func jump(toNextHour hour: Int, minute: Int = 0) {
        let components = DateComponents(hour: hour, minute: minute, second: 0)
        guard let target = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime) else { return }
        set(to: target)
    }

    public func advance(by interval: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        offset += interval
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        offset = 0
    }
}
