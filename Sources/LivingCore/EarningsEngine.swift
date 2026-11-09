import Foundation

public struct EarningsEngine {
    public let workCalendar: WorkCalendar

    /// Creates a pure calculator using workCalendar; returns a new engine.
    public init(workCalendar: WorkCalendar = WorkCalendar()) {
        self.workCalendar = workCalendar
    }

    /// Resolves a recorded plan before current settings for day; returns a frozen or prospective plan.
    public func plan(on day: Date, settings: WorkSettings, records: [String: DayRecord]) -> RecordedShift? {
        if let existing = records[workCalendar.key(for: day)]?.plan { return existing }
        guard let shift = workCalendar.shift(on: day, settings: settings) else { return nil }
        let totals = workCalendar.monthTotals(for: day, settings: settings)
        return RecordedShift(
            shift: shift, rate: totals.seconds > 0 ? settings.monthlySalary / totals.seconds : 0,
            monthWorkdays: totals.days, timeZoneID: workCalendar.calendar.timeZone.identifier,
            calendarLabel: workCalendar.scheduleLabel(day, settings: settings)
        )
    }

    /// Selects today's or an active overnight plan for date using records and settings; returns the applicable plan.
    public func currentPlan(
        at date: Date, settings: WorkSettings, records: [String: DayRecord]
    ) -> RecordedShift? {
        // Absolute dates preserve the active shift when the system timezone changes.
        if let active = records.values.compactMap(\.plan).filter({
            date >= $0.shift.day && date < $0.shift.overtimeEnd
        }).min(by: { $0.shift.start < $1.shift.start }) {
            return active
        }
        let today = workCalendar.calendar.startOfDay(for: date)
        let current = plan(on: today, settings: settings, records: records)
        if let current, date >= current.shift.start, date < current.shift.overtimeEnd { return current }
        let previous = plan(on: workCalendar.addingDays(-1, to: today), settings: settings, records: records)
        if let previous, date >= previous.shift.start, date < previous.shift.overtimeEnd { return previous }
        return current.flatMap { date < $0.shift.start ? $0 : nil }
    }

    /// Calculates attendance from date/settings/records without writing storage; returns a display snapshot.
    public func snapshot(
        at date: Date, settings: WorkSettings, records: [String: DayRecord]
    ) -> EarningsSnapshot {
        let selected = currentPlan(at: date, settings: settings, records: records)
        let shift = selected?.shift
        let dayKey = shift?.key ?? workCalendar.key(for: date)
        var record = records[dayKey] ?? DayRecord()
        record.plan = selected
        let amounts = DailyAmounts.calculate(record: record, asOf: date)
        let phase: WorkPhase
        let timer: TimeInterval
        if let shift {
            if let departure = record.checkOutAt, departure <= date {
                phase = .checkedOut
                timer = 0
            } else if date < shift.start {
                phase = .beforeWork
                timer = shift.start.timeIntervalSince(date)
            } else if date < shift.end {
                phase = (record.checkInAt.map { $0 <= date } ?? false) ? .working : .awaitingCheckIn
                timer = shift.end.timeIntervalSince(date)
            } else {
                phase = .overtime
                timer = date.timeIntervalSince(shift.end)
            }
        } else {
            phase = .rest
            timer = 0
        }
        let rate = selected?.rate ?? workCalendar.rate(for: date, settings: settings)
        let total = (shift?.duration ?? 0) * rate
        return EarningsSnapshot(
            date: date, phase: phase, dayKey: dayKey,
            amount: phase == .overtime ? -record.overtimeLoss : amounts.earned,
            earned: amounts.earned, overtimeLoss: record.overtimeLoss, rate: rate, timerSeconds: timer,
            progress: total > 0 ? min(1, amounts.earned / total) : 0,
            monthWorkdays: selected?.monthWorkdays ?? workCalendar.monthTotals(for: date, settings: settings).days,
            shift: shift, freeloadAmount: amounts.freeload, freeloadSeconds: amounts.freeSeconds,
            scheduledAmount: total, checkInAt: record.checkInAt, checkOutAt: record.checkOutAt,
            isSettled: phase == .checkedOut || record.isSettled
        )
    }

    /// Records only the day actually opened and refreshes existing records at date; returns nothing.
    public func observe(at date: Date, settings: WorkSettings, records: inout [String: DayRecord]) {
        if let selected = currentPlan(at: date, settings: settings, records: records),
           date >= selected.shift.start {
            attach(selected, records: &records)
        }
        refreshRecords(at: date, records: &records)
    }

    /// Rebuilds current-day plans using new settings while retaining historical plans; returns nothing.
    public func reconcileCurrentData(at date: Date, settings: WorkSettings, records: inout [String: DayRecord]) {
        var currentKeys = Set([workCalendar.key(for: date)])
        if let active = records.values.compactMap(\.plan).first(where: {
            date >= $0.shift.day && date < $0.shift.overtimeEnd
        }) {
            currentKeys.insert(active.shift.key)
        }
        for key in currentKeys {
            guard var record = records[key],
                  let previous = record.plan,
                  let replacement = plan(on: previous.shift.day, settings: settings, records: [:]),
                  replacement.shift.key == key else { continue }
            record.plan = replacement
            let amounts = DailyAmounts.calculate(record: record, asOf: date)
            record.earnedAmount = amounts.earned
            record.freeloadAmount = amounts.freeload
            record.freeloadSeconds = amounts.freeSeconds
            record.isSettled = record.checkOutAt != nil || date >= replacement.shift.overtimeEnd
            recalculateLoss(&record)
            records[key] = record
        }
    }

    /// Refreshes amounts and settlement for existing records at date; returns nothing and never creates history.
    private func refreshRecords(at date: Date, records: inout [String: DayRecord]) {
        for key in Array(records.keys) {
            guard var record = records[key], let selected = record.plan, !record.isSettled else { continue }
            let amounts = DailyAmounts.calculate(record: record, asOf: date)
            record.earnedAmount = amounts.earned
            record.freeloadAmount = amounts.freeload
            record.freeloadSeconds = amounts.freeSeconds
            record.isSettled = record.checkOutAt != nil || date >= selected.shift.overtimeEnd
            records[key] = record
        }
    }

    /// Accrues runtime-only overtime between start/end, clipped by departure, using frozen rates; returns nothing.
    public func accrue(
        from start: Date, to end: Date, settings: WorkSettings, records: inout [String: DayRecord]
    ) {
        guard end > start else { return }
        var plans = records.values.compactMap(\.plan).filter {
            end > $0.shift.start && start < $0.shift.overtimeEnd
        }
        let frozenKeys = Set(plans.map { $0.shift.key })
        var day = workCalendar.addingDays(-1, to: workCalendar.calendar.startOfDay(for: start))
        let last = workCalendar.calendar.startOfDay(for: end)
        while day <= last {
            if let selected = plan(on: day, settings: settings, records: records),
               !frozenKeys.contains(selected.shift.key),
               end > selected.shift.start, start < selected.shift.overtimeEnd,
               !plans.contains(where: {
                   selected.shift.start < $0.shift.overtimeEnd && selected.shift.start >= $0.shift.day
               }) {
                plans.append(selected)
            }
            day = workCalendar.addingDays(1, to: day)
        }
        for selected in plans {
            let shift = selected.shift
            attach(selected, records: &records)
            var record = records[shift.key]!
            let lower = max(start, shift.end)
            let upper = min(end, min(shift.overtimeEnd, record.checkOutAt ?? shift.overtimeEnd))
            if upper > lower && !record.isSettled {
                if let previous = record.overtimeIntervals.last,
                   abs(previous.end.timeIntervalSince(lower)) < 0.01 {
                    record.overtimeIntervals[record.overtimeIntervals.count - 1].end = upper
                } else {
                    record.overtimeIntervals.append(OvertimeInterval(start: lower, end: upper))
                }
                recalculateLoss(&record)
                records[shift.key] = record
            }
        }
        refreshRecords(at: end, records: &records)
    }

    /// Records arrival, including before shift start; returns false for rests, repeated punches or finished shifts.
    @discardableResult
    public func checkIn(at date: Date, settings: WorkSettings, records: inout [String: DayRecord]) -> Bool {
        guard let selected = currentPlan(at: date, settings: settings, records: records) else { return false }
        attach(selected, records: &records)
        var record = records[selected.shift.key]!
        guard record.checkInAt == nil, record.checkOutAt == nil, !record.isSettled else { return false }
        record.checkInAt = date
        records[selected.shift.key] = record
        observe(at: date, settings: settings, records: &records)
        return true
    }

    /// Settles all planned income and the free-time subset at departure date; returns false if already settled.
    @discardableResult
    public func checkOut(at date: Date, settings: WorkSettings, records: inout [String: DayRecord]) -> Bool {
        guard let selected = currentPlan(at: date, settings: settings, records: records),
              date >= selected.shift.start else { return false }
        attach(selected, records: &records)
        var record = records[selected.shift.key]!
        guard record.checkOutAt == nil, !record.isSettled,
              record.checkInAt.map({ $0 <= date }) ?? true else { return false }
        record.checkOutAt = date
        recalculateLoss(&record)
        records[selected.shift.key] = record
        observe(at: date, settings: settings, records: &records)
        return true
    }

    /// Corrects punches for a recorded day, preserving runtime evidence and legacy losses; returns an error or nil.
    public func correct(
        key: String, checkIn: Date?, checkOut: Date?, now: Date, records: inout [String: DayRecord]
    ) -> String? {
        guard var record = records[key], let selected = record.plan else { return "该日没有可更正的打卡记录。" }
        let shift = selected.shift
        if let checkIn, checkIn < shift.day || checkIn > now || checkIn >= shift.overtimeEnd {
            return "上班打卡须在班次日期至班次结束区间内，不能在未来。"
        }
        if let checkOut, checkOut < shift.start || checkOut > now || checkOut > shift.overtimeEnd {
            return "下班打卡不能早于规定上班时间、晚于班次记录区间或在未来。"
        }
        if let checkIn, let checkOut, checkOut < checkIn { return "下班打卡不能早于上班打卡。" }
        if checkIn == record.checkInAt && checkOut == record.checkOutAt { return nil }
        record.manualChanges.append(AttendanceChange(
            changedAt: now, oldCheckIn: record.checkInAt, oldCheckOut: record.checkOutAt,
            newCheckIn: checkIn, newCheckOut: checkOut
        ))
        record.checkInAt = checkIn
        record.checkOutAt = checkOut
        let amounts = DailyAmounts.calculate(record: record, asOf: now)
        record.earnedAmount = amounts.earned
        record.freeloadAmount = amounts.freeload
        record.freeloadSeconds = amounts.freeSeconds
        record.isSettled = checkOut != nil || now >= shift.overtimeEnd
        recalculateLoss(&record)
        records[key] = record
        return nil
    }

    /// Pins selected plan once and retains previously stored legacy losses; returns nothing.
    private func attach(_ selected: RecordedShift, records: inout [String: DayRecord]) {
        var record = records[selected.shift.key] ?? DayRecord()
        guard record.plan == nil else { return }
        record.plan = selected
        record.legacyLoss = record.overtimeLoss
        record.legacySeconds = record.overtimeSeconds
        records[selected.shift.key] = record
    }

    /// Recalculates record loss only from recorded runtime intersections plus legacy totals; returns nothing.
    private func recalculateLoss(_ record: inout DayRecord) {
        guard let plan = record.plan else { return }
        let cutoff = min(plan.shift.overtimeEnd, record.checkOutAt ?? plan.shift.overtimeEnd)
        let seconds = record.overtimeIntervals.reduce(0.0) {
            $0 + max(0, min($1.end, cutoff).timeIntervalSince(max($1.start, plan.shift.end)))
        }
        record.overtimeSeconds = record.legacySeconds + seconds
        record.overtimeLoss = record.legacyLoss + seconds * plan.rate
    }
}

public struct ActiveSession {
    public private(set) var checkpoint: Date
    public private(set) var uptimeCheckpoint: TimeInterval

    /// Starts a session with wall date and continuous uptime; returns a fresh, nonpersisted checkpoint.
    public init(startingAt date: Date, uptime: TimeInterval) {
        checkpoint = date
        uptimeCheckpoint = uptime
    }

    /// Charges engine/settings overtime using continuous uptime; updates records and checkpoints, returns nothing.
    public mutating func advance(
        to date: Date, uptime: TimeInterval, engine: EarningsEngine,
        settings: WorkSettings, records: inout [String: DayRecord]
    ) {
        guard uptime.isFinite, uptime >= uptimeCheckpoint else { return }
        engine.accrue(from: checkpoint, to: checkpoint.addingTimeInterval(uptime - uptimeCheckpoint),
                      settings: settings, records: &records)
        checkpoint = date
        uptimeCheckpoint = uptime
    }
}
