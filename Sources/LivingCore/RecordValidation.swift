import Foundation

extension DayRecord {
    /// Validates amounts and absolute evidence for key independently of edited work hours; returns false if invalid.
    func isValid(for key: String) -> Bool {
        let amounts = [overtimeSeconds, overtimeLoss, earnedAmount, freeloadSeconds,
                       freeloadAmount, legacyLoss, legacySeconds]
        guard amounts.allSatisfy({ $0.isFinite && $0 >= 0 }),
              freeloadAmount <= earnedAmount + 0.000_001 else { return false }
        guard let plan else {
            return checkInAt == nil && checkOutAt == nil && overtimeIntervals.isEmpty && manualChanges.isEmpty
                && earnedAmount == 0 && freeloadAmount == 0 && freeloadSeconds == 0
        }
        let shift = plan.shift
        guard let zone = TimeZone(identifier: plan.timeZoneID),
              [shift.day, shift.start, shift.end, shift.overtimeEnd].allSatisfy({
                  $0.timeIntervalSinceReferenceDate.isFinite
              }) else { return false }
        let calendar = WorkCalendar(timeZone: zone)
        // Settings can move a shift between daytime and overnight. Actual evidence keeps its original timestamps.
        // Any supported schedule for this record ends no later than midnight after the following calendar day.
        let evidenceEnd = calendar.addingDays(2, to: calendar.calendar.startOfDay(for: shift.day))
        guard plan.rate.isFinite, plan.rate >= 0, (1...31).contains(plan.monthWorkdays),
              shift.key == key, calendar.key(for: shift.day) == key,
              calendar.calendar.startOfDay(for: shift.day) == shift.day,
              shift.start >= shift.day, shift.start.timeIntervalSince(shift.day) < 26 * 3600,
              shift.duration > 0, shift.duration <= 25 * 3600,
              shift.overtimeEnd >= shift.end, shift.overtimeEnd.timeIntervalSince(shift.end) <= 26 * 3600,
              shift.overtimeEnd <= evidenceEnd,
              earnedAmount <= shift.duration * plan.rate + 0.000_001,
              freeloadSeconds <= shift.duration + 0.000_001,
              validPunches(arrival: checkInAt, departure: checkOutAt, day: shift.day, end: evidenceEnd),
              legacyLoss <= overtimeLoss + 0.000_001,
              legacySeconds <= overtimeSeconds + 0.000_001 else { return false }
        guard overtimeIntervals.allSatisfy({
            $0.start.timeIntervalSinceReferenceDate.isFinite && $0.end.timeIntervalSinceReferenceDate.isFinite
                && $0.start >= shift.day && $0.end > $0.start && $0.end <= evidenceEnd
        }) else { return false }
        return manualChanges.allSatisfy {
            $0.changedAt.timeIntervalSinceReferenceDate.isFinite
                && validPunches(arrival: $0.oldCheckIn, departure: $0.oldCheckOut, day: shift.day, end: evidenceEnd)
                && validPunches(arrival: $0.newCheckIn, departure: $0.newCheckOut, day: shift.day, end: evidenceEnd)
        }
    }

    /// Checks arrival/departure within the record's day/end evidence window and order; returns whether valid.
    private func validPunches(arrival: Date?, departure: Date?, day: Date, end: Date) -> Bool {
        if let arrival {
            guard arrival.timeIntervalSinceReferenceDate.isFinite,
                  arrival >= day, arrival < end else { return false }
        }
        if let departure {
            guard departure.timeIntervalSinceReferenceDate.isFinite,
                  departure >= day, departure <= end else { return false }
        }
        if let arrival, let departure, departure < arrival { return false }
        return true
    }
}
