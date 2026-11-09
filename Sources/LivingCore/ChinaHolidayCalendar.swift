import Foundation

public struct ChinaHolidayDay: Equatable {
    public let name: String
    public let isWorkday: Bool

    /// Creates an official holiday or makeup-workday entry; returns a calendar entry.
    public init(name: String, isWorkday: Bool) {
        self.name = name
        self.isWorkday = isWorkday
    }
}

public enum ChinaHolidayCalendar {
    private static let schedules: [Int: [String: ChinaHolidayDay]] = [
        2025: [
            "2025-01-01": ChinaHolidayDay(name: "元旦", isWorkday: false),
            "2025-01-28": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2025-01-29": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2025-01-30": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2025-01-31": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2025-02-01": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2025-02-02": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2025-02-03": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2025-02-04": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2025-01-26": ChinaHolidayDay(name: "春节调休", isWorkday: true),
            "2025-02-08": ChinaHolidayDay(name: "春节调休", isWorkday: true),
            "2025-04-04": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2025-04-05": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2025-04-06": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2025-05-01": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2025-05-02": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2025-05-03": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2025-05-04": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2025-05-05": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2025-04-27": ChinaHolidayDay(name: "劳动节调休", isWorkday: true),
            "2025-05-31": ChinaHolidayDay(name: "端午节", isWorkday: false),
            "2025-06-01": ChinaHolidayDay(name: "端午节", isWorkday: false),
            "2025-06-02": ChinaHolidayDay(name: "端午节", isWorkday: false),
            "2025-10-01": ChinaHolidayDay(name: "国庆·中秋", isWorkday: false),
            "2025-10-02": ChinaHolidayDay(name: "国庆·中秋", isWorkday: false),
            "2025-10-03": ChinaHolidayDay(name: "国庆·中秋", isWorkday: false),
            "2025-10-04": ChinaHolidayDay(name: "国庆·中秋", isWorkday: false),
            "2025-10-05": ChinaHolidayDay(name: "国庆·中秋", isWorkday: false),
            "2025-10-06": ChinaHolidayDay(name: "国庆·中秋", isWorkday: false),
            "2025-10-07": ChinaHolidayDay(name: "国庆·中秋", isWorkday: false),
            "2025-10-08": ChinaHolidayDay(name: "国庆·中秋", isWorkday: false),
            "2025-09-28": ChinaHolidayDay(name: "国庆节调休", isWorkday: true),
            "2025-10-11": ChinaHolidayDay(name: "国庆节调休", isWorkday: true),
        ],
        2026: [
            "2026-01-01": ChinaHolidayDay(name: "元旦", isWorkday: false),
            "2026-01-02": ChinaHolidayDay(name: "元旦", isWorkday: false),
            "2026-01-03": ChinaHolidayDay(name: "元旦", isWorkday: false),
            "2026-01-04": ChinaHolidayDay(name: "元旦调休", isWorkday: true),
            "2026-02-15": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-16": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-17": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-18": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-19": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-20": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-21": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-22": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-23": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2026-02-14": ChinaHolidayDay(name: "春节调休", isWorkday: true),
            "2026-02-28": ChinaHolidayDay(name: "春节调休", isWorkday: true),
            "2026-04-04": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2026-04-05": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2026-04-06": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2026-05-01": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2026-05-02": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2026-05-03": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2026-05-04": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2026-05-05": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2026-05-09": ChinaHolidayDay(name: "劳动节调休", isWorkday: true),
            "2026-06-19": ChinaHolidayDay(name: "端午节", isWorkday: false),
            "2026-06-20": ChinaHolidayDay(name: "端午节", isWorkday: false),
            "2026-06-21": ChinaHolidayDay(name: "端午节", isWorkday: false),
            "2026-09-25": ChinaHolidayDay(name: "中秋节", isWorkday: false),
            "2026-09-26": ChinaHolidayDay(name: "中秋节", isWorkday: false),
            "2026-09-27": ChinaHolidayDay(name: "中秋节", isWorkday: false),
            "2026-10-01": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2026-10-02": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2026-10-03": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2026-10-04": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2026-10-05": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2026-10-06": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2026-10-07": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2026-09-20": ChinaHolidayDay(name: "国庆节调休", isWorkday: true),
            "2026-10-10": ChinaHolidayDay(name: "国庆节调休", isWorkday: true),
        ],
        2027: [
            "2027-01-01": ChinaHolidayDay(name: "元旦", isWorkday: false),
            "2027-01-02": ChinaHolidayDay(name: "元旦", isWorkday: false),
            "2027-01-03": ChinaHolidayDay(name: "元旦", isWorkday: false),
            "2027-02-05": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-02-06": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-02-07": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-02-08": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-02-09": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-02-10": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-02-11": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-02-12": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-02-13": ChinaHolidayDay(name: "春节", isWorkday: false),
            "2027-04-03": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2027-04-04": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2027-04-05": ChinaHolidayDay(name: "清明节", isWorkday: false),
            "2027-05-01": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2027-05-02": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2027-05-03": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2027-05-04": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2027-05-05": ChinaHolidayDay(name: "劳动节", isWorkday: false),
            "2027-06-09": ChinaHolidayDay(name: "端午节", isWorkday: false),
            "2027-09-15": ChinaHolidayDay(name: "中秋节", isWorkday: false),
            "2027-10-01": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2027-10-02": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2027-10-03": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2027-10-04": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2027-10-05": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2027-10-06": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2027-10-07": ChinaHolidayDay(name: "国庆节", isWorkday: false),
            "2027-01-31": ChinaHolidayDay(name: "春节调休", isWorkday: true),
            "2027-02-14": ChinaHolidayDay(name: "春节调休", isWorkday: true),
            "2027-05-08": ChinaHolidayDay(name: "劳动节调休", isWorkday: true),
            "2027-09-26": ChinaHolidayDay(name: "国庆节调休", isWorkday: true),
            "2027-10-09": ChinaHolidayDay(name: "国庆节调休", isWorkday: true),
        ],
    ]

    /// Returns the built-in official arrangement for date, or nil when that year is not embedded.
    public static func day(for date: Date, calendar: Calendar) -> ChinaHolidayDay? {
        let year = calendar.component(.year, from: date)
        let key = String(format: "%04d-%02d-%02d", year, calendar.component(.month, from: date),
                         calendar.component(.day, from: date))
        return schedules[year]?[key]
    }

    /// Returns whether an official schedule is embedded for the year; no parameters beyond year.
    public static func supports(year: Int) -> Bool {
        schedules[year] != nil
    }
}
