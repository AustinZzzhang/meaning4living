import Foundation

public struct WorkSettings: Codable, Equatable {
    public var monthlySalary: Double = 18_000
    public var startMinute: Int = 9 * 60 + 30
    public var endMinute: Int = 18 * 60 + 30
    public var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    public var dateOverrides: [String: Bool] = [:]
    public var compactMenuBar: Bool = false
    public var useChinaHolidayCalendar: Bool = true
    public var hideMenuBarWhenMirroring: Bool = true
    public var hideWhenExternalDisplay: Bool = false
    public var sensitiveMode: Bool = false
    public var itemPreset: ItemPreset = .food
    public var customItemTiers: [ItemTier] = []

    /// Creates the default schedule. No parameters; returns a new settings value.
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case monthlySalary, startMinute, endMinute, weekdays, dateOverrides, compactMenuBar
        case useChinaHolidayCalendar, hideMenuBarWhenMirroring, hideWhenExternalDisplay
        case sensitiveMode, itemPreset, customItemTiers
    }

    /// Migrates decoder's version-one settings with safe defaults for new fields; returns decoded settings.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        monthlySalary = try values.decode(Double.self, forKey: .monthlySalary)
        startMinute = try values.decode(Int.self, forKey: .startMinute)
        endMinute = try values.decode(Int.self, forKey: .endMinute)
        weekdays = try values.decode(Set<Int>.self, forKey: .weekdays)
        dateOverrides = try values.decode([String: Bool].self, forKey: .dateOverrides)
        compactMenuBar = try values.decode(Bool.self, forKey: .compactMenuBar)
        useChinaHolidayCalendar = try values.decodeIfPresent(Bool.self, forKey: .useChinaHolidayCalendar) ?? true
        hideMenuBarWhenMirroring = try values.decodeIfPresent(
            Bool.self, forKey: .hideMenuBarWhenMirroring
        ) ?? true
        hideWhenExternalDisplay = try values.decodeIfPresent(Bool.self, forKey: .hideWhenExternalDisplay) ?? false
        sensitiveMode = try values.decodeIfPresent(Bool.self, forKey: .sensitiveMode) ?? false
        itemPreset = try values.decodeIfPresent(ItemPreset.self, forKey: .itemPreset) ?? .food
        customItemTiers = try values.decodeIfPresent([ItemTier].self, forKey: .customItemTiers) ?? []
    }

    public var validationMessage: String? {
        if !monthlySalary.isFinite || monthlySalary <= 0 || monthlySalary > 100_000_000 {
            return "请输入大于 0、不超过 1 亿的月薪。"
        }
        if !(0..<1440).contains(startMinute) || !(0..<1440).contains(endMinute) {
            return "请选择有效的上下班时间。"
        }
        if startMinute == endMinute {
            return "上下班时间不能相同；跨午夜的班次可以正常设置。"
        }
        if weekdays.isEmpty || !weekdays.isSubset(of: Set(1...7)) {
            return "请至少选择一个每周工作日。"
        }
        if itemPreset == .custom { return ItemCatalog.validationMessage(for: customItemTiers) }
        return nil
    }

    public var isOvernight: Bool { endMinute < startMinute }
    public var activeItemTiers: [ItemTier] {
        itemPreset == .custom ? customItemTiers : itemPreset.tiers
    }
}

public struct DayRecord: Codable, Equatable {
    public var overtimeSeconds: TimeInterval = 0
    public var overtimeLoss: Double = 0
    public var earnedAmount: Double = 0
    public var freeloadSeconds: TimeInterval = 0
    public var freeloadAmount: Double = 0
    public var checkInAt: Date?
    public var checkOutAt: Date?
    public var isSettled: Bool = false
    public var plan: RecordedShift?
    public var overtimeIntervals: [OvertimeInterval] = []
    public var legacyLoss: Double = 0
    public var legacySeconds: TimeInterval = 0
    public var manualChanges: [AttendanceChange] = []

    /// Creates an empty attendance and earnings record; no parameters, returns a new record.
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case overtimeSeconds, overtimeLoss, earnedAmount, freeloadSeconds, freeloadAmount
        case checkInAt, checkOutAt, isSettled
        case plan, overtimeIntervals, legacyLoss, legacySeconds, manualChanges
    }

    /// Migrates legacy loss-only records and supplies attendance defaults; returns a decoded record.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        overtimeSeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .overtimeSeconds) ?? 0
        overtimeLoss = try values.decodeIfPresent(Double.self, forKey: .overtimeLoss) ?? 0
        earnedAmount = try values.decodeIfPresent(Double.self, forKey: .earnedAmount) ?? 0
        freeloadSeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .freeloadSeconds) ?? 0
        freeloadAmount = try values.decodeIfPresent(Double.self, forKey: .freeloadAmount) ?? 0
        checkInAt = try values.decodeIfPresent(Date.self, forKey: .checkInAt)
        checkOutAt = try values.decodeIfPresent(Date.self, forKey: .checkOutAt)
        isSettled = try values.decodeIfPresent(Bool.self, forKey: .isSettled) ?? false
        plan = try values.decodeIfPresent(RecordedShift.self, forKey: .plan)
        overtimeIntervals = try values.decodeIfPresent([OvertimeInterval].self, forKey: .overtimeIntervals) ?? []
        legacyLoss = try values.decodeIfPresent(Double.self, forKey: .legacyLoss) ?? overtimeLoss
        legacySeconds = try values.decodeIfPresent(TimeInterval.self, forKey: .legacySeconds) ?? overtimeSeconds
        manualChanges = try values.decodeIfPresent([AttendanceChange].self, forKey: .manualChanges) ?? []
    }
}

public struct SavedState: Codable, Equatable {
    public var version: Int = 2
    public var hasConfirmedSchedule = false
    public var settings: WorkSettings = WorkSettings()
    public var records: [String: DayRecord] = [:]

    /// Creates persistent application state. No parameters; returns default state.
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case version, hasConfirmedSchedule, settings, records
    }

    /// Decodes saved fields, treating existing versions without setup flags as configured; returns migrated state.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        hasConfirmedSchedule = try values.decodeIfPresent(Bool.self, forKey: .hasConfirmedSchedule) ?? true
        settings = try values.decode(WorkSettings.self, forKey: .settings)
        records = try values.decode([String: DayRecord].self, forKey: .records)
    }
}

public enum WorkPhase: String, Codable {
    case beforeWork
    case awaitingCheckIn
    case working
    case overtime
    case checkedOut
    case rest

    public var title: String {
        switch self {
        case .beforeWork: return "未上班"
        case .awaitingCheckIn: return "未打卡"
        case .working: return "工作中"
        case .overtime: return "已超时"
        case .checkedOut: return "已结算"
        case .rest: return "休息日"
        }
    }

    public var timerLabel: String {
        switch self {
        case .beforeWork: return "距上班"
        case .awaitingCheckIn: return "距下班"
        case .working: return "距下班"
        case .overtime: return "已下班"
        case .checkedOut: return "已结算"
        case .rest: return "好好生活"
        }
    }
}

public struct WorkShift: Codable, Equatable {
    public let day: Date
    public let key: String
    public let start: Date
    public let end: Date
    public let overtimeEnd: Date

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

public struct EarningsSnapshot {
    public let date: Date
    public let phase: WorkPhase
    public let dayKey: String
    public let amount: Double
    public let earned: Double
    public let overtimeLoss: Double
    public let rate: Double
    public let timerSeconds: TimeInterval
    public let progress: Double
    public let monthWorkdays: Int
    public let shift: WorkShift?
    public let freeloadAmount: Double
    public let freeloadSeconds: TimeInterval
    public let scheduledAmount: Double
    public let checkInAt: Date?
    public let checkOutAt: Date?
    public let isSettled: Bool

    public var amountText: String {
        MoneyText.currency(amount, negative: phase == .overtime)
    }

    public var timerText: String {
        MoneyText.duration(timerSeconds, roundUp: phase != .overtime)
    }

    public var timerCaption: String {
        if phase == .rest { return "好好生活" }
        if phase == .checkedOut { return "今日已结算" }
        return "\(phase.timerLabel) \(timerText)"
    }

    public var menuText: String {
        if phase == .rest { return "休息日" }
        if phase == .checkedOut { return "已下班 ✓" }
        let prefix = phase == .awaitingCheckIn ? "白嫖 " : ""
        return "\(prefix)\(amountText) · \(timerText)"
    }
}

public enum MoneyText {
    /// Formats a finite amount in yuan; negative forces a minus at zero. Returns display text.
    public static func currency(_ value: Double, negative: Bool = false) -> String {
        let magnitude = abs(value.isFinite ? value : 0)
        let prefix = negative || value < 0 ? "-¥" : "¥"
        return prefix + String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), magnitude)
    }

    /// Formats seconds as HH:mm:ss; roundUp preserves countdowns. Returns a duration string.
    public static func duration(_ seconds: TimeInterval, roundUp: Bool = false) -> String {
        let safe = seconds.isFinite ? min(max(0, seconds), 315_576_000) : 0
        let total = Int(roundUp ? ceil(safe) : floor(safe))
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    /// Formats minutes after midnight as HH:mm. Returns a 24-hour schedule label.
    public static func clock(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    /// Formats the per-second rate with useful precision. Returns a yuan-per-second label.
    public static func rate(_ value: Double) -> String {
        String(format: "¥%.4f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
