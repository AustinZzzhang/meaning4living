import Foundation

public struct RecordedShift: Codable, Equatable {
    public let shift: WorkShift
    public let rate: Double
    public let monthWorkdays: Int
    public let timeZoneID: String
    public let calendarLabel: String

    /// Freezes shift, rate, month workdays, timezone and label for a recorded workday; returns a plan.
    public init(shift: WorkShift, rate: Double, monthWorkdays: Int, timeZoneID: String, calendarLabel: String) {
        self.shift = shift
        self.rate = rate
        self.monthWorkdays = monthWorkdays
        self.timeZoneID = timeZoneID
        self.calendarLabel = calendarLabel
    }
}

public struct OvertimeInterval: Codable, Equatable {
    public var start: Date
    public var end: Date

    /// Creates a runtime-only overtime interval using inclusive start and exclusive end; returns an interval.
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public struct AttendanceChange: Codable, Equatable {
    public let changedAt: Date
    public let oldCheckIn: Date?
    public let oldCheckOut: Date?
    public let newCheckIn: Date?
    public let newCheckOut: Date?

    /// Records an edit at changedAt with previous and replacement punches; returns an audit entry.
    public init(changedAt: Date, oldCheckIn: Date?, oldCheckOut: Date?, newCheckIn: Date?, newCheckOut: Date?) {
        self.changedAt = changedAt
        self.oldCheckIn = oldCheckIn
        self.oldCheckOut = oldCheckOut
        self.newCheckIn = newCheckIn
        self.newCheckOut = newCheckOut
    }
}

public struct DailyAmounts {
    public let earned: Double
    public let freeload: Double
    public let freeSeconds: TimeInterval
    public let lateSeconds: TimeInterval
    public let earlySeconds: TimeInterval

    /// Computes income and its free-time subset for record asOf date, without adding them together; returns totals.
    public static func calculate(record: DayRecord, asOf date: Date) -> DailyAmounts {
        guard let plan = record.plan else {
            return DailyAmounts(earned: record.earnedAmount, freeload: record.freeloadAmount,
                                freeSeconds: record.freeloadSeconds, lateSeconds: 0, earlySeconds: 0)
        }
        let shift = plan.shift
        let departed = record.checkOutAt.map { $0 <= date } ?? false
        let through = departed ? shift.end : min(date, shift.end)
        let elapsed = max(0, min(shift.duration, through.timeIntervalSince(shift.start)))
        let arrival = record.checkInAt ?? (departed ? record.checkOutAt! : through)
        let late = max(0, min(through, min(arrival, shift.end)).timeIntervalSince(shift.start))
        let early = departed ? max(0, shift.end.timeIntervalSince(max(shift.start, record.checkOutAt!))) : 0
        let free = min(elapsed, late + early)
        return DailyAmounts(earned: elapsed * plan.rate, freeload: free * plan.rate,
                            freeSeconds: free, lateSeconds: late, earlySeconds: early)
    }
}
