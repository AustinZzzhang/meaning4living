import Foundation

public struct WorkCalendar {
    public var calendar: Calendar

    /// Creates a Gregorian work calendar in the supplied time zone; returns a calendar helper.
    public init(timeZone: TimeZone = .autoupdatingCurrent) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2
        self.calendar = calendar
    }

    /// Identifies a date in the work calendar's time zone. Returns a stable yyyy-MM-dd key.
    public func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// Shifts a date by calendar days, preserving civil time when possible. Returns the new date.
    public func addingDays(_ value: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: value, to: date)!
    }

    /// Returns every civil day in the month containing date, ordered from the first day.
    public func days(inMonthOf date: Date) -> [Date] {
        let start = calendar.dateInterval(of: .month, for: date)!.start
        let range = calendar.range(of: .day, in: .month, for: date)!
        return range.map { addingDays($0 - 1, to: start) }
    }

    /// Resolves date using personal overrides, official arrangements, then weekdays; returns true for a workday.
    public func isWorkday(_ date: Date, settings: WorkSettings) -> Bool {
        if let override = settings.dateOverrides[key(for: date)] { return override }
        if settings.useChinaHolidayCalendar, let official = ChinaHolidayCalendar.day(for: date, calendar: calendar) {
            return official.isWorkday
        }
        return settings.weekdays.contains(calendar.component(.weekday, from: date))
    }

    /// Returns the official holiday or makeup-workday label for date, or nil for ordinary dates.
    public func officialDayInfo(_ date: Date) -> ChinaHolidayDay? {
        ChinaHolidayCalendar.day(for: date, calendar: calendar)
    }

    /// Returns a readable source label for date, including custom overrides and official arrangements.
    public func scheduleLabel(_ date: Date, settings: WorkSettings) -> String {
        if let override = settings.dateOverrides[key(for: date)] {
            return override ? "自定义工作日" : "自定义休息日"
        }
        if settings.useChinaHolidayCalendar, let official = officialDayInfo(date) {
            return official.name
        }
        return isWorkday(date, settings: settings) ? "工作日" : "休息日"
    }

    /// Places a minute-of-day on date, advancing nonexistent DST times. Returns an absolute date.
    public func time(_ minute: Int, on date: Date) -> Date {
        calendar.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: date,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )!
    }

    /// Builds the paid shift and bounded overtime interval for a workday; returns nil on rest days.
    public func shift(on date: Date, settings: WorkSettings) -> WorkShift? {
        guard isWorkday(date, settings: settings), settings.validationMessage == nil else { return nil }
        let day = calendar.startOfDay(for: date)
        let start = time(settings.startMinute, on: day)
        let endDay = settings.isOvernight ? addingDays(1, to: day) : day
        let end = time(settings.endMinute, on: endDay)
        guard end > start else { return nil }
        var cutoff = addingDays(1, to: calendar.startOfDay(for: end))
        let followingDay = addingDays(1, to: day)
        if isWorkday(followingDay, settings: settings) {
            let followingStart = time(settings.startMinute, on: followingDay)
            if followingStart >= end { cutoff = min(cutoff, followingStart) }
        }
        return WorkShift(day: day, key: key(for: day), start: start, end: end, overtimeEnd: cutoff)
    }

    /// Uses date's month and settings to return planned day count and seconds, including overnight/DST shifts.
    public func monthTotals(for date: Date, settings: WorkSettings) -> (days: Int, seconds: TimeInterval) {
        let shifts = days(inMonthOf: date).compactMap { shift(on: $0, settings: settings) }
        return (shifts.count, shifts.reduce(0) { $0 + $1.duration })
    }

    /// Returns the salary rate for the shift's starting month; invalid or empty plans return zero.
    public func rate(for date: Date, settings: WorkSettings) -> Double {
        guard settings.validationMessage == nil else { return 0 }
        let seconds = monthTotals(for: date, settings: settings).seconds
        return seconds > 0 ? settings.monthlySalary / seconds : 0
    }
}
