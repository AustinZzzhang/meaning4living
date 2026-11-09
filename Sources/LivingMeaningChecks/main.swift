import Foundation
import LivingCore

var failures: [String] = []
var passed = 0
let workCalendar = WorkCalendar(timeZone: TimeZone(identifier: "Asia/Shanghai")!)
let engine = EarningsEngine(workCalendar: workCalendar)
let defaults = WorkSettings()

/// Creates a deterministic civil date in calendar from year/month/day/hour/minute/second; returns Date.
func date(
    _ year: Int = 2026,
    _ month: Int = 11,
    _ day: Int = 3,
    _ hour: Int = 0,
    _ minute: Int = 0,
    _ second: Int = 0,
    in calendar: WorkCalendar = workCalendar
) -> Date {
    calendar.calendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute,
        second: second
    ))!
}

/// Runs a named throwing check closure; appends failures or increments the passing count, returns nothing.
func check(_ name: String, _ body: () throws -> Bool) {
    do {
        if try body() {
            passed += 1
            print("PASS \(name)")
        } else {
            failures.append(name)
            print("FAIL \(name)")
        }
    } catch {
        failures.append("\(name): \(error)")
        print("FAIL \(name): \(error)")
    }
}

/// Compares doubles using absolute tolerance; returns true when the values are sufficiently close.
func near(_ left: Double, _ right: Double, tolerance: Double = 0.000_001) -> Bool {
    abs(left - right) <= tolerance
}

/// Calculates a test snapshot with optional settings/records at the provided time; returns the result.
func snapshot(
    _ time: Date,
    settings: WorkSettings = defaults,
    records: [String: DayRecord] = [:]
) -> EarningsSnapshot {
    engine.snapshot(at: time, settings: settings, records: records)
}

check("November 2026 has 21 planned weekdays") {
    workCalendar.monthTotals(for: date(), settings: defaults).days == 21
}
check("December 2026 has 23 planned weekdays") {
    workCalendar.monthTotals(for: date(2026, 12, 1), settings: defaults).days == 23
}
check("Rate uses salary and the actual month's planned seconds") {
    near(workCalendar.rate(for: date(), settings: defaults), 18000 / (21 * 9 * 3600))
}
check("Before work shows zero and a countdown to start") {
    let value = snapshot(date(2026, 11, 3, 9))
    return value.phase == .beforeWork && value.amount == 0 && value.timerText == "00:30:00"
}
check("Exact start awaits check-in with zero earnings") {
    let value = snapshot(date(2026, 11, 3, 9, 30))
    return value.phase == .awaitingCheckIn && value.earned == 0 && value.timerCaption == "距下班 09:00:00"
}
check("Mid-shift earnings are elapsed seconds times rate") {
    let value = snapshot(date(2026, 11, 3, 12, 30))
    return near(value.amount, 18000 / 21 / 3) && near(value.progress, 1 / 3)
}
check("One second before end still awaits check-in") {
    let value = snapshot(date(2026, 11, 3, 18, 29, 59))
    return value.phase == .awaitingCheckIn && value.timerText == "00:00:01"
}
check("Exact end enters overtime at negative zero") {
    let value = snapshot(date(2026, 11, 3, 18, 30))
    return value.phase == .overtime && value.amountText == "-¥0.00" && value.timerCaption == "已下班 00:00:00"
}
check("Post-work display uses stored loss, not a deduction from daytime salary") {
    var record = DayRecord()
    record.overtimeLoss = 12.96
    let value = snapshot(date(2026, 11, 3, 18, 54, 16), records: ["2026-11-03": record])
    return value.amountText == "-¥12.96" && value.timerCaption == "已下班 00:24:16"
        && near(value.earned, 18000 / 21)
}
check("Weekend is a rest day with no ticking overtime") {
    let value = snapshot(date(2026, 11, 8, 20))
    return value.phase == .rest && value.amount == 0 && value.menuText == "休息日"
}
check("A rest override removes a weekday from the salary divisor") {
    var settings = defaults
    settings.dateOverrides["2026-11-03"] = false
    return snapshot(date(2026, 11, 3, 12), settings: settings).phase == .rest
        && workCalendar.monthTotals(for: date(), settings: settings).days == 20
}
check("A makeup-day override adds a weekend to the divisor") {
    var settings = defaults
    settings.dateOverrides["2026-11-07"] = true
    return snapshot(date(2026, 11, 7, 12), settings: settings).phase == .awaitingCheckIn
        && workCalendar.monthTotals(for: date(), settings: settings).days == 22
}
check("Overtime accrual intersects the end-of-shift boundary") {
    var records: [String: DayRecord] = [:]
    engine.accrue(
        from: date(2026, 11, 3, 18, 29, 50),
        to: date(2026, 11, 3, 18, 30, 10),
        settings: defaults,
        records: &records
    )
    return records["2026-11-03"]?.overtimeSeconds == 10
}
check("Quitting and relaunching never backfills the closed interval") {
    var records: [String: DayRecord] = [:]
    var first = ActiveSession(startingAt: date(2026, 11, 3, 18, 30), uptime: 0)
    first.advance(to: date(2026, 11, 3, 18, 31), uptime: 60, engine: engine, settings: defaults, records: &records)
    var second = ActiveSession(startingAt: date(2026, 11, 3, 20), uptime: 0)
    second.advance(to: date(2026, 11, 3, 20, 1), uptime: 60, engine: engine, settings: defaults, records: &records)
    return records["2026-11-03"]?.overtimeSeconds == 120
}
check("Launching after work does not retroactively charge from shift end") {
    var records: [String: DayRecord] = [:]
    var session = ActiveSession(startingAt: date(2026, 11, 3, 21), uptime: 0)
    session.advance(to: date(2026, 11, 3, 21, 0, 5), uptime: 5, engine: engine, settings: defaults, records: &records)
    return records["2026-11-03"]?.overtimeSeconds == 5
}
check("An active sleeping process catches up using real elapsed time") {
    var records: [String: DayRecord] = [:]
    var session = ActiveSession(startingAt: date(2026, 11, 3, 18, 30), uptime: 0)
    session.advance(to: date(2026, 11, 3, 20, 30), uptime: 7200, engine: engine, settings: defaults, records: &records)
    return records["2026-11-03"]?.overtimeSeconds == 7200
}
check("A normal shift stops charging at midnight") {
    var records: [String: DayRecord] = [:]
    engine.accrue(
        from: date(2026, 11, 3, 23, 59, 50),
        to: date(2026, 11, 4, 0, 0, 10),
        settings: defaults,
        records: &records
    )
    return records.count == 1 && records["2026-11-03"]?.overtimeSeconds == 10
}
check("Backward clock adjustments do not freeze ongoing runtime accounting") {
    var records: [String: DayRecord] = [:]
    var session = ActiveSession(startingAt: date(2026, 11, 3, 20), uptime: 0)
    session.advance(to: date(2026, 11, 3, 19), uptime: 1, engine: engine, settings: defaults, records: &records)
    session.advance(to: date(2026, 11, 3, 19, 0, 1), uptime: 2, engine: engine, settings: defaults, records: &records)
    return records["2026-11-03"]?.overtimeSeconds == 2
}
check("Forward clock adjustments do not charge a fictitious hour") {
    var records: [String: DayRecord] = [:]
    var session = ActiveSession(startingAt: date(2026, 11, 3, 19), uptime: 0)
    session.advance(to: date(2026, 11, 3, 20), uptime: 1, engine: engine, settings: defaults, records: &records)
    return records["2026-11-03"]?.overtimeSeconds == 1
}
check("Unchanged checkpoints never double-charge") {
    var records: [String: DayRecord] = [:]
    var session = ActiveSession(startingAt: date(2026, 11, 3, 19), uptime: 0)
    let end = date(2026, 11, 3, 19, 1)
    session.advance(to: end, uptime: 60, engine: engine, settings: defaults, records: &records)
    session.advance(to: end, uptime: 60, engine: engine, settings: defaults, records: &records)
    return records["2026-11-03"]?.overtimeSeconds == 60
}
check("Rest days never accumulate overtime while the app stays open") {
    var records: [String: DayRecord] = [:]
    engine.accrue(
        from: date(2026, 11, 7),
        to: date(2026, 11, 9),
        settings: defaults,
        records: &records
    )
    return records.isEmpty
}
check("Salary changes keep the recorded day's frozen rate for all of its losses") {
    var records: [String: DayRecord] = [:]
    var session = ActiveSession(startingAt: date(2026, 11, 3, 19), uptime: 0)
    session.advance(to: date(2026, 11, 3, 19, 1), uptime: 60, engine: engine, settings: defaults, records: &records)
    let first = records["2026-11-03"]!.overtimeLoss
    var higher = defaults
    higher.monthlySalary *= 2
    session.advance(to: date(2026, 11, 3, 19, 2), uptime: 120, engine: engine, settings: higher, records: &records)
    return near(records["2026-11-03"]!.overtimeLoss, first * 2)
}
check("Month-boundary accrual uses the corresponding month's rate") {
    var records: [String: DayRecord] = [:]
    engine.accrue(
        from: date(2026, 11, 30, 23, 59, 50),
        to: date(2026, 12, 1, 18, 30, 10),
        settings: defaults,
        records: &records
    )
    let november = 10 * workCalendar.rate(for: date(2026, 11, 30), settings: defaults)
    let december = 10 * workCalendar.rate(for: date(2026, 12, 1), settings: defaults)
    return near(records["2026-11-30"]!.overtimeLoss, november)
        && near(records["2026-12-01"]!.overtimeLoss, december)
}
check("An overnight Friday shift continues into Saturday despite Saturday being a rest day") {
    var settings = defaults
    settings.startMinute = 22 * 60
    settings.endMinute = 6 * 60
    let value = snapshot(date(2026, 11, 7, 2), settings: settings)
    return value.phase == .awaitingCheckIn && value.dayKey == "2026-11-06" && value.timerText == "04:00:00"
}
check("Overnight shifts retain the starting month's pay rate") {
    var settings = defaults
    settings.startMinute = 22 * 60
    settings.endMinute = 6 * 60
    let value = snapshot(date(2026, 12, 1, 2), settings: settings)
    return value.dayKey == "2026-11-30" && near(value.rate, 18000 / (21 * 8 * 3600))
}
check("Overnight overtime stops at the next shift start") {
    var settings = defaults
    settings.startMinute = 22 * 60
    settings.endMinute = 6 * 60
    var records: [String: DayRecord] = [:]
    engine.accrue(
        from: date(2026, 11, 4, 21, 59, 50),
        to: date(2026, 11, 4, 22, 0, 10),
        settings: settings,
        records: &records
    )
    return records["2026-11-03"]?.overtimeSeconds == 10
        && snapshot(date(2026, 11, 4, 22), settings: settings).phase == .awaitingCheckIn
}
check("An overnight rest-day morning can still show the previous shift's overtime") {
    var settings = defaults
    settings.startMinute = 22 * 60
    settings.endMinute = 6 * 60
    let value = snapshot(date(2026, 11, 7, 7), settings: settings)
    return value.phase == .overtime && value.dayKey == "2026-11-06"
}
check("Spring DST shift uses seven real hours instead of eight nominal hours") {
    let calendar = WorkCalendar(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
    var settings = defaults
    settings.weekdays = Set(1...7)
    settings.startMinute = 0
    settings.endMinute = 8 * 60
    let shift = calendar.shift(on: date(2026, 3, 8, in: calendar), settings: settings)!
    return shift.duration == 7 * 3600
}
check("Fall DST shift uses nine real hours instead of eight nominal hours") {
    let calendar = WorkCalendar(timeZone: TimeZone(identifier: "America/Los_Angeles")!)
    var settings = defaults
    settings.weekdays = Set(1...7)
    settings.startMinute = 0
    settings.endMinute = 8 * 60
    let shift = calendar.shift(on: date(2026, 11, 1, in: calendar), settings: settings)!
    return shift.duration == 9 * 3600
}
check("Leap February has 29 calendar dates") {
    workCalendar.days(inMonthOf: date(2028, 2, 1)).count == 29
}
check("All overridden rest days yield a zero rate, never division by zero") {
    var settings = defaults
    for day in workCalendar.days(inMonthOf: date()) {
        settings.dateOverrides[workCalendar.key(for: day)] = false
    }
    return workCalendar.rate(for: date(), settings: settings) == 0
        && snapshot(date(), settings: settings).phase == .rest
}
check("Zero, negative and non-finite salaries are rejected") {
    [0, -1, Double.infinity, Double.nan].allSatisfy { salary in
        var settings = defaults
        settings.monthlySalary = salary
        return settings.validationMessage != nil
    }
}
check("Identical start and end times are rejected") {
    var settings = defaults
    settings.endMinute = settings.startMinute
    return settings.validationMessage != nil
}
check("Empty or invalid weekly schedules are rejected") {
    var settings = defaults
    settings.weekdays = []
    let empty = settings.validationMessage != nil
    settings.weekdays = [8]
    return empty && settings.validationMessage != nil
}
check("Timers round countdowns up and elapsed times down") {
    MoneyText.duration(0.2, roundUp: true) == "00:00:01"
        && MoneyText.duration(0.9) == "00:00:00"
        && MoneyText.duration(90061) == "25:01:01"
}
check("Currency keeps two decimals and an explicit overtime minus sign") {
    MoneyText.currency(-12.96) == "-¥12.96"
        && MoneyText.currency(0, negative: true) == "-¥0.00"
        && MoneyText.currency(186.42) == "¥186.42"
}
check("Saving and reloading preserves settings, overrides and accumulated losses") {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repository = StateRepository(url: directory.appendingPathComponent("state.json"))
    var state = SavedState()
    state.settings.monthlySalary = 25000.5
    state.settings.dateOverrides["2026-11-07"] = true
    var record = DayRecord()
    record.overtimeLoss = 12.96
    record.overtimeSeconds = 1456
    state.records["2026-11-03"] = record
    try repository.save(state)
    return try repository.load() == state
}
check("Missing storage returns valid defaults") {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    return try StateRepository(url: url).load() == SavedState()
}
check("Malformed storage is reported and never overwritten by loading") {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let original = Data("broken file".utf8)
    try original.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }
    do {
        _ = try StateRepository(url: url).load()
        return false
    } catch {
        return try Data(contentsOf: url) == original
    }
}
check("Unsupported storage versions are rejected") {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var state = SavedState()
    state.version = 999
    try StateRepository(url: url).save(state)
    do {
        _ = try StateRepository(url: url).load()
        return false
    } catch StateError.unsupportedVersion {
        return true
    }
}
check("Malformed persisted settings are rejected") {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var state = SavedState()
    state.settings.monthlySalary = -1
    try StateRepository(url: url).save(state)
    do {
        _ = try StateRepository(url: url).load()
        return false
    } catch StateError.invalidSettings {
        return true
    }
}

check("Legacy 1.0 settings migrate without losing salary, shifts or records") {
    var old = SavedState()
    old.settings.monthlySalary = 23456
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
    var settings = json["settings"] as! [String: Any]
    for key in ["sensitiveMode", "itemPreset", "customItemTiers"] { settings.removeValue(forKey: key) }
    json["settings"] = settings
    let migrated = try JSONDecoder().decode(SavedState.self, from: JSONSerialization.data(withJSONObject: json))
    return migrated.settings.monthlySalary == 23456 && !migrated.settings.sensitiveMode
        && migrated.settings.itemPreset == .food && migrated.settings.customItemTiers.isEmpty
}
check("All three preset tables are valid and mirror positive/negative amounts at every boundary") {
    for preset in [ItemPreset.fashion, .electronics, .food] {
        guard ItemCatalog.validationMessage(for: preset.tiers) == nil else { return false }
        for tier in preset.tiers {
            for amount in [tier.minimum - 0.01, tier.minimum, tier.minimum + 0.01] {
                guard ItemCatalog.item(for: amount, tiers: preset.tiers)
                    == ItemCatalog.item(for: -amount, tiers: preset.tiers) else { return false }
            }
            guard ItemCatalog.item(for: tier.minimum, tiers: preset.tiers) == tier.item else { return false }
        }
    }
    return true
}
check("Tea, clothes and a phone belong to their configured preset brackets") {
    ItemCatalog.item(for: 15, tiers: ItemPreset.food.tiers) == "一杯奶茶"
        && ItemCatalog.item(for: 34.99, tiers: ItemPreset.food.tiers) == "一杯奶茶"
        && ItemCatalog.item(for: 200, tiers: ItemPreset.fashion.tiers) == "一件衣服"
        && ItemCatalog.item(for: -5000, tiers: ItemPreset.electronics.tiers) == "一个手机"
}
check("Zero, below-first and above-last tiers have predictable displays") {
    ItemCatalog.item(for: 0, tiers: ItemPreset.food.tiers) == "还没有积累"
        && ItemCatalog.item(for: 0.1, tiers: ItemPreset.food.tiers) == "一点小确幸"
        && ItemCatalog.item(for: 1_000_000, tiers: ItemPreset.electronics.tiers) == "一台电脑"
}
check("Custom fractional boundaries choose exactly the lower-inclusive bracket") {
    let tiers = [ItemTier(minimum: 0, item: "一颗糖"), ItemTier(minimum: 12.5, item: "一杯茶")]
    return ItemCatalog.item(for: 12.49, tiers: tiers) == "一颗糖"
        && ItemCatalog.item(for: 12.5, tiers: tiers) == "一杯茶"
        && ItemCatalog.item(for: -12.5, tiers: tiers) == "一杯茶"
}
check("Invalid custom tiers are rejected, including duplicate and unsorted boundaries") {
    let invalid: [[ItemTier]] = [
        [], [ItemTier(minimum: -1, item: "物品")],
        [ItemTier(minimum: .nan, item: "物品")],
        [ItemTier(minimum: 1, item: "")],
        [ItemTier(minimum: 1, item: "物品\n另一物品")],
        [ItemTier(minimum: 10, item: "一杯茶"), ItemTier(minimum: 10, item: "两杯茶")],
        [ItemTier(minimum: 20, item: "一杯茶"), ItemTier(minimum: 10, item: "两杯茶")],
        [ItemTier(minimum: 1, item: String(repeating: "长", count: 17))]
    ]
    return invalid.allSatisfy { ItemCatalog.validationMessage(for: $0) != nil }
}
check("Sensitive projections never contain salary, currency, earned amount or per-second rate") {
    var settings = defaults
    settings.sensitiveMode = true
    var record = DayRecord()
    record.overtimeLoss = 15
    let snapshots = [
        snapshot(date(2026, 11, 3, 9)),
        snapshot(date(2026, 11, 3, 12)),
        snapshot(date(2026, 11, 3, 19), records: ["2026-11-03": record]),
        snapshot(date(2026, 11, 8))
    ]
    return snapshots.allSatisfy { value in
        let display = EarningsPresentation(snapshot: value, settings: settings)
        let strings = [
            display.amount, display.compactAmount, display.headline, display.rate, display.salary,
            display.earned, display.menuText, display.accessibilityLabel,
            ItemCatalog.loss(15, settings: settings)
        ]
        return strings.allSatisfy { !$0.contains("¥") && !$0.contains("18000") && !$0.contains("0.0265") }
    }
}
check("Sensitive loss is red-state wording plus the same item, never a money display") {
    var settings = defaults
    settings.sensitiveMode = true
    var record = DayRecord()
    record.overtimeLoss = 15
    let value = snapshot(date(2026, 11, 3, 19), records: ["2026-11-03": record])
    let display = EarningsPresentation(snapshot: value, settings: settings)
    return display.headline == "今天已损失" && display.amount == "一杯奶茶"
        && display.compactAmount == "−一杯奶茶"
}
check("Custom sensitive settings survive persistence exactly") {
    var settings = defaults
    settings.sensitiveMode = true
    settings.itemPreset = .custom
    settings.customItemTiers = [ItemTier(minimum: 0, item: "一个愿望"), ItemTier(minimum: 88.5, item: "一份礼物")]
    return try JSONDecoder().decode(WorkSettings.self, from: JSONEncoder().encode(settings)) == settings
}
check("Disabled sensitive mode preserves existing monetary formatting") {
    let value = snapshot(date(2026, 11, 3, 12))
    let display = EarningsPresentation(snapshot: value, settings: defaults)
    return display.amount == value.amountText && display.menuText == value.menuText
        && display.salary == "¥18000.00"
}
check("Password verifiers authenticate correctly and never encode plaintext") {
    let password = "test-only-password-中文-2036"
    let credential = try PasswordCredential(password: password)
    let encoded = try JSONEncoder().encode(credential)
    return try credential.matches(password) && !credential.matches("wrong-password")
        && !String(data: encoded, encoding: .utf8)!.contains(password)
}
check("Identical passwords use different random salts and hashes") {
    let left = try PasswordCredential(password: "test-only-123")
    let right = try PasswordCredential(password: "test-only-123")
    return left.salt != right.salt && left.digest != right.digest
}
check("Passwords reject weak-length and all-space inputs; Unicode is supported") {
    PasswordCredential.validationMessage("12345") != nil
        && PasswordCredential.validationMessage("        ") != nil
        && PasswordCredential.validationMessage("我的保护密码六位") == nil
}
check("Corrupt verifier records fail closed") {
    let credential = try PasswordCredential(password: "test-only-123")
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(credential)) as! [String: Any]
    json["rounds"] = 1
    let invalid = try JSONDecoder().decode(PasswordCredential.self, from: JSONSerialization.data(withJSONObject: json))
    return !invalid.isValid()
}
check("Update source permits HTTPS XML but refuses unsafe schemes and credentials") {
    UpdateSource.url("https://updates.example.com/appcast.xml") != nil
        && UpdateSource.url(" https://updates.example.com/appcast.xml ") != nil
        && ["http://example.com/appcast.xml", "file:///tmp/appcast.xml", "javascript:alert(1)",
            "https://user:secret@example.com/appcast.xml", "https://example.com/appcast.xml#fragment",
            "https:///appcast.xml", "https://example.com/app.zip"
        ].allSatisfy { UpdateSource.url($0) == nil }
}

var attendance = defaults
attendance.startMinute = 9 * 60
attendance.endMinute = 18 * 60
attendance.monthlySalary = 18_900

check("Official 2026 holiday weekdays are off and makeup weekends are working days") {
    [date(2026, 1, 1), date(2026, 2, 23), date(2026, 5, 5), date(2026, 10, 7)].allSatisfy {
        !workCalendar.isWorkday($0, settings: defaults)
    } && [date(2026, 1, 4), date(2026, 2, 28), date(2026, 9, 20), date(2026, 10, 10)].allSatisfy {
        workCalendar.isWorkday($0, settings: defaults)
    }
}
check("Official 2027 includes single-day Dragon Boat and Mid-Autumn holidays") {
    !workCalendar.isWorkday(date(2027, 6, 9), settings: defaults)
        && workCalendar.isWorkday(date(2027, 6, 10), settings: defaults)
        && !workCalendar.isWorkday(date(2027, 9, 15), settings: defaults)
        && workCalendar.isWorkday(date(2027, 1, 31), settings: defaults)
}
check("Personal overrides win over official holidays and makeup workdays") {
    var settings = defaults
    settings.dateOverrides["2026-10-01"] = true
    settings.dateOverrides["2026-10-10"] = false
    return workCalendar.isWorkday(date(2026, 10, 1), settings: settings)
        && !workCalendar.isWorkday(date(2026, 10, 10), settings: settings)
        && workCalendar.scheduleLabel(date(2026, 10, 1), settings: settings) == "自定义工作日"
}
check("Holiday switch restores weekly schedule and unknown years use weekly fallback") {
    var settings = defaults
    settings.useChinaHolidayCalendar = false
    return workCalendar.isWorkday(date(2026, 10, 1), settings: settings)
        && !workCalendar.isWorkday(date(2026, 10, 10), settings: settings)
        && !ChinaHolidayCalendar.supports(year: 2028)
        && workCalendar.isWorkday(date(2028, 1, 3), settings: defaults)
}
check("February and October 2026 salary divisors include official holidays and makeup days") {
    workCalendar.monthTotals(for: date(2026, 2, 1), settings: defaults).days == 16
        && workCalendar.monthTotals(for: date(2026, 10, 1), settings: defaults).days == 18
        && near(workCalendar.rate(for: date(2026, 2, 1), settings: defaults), 18000 / (16 * 9 * 3600))
}
check("Opening before work does not freeze an untouched schedule") {
    var records: [String: DayRecord] = [:]
    engine.observe(at: date(2026, 11, 3, 8), settings: attendance, records: &records)
    return records.isEmpty
}
check("Late arrival changes state while preserving income and its free subset") {
    var records: [String: DayRecord] = [:]
    let now = date(2026, 11, 3, 9, 30)
    let before = snapshot(now, settings: attendance, records: records)
    guard engine.checkIn(at: now, settings: attendance, records: &records) else { return false }
    let after = snapshot(now, settings: attendance, records: records)
    let later = snapshot(date(2026, 11, 3, 10), settings: attendance, records: records)
    return before.phase == .awaitingCheckIn && after.phase == .working
        && near(before.earned, 50) && near(after.earned, 50)
        && near(later.earned, 100) && near(later.freeloadAmount, 50)
}
check("Early arrival is allowed but pays nothing before the scheduled start") {
    var records: [String: DayRecord] = [:]
    guard engine.checkIn(at: date(2026, 11, 3, 8), settings: attendance, records: &records) else { return false }
    let before = snapshot(date(2026, 11, 3, 8, 30), settings: attendance, records: records)
    let after = snapshot(date(2026, 11, 3, 9, 30), settings: attendance, records: records)
    return before.phase == .beforeWork && before.earned == 0
        && after.phase == .working && near(after.earned, 50) && after.freeloadAmount == 0
}
check("Early checkout settles 900 earned with 150 free for a late arrival and early departure") {
    var records: [String: DayRecord] = [:]
    engine.checkIn(at: date(2026, 11, 3, 9, 30), settings: attendance, records: &records)
    engine.checkOut(at: date(2026, 11, 3, 17), settings: attendance, records: &records)
    let value = snapshot(date(2026, 11, 3, 17), settings: attendance, records: records)
    let amounts = DailyAmounts.calculate(record: records[value.dayKey]!, asOf: value.date)
    return value.phase == .checkedOut && value.menuText == "已下班 ✓" && value.isSettled
        && near(value.earned, 900) && near(value.freeloadAmount, 150)
        && amounts.lateSeconds == 1800 && amounts.earlySeconds == 3600
}
check("Checkout without arrival makes the whole paid shift free exactly once") {
    var records: [String: DayRecord] = [:]
    engine.checkOut(at: date(2026, 11, 3, 12), settings: attendance, records: &records)
    let value = snapshot(date(2026, 11, 3, 12), settings: attendance, records: records)
    return near(value.earned, 900) && near(value.freeloadAmount, 900) && value.freeloadSeconds == 9 * 3600
}
check("Checkout exactly at start settles a full free day; before start is refused") {
    var records: [String: DayRecord] = [:]
    guard !engine.checkOut(at: date(2026, 11, 3, 8, 59), settings: attendance, records: &records),
          records.isEmpty else { return false }
    engine.checkOut(at: date(2026, 11, 3, 9), settings: attendance, records: &records)
    return near(records["2026-11-03"]!.earnedAmount, 900)
        && near(records["2026-11-03"]!.freeloadAmount, 900)
}
check("Repeated arrival/departure never changes the first saved punches or totals") {
    var records: [String: DayRecord] = [:]
    engine.checkIn(at: date(2026, 11, 3, 9), settings: attendance, records: &records)
    guard !engine.checkIn(at: date(2026, 11, 3, 10), settings: attendance, records: &records) else { return false }
    engine.checkOut(at: date(2026, 11, 3, 18), settings: attendance, records: &records)
    let previous = records
    return !engine.checkOut(at: date(2026, 11, 3, 19), settings: attendance, records: &records)
        && !engine.checkIn(at: date(2026, 11, 3, 19), settings: attendance, records: &records)
        && previous == records
}
check("Late checkout keeps accrued 50 loss and stops subsequent accounting") {
    var records: [String: DayRecord] = [:]
    engine.checkIn(at: date(2026, 11, 3, 9), settings: attendance, records: &records)
    engine.accrue(from: date(2026, 11, 3, 18), to: date(2026, 11, 3, 18, 30),
                  settings: attendance, records: &records)
    engine.checkOut(at: date(2026, 11, 3, 18, 30), settings: attendance, records: &records)
    engine.accrue(from: date(2026, 11, 3, 18, 30), to: date(2026, 11, 3, 23),
                  settings: attendance, records: &records)
    let value = snapshot(date(2026, 11, 3, 23), settings: attendance, records: records)
    return near(value.overtimeLoss, 50) && near(value.earned, 900) && value.freeloadAmount == 0
}
check("Persisted checkout survives relaunch without restarting losses") {
    var state = SavedState()
    state.settings = attendance
    engine.checkOut(at: date(2026, 11, 3, 17), settings: attendance, records: &state.records)
    var loaded = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(state))
    var session = ActiveSession(startingAt: date(2026, 11, 3, 20), uptime: 0)
    session.advance(to: date(2026, 11, 3, 21), uptime: 3600,
                    engine: engine, settings: attendance, records: &loaded.records)
    return loaded.records == state.records
}
check("Opening on a later day refreshes observed history but never creates missing days") {
    var records: [String: DayRecord] = [:]
    engine.observe(at: date(2026, 11, 3, 10), settings: attendance, records: &records)
    engine.observe(at: date(2026, 11, 6, 12), settings: attendance, records: &records)
    return Set(records.keys) == ["2026-11-03", "2026-11-06"]
        && records["2026-11-03"]!.isSettled && near(records["2026-11-03"]!.earnedAmount, 900)
        && records.values.allSatisfy { $0.overtimeLoss == 0 }
}
check("Existing plan stays fixed when salary, hours and the day's calendar are edited") {
    var records: [String: DayRecord] = [:]
    engine.checkIn(at: date(2026, 11, 3, 9), settings: attendance, records: &records)
    var edited = attendance
    edited.monthlySalary *= 2
    edited.startMinute = 10 * 60
    edited.dateOverrides["2026-11-03"] = false
    let current = snapshot(date(2026, 11, 3, 10), settings: edited, records: records)
    return near(current.rate, 100 / 3600) && near(current.earned, 100)
        && current.phase == .working && current.shift?.start == date(2026, 11, 3, 9)
        && engine.plan(on: date(2026, 11, 4), settings: edited, records: records)!.rate > current.rate
}
check("An active shift preserves absolute dates and rate through a timezone change") {
    var records: [String: DayRecord] = [:]
    engine.checkIn(at: date(2026, 11, 3, 9), settings: attendance, records: &records)
    let relocated = EarningsEngine(workCalendar: WorkCalendar(timeZone: TimeZone(identifier: "America/Los_Angeles")!))
    let now = date(2026, 11, 3, 10)
    let value = relocated.snapshot(at: now, settings: attendance, records: records)
    relocated.accrue(from: date(2026, 11, 3, 18), to: date(2026, 11, 3, 18, 30),
                     settings: attendance, records: &records)
    return value.dayKey == "2026-11-03" && value.phase == .working && near(value.earned, 100)
        && near(records[value.dayKey]!.overtimeLoss, 50) && records.count == 1
}
check("A correction clips actual runtime evidence and preserves an audit entry") {
    var records: [String: DayRecord] = [:]
    engine.checkIn(at: date(2026, 11, 3, 9), settings: attendance, records: &records)
    engine.accrue(from: date(2026, 11, 3, 18), to: date(2026, 11, 3, 19),
                  settings: attendance, records: &records)
    let error = engine.correct(key: "2026-11-03", checkIn: date(2026, 11, 3, 9, 30),
                               checkOut: date(2026, 11, 3, 18, 30),
                               now: date(2026, 11, 3, 20), records: &records)
    let record = records["2026-11-03"]!
    return error == nil && near(record.overtimeLoss, 50) && near(record.freeloadAmount, 50)
        && record.manualChanges.count == 1 && record.overtimeIntervals[0].end == date(2026, 11, 3, 19)
}
check("Correcting departure later never backfills gaps when the app was closed") {
    var records: [String: DayRecord] = [:]
    engine.accrue(from: date(2026, 11, 3, 18), to: date(2026, 11, 3, 18, 15),
                  settings: attendance, records: &records)
    engine.accrue(from: date(2026, 11, 3, 19), to: date(2026, 11, 3, 19, 15),
                  settings: attendance, records: &records)
    let error = engine.correct(key: "2026-11-03", checkIn: nil, checkOut: date(2026, 11, 3, 20),
                               now: date(2026, 11, 3, 20), records: &records)
    return error == nil && near(records["2026-11-03"]!.overtimeLoss, 50)
}
check("Corrections preserve legacy losses without unverifiable old runtime details") {
    var legacy = DayRecord()
    legacy.overtimeLoss = 12
    legacy.overtimeSeconds = 300
    var records = ["2026-11-03": legacy]
    engine.observe(at: date(2026, 11, 3, 19), settings: attendance, records: &records)
    let error = engine.correct(key: "2026-11-03", checkIn: date(2026, 11, 3, 9),
                               checkOut: date(2026, 11, 3, 17), now: date(2026, 11, 3, 20), records: &records)
    return error == nil && records["2026-11-03"]!.overtimeLoss == 12
        && records["2026-11-03"]!.legacyLoss == 12 && near(records["2026-11-03"]!.freeloadAmount, 100)
}
check("Invalid corrections and missing historical dates leave records unchanged") {
    var records: [String: DayRecord] = [:]
    engine.checkIn(at: date(2026, 11, 3, 9), settings: attendance, records: &records)
    let previous = records
    let future = engine.correct(key: "2026-11-03", checkIn: nil, checkOut: date(2026, 11, 3, 19),
                                now: date(2026, 11, 3, 18), records: &records)
    let reversed = engine.correct(key: "2026-11-03", checkIn: date(2026, 11, 3, 12),
                                  checkOut: date(2026, 11, 3, 11), now: date(2026, 11, 3, 18), records: &records)
    let missing = engine.correct(key: "2026-11-02", checkIn: nil, checkOut: nil,
                                 now: date(2026, 11, 3, 18), records: &records)
    return future != nil && reversed != nil && missing != nil && previous == records
}
check("Overnight punches stay on the starting day and settle both free segments") {
    var settings = attendance
    settings.startMinute = 22 * 60
    settings.endMinute = 6 * 60
    settings.monthlySalary = 16_800
    var records: [String: DayRecord] = [:]
    engine.checkIn(at: date(2026, 11, 6, 22, 30), settings: settings, records: &records)
    engine.checkOut(at: date(2026, 11, 7, 5), settings: settings, records: &records)
    let value = snapshot(date(2026, 11, 7, 7), settings: settings, records: records)
    return value.dayKey == "2026-11-06" && value.phase == .checkedOut
        && near(value.earned, 800) && near(value.freeloadAmount, 150)
}
check("Old schema loss-only records migrate without invented attendance or earnings") {
    let original = """
    {"version":1,"settings":{"monthlySalary":23456,"startMinute":570,"endMinute":1110,
    "weekdays":[2,3,4,5,6],"dateOverrides":{},"compactMenuBar":false},
    "records":{"2026-11-02":{"overtimeSeconds":100,"overtimeLoss":12.34}}}
    """
    let state = try JSONDecoder().decode(SavedState.self, from: Data(original.utf8))
    let record = state.records["2026-11-02"]!
    return state.settings.monthlySalary == 23456 && state.settings.useChinaHolidayCalendar
        && state.settings.hideMenuBarWhenMirroring && !state.settings.hideWhenExternalDisplay
        && record.plan == nil && record.checkInAt == nil && record.earnedAmount == 0
        && record.freeloadAmount == 0 && record.legacyLoss == 12.34 && record.overtimeSeconds == 100
}
check("New attendance state roundtrips with the frozen plan, runtime evidence and correction audit") {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var state = SavedState()
    state.settings = attendance
    engine.accrue(from: date(2026, 11, 3, 18), to: date(2026, 11, 3, 19),
                  settings: attendance, records: &state.records)
    _ = engine.correct(key: "2026-11-03", checkIn: date(2026, 11, 3, 9, 30),
                       checkOut: date(2026, 11, 3, 18, 30),
                       now: date(2026, 11, 3, 20), records: &state.records)
    let repository = StateRepository(url: url)
    try repository.save(state)
    return try repository.load() == state
}
check("Corrupt stored amounts, intervals and punches are rejected without overwriting their file") {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var state = SavedState()
    engine.observe(at: date(2026, 11, 3, 10), settings: attendance, records: &state.records)
    let original = state.records["2026-11-03"]!
    for index in 0..<4 {
        var record = original
        switch index {
        case 0: record.freeloadAmount = record.earnedAmount + 1
        case 1: record.legacyLoss = -1
        case 2: record.checkOutAt = date(2026, 11, 3, 8)
        default: record.overtimeIntervals = [OvertimeInterval(start: date(), end: date(2026, 11, 3, 1))]
        }
        state.records["2026-11-03"] = record
        try StateRepository(url: url).save(state)
        let bytes = try Data(contentsOf: url)
        do {
            _ = try StateRepository(url: url).load()
            return false
        } catch StateError.invalidRecord {
            guard try Data(contentsOf: url) == bytes else { return false }
        }
    }
    return true
}
check("Privacy manual latch and both automatic switches behave independently for every combination") {
    for manual in [false, true] {
        for mirrored in [false, true] {
            for external in [false, true] {
                for mirrorEnabled in [false, true] {
                    for externalEnabled in [false, true] {
                        var settings = defaults
                        settings.hideMenuBarWhenMirroring = mirrorEnabled
                        settings.hideWhenExternalDisplay = externalEnabled
                        let reason = PresentationPrivacyRule.reason(
                            manual: manual, mirrored: mirrored, external: external, settings: settings
                        )
                        let expected = manual || (mirrored && mirrorEnabled) || (external && externalEnabled)
                        guard (reason != nil) == expected else { return false }
                    }
                }
            }
        }
    }
    return true
}
check("Sensitive attendance amounts and settled menu never reveal currency or salary") {
    var settings = attendance
    settings.sensitiveMode = true
    var records: [String: DayRecord] = [:]
    let before = snapshot(date(2026, 11, 3, 10), settings: settings)
    engine.checkOut(at: date(2026, 11, 3, 17), settings: settings, records: &records)
    let after = snapshot(date(2026, 11, 3, 17), settings: settings, records: records)
    let display = EarningsPresentation(snapshot: before, settings: settings)
    let settled = EarningsPresentation(snapshot: after, settings: settings)
    return display.headline == "今天已白嫖到" && display.menuText.contains("白嫖")
        && settled.menuText == "已下班 ✓"
        && [display.amount, display.freeload, display.overtime, settled.earned, settled.freeload].allSatisfy {
            !$0.contains("¥") && !$0.contains("18900")
        }
}

print("\n\(passed) passed; \(failures.count) failed")
if !failures.isEmpty {
    fputs(failures.joined(separator: "\n") + "\n", stderr)
    exit(1)
}
