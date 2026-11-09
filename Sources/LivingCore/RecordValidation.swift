import Foundation

extension DayRecord {
    /// Validates stored amounts, plan, punches and runtime evidence for key; returns false on corrupt data.
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
              plan.rate.isFinite, plan.rate >= 0, (1...31).contains(plan.monthWorkdays),
              [shift.day, shift.start, shift.end, shift.overtimeEnd].allSatisfy({
                  $0.timeIntervalSinceReferenceDate.isFinite
              }),
              shift.key == key, WorkCalendar(timeZone: zone).key(for: shift.day) == key,
              shift.start >= shift.day, shift.start.timeIntervalSince(shift.day) < 26 * 3600,
              shift.duration > 0, shift.duration <= 25 * 3600,
              shift.overtimeEnd >= shift.end, shift.overtimeEnd.timeIntervalSince(shift.end) <= 26 * 3600,
              earnedAmount <= shift.duration * plan.rate + 0.000_001,
              freeloadSeconds <= shift.duration + 0.000_001,
              validPunches(arrival: checkInAt, departure: checkOutAt, shift: shift),
              legacyLoss <= overtimeLoss + 0.000_001,
              legacySeconds <= overtimeSeconds + 0.000_001 else { return false }
        guard overtimeIntervals.allSatisfy({
            $0.start.timeIntervalSinceReferenceDate.isFinite && $0.end.timeIntervalSinceReferenceDate.isFinite
                && $0.start >= shift.end && $0.end > $0.start && $0.end <= shift.overtimeEnd
        }) else { return false }
        return manualChanges.allSatisfy {
            $0.changedAt.timeIntervalSinceReferenceDate.isFinite
                && validPunches(arrival: $0.oldCheckIn, departure: $0.oldCheckOut, shift: shift)
                && validPunches(arrival: $0.newCheckIn, departure: $0.newCheckOut, shift: shift)
        }
    }

    /// Checks optional arrival/departure against shift bounds and ordering; returns whether punches are valid.
    private func validPunches(arrival: Date?, departure: Date?, shift: WorkShift) -> Bool {
        if let arrival {
            guard arrival.timeIntervalSinceReferenceDate.isFinite,
                  arrival >= shift.day, arrival < shift.overtimeEnd else { return false }
        }
        if let departure {
            guard departure.timeIntervalSinceReferenceDate.isFinite,
                  departure >= shift.start, departure <= shift.overtimeEnd else { return false }
        }
        if let arrival, let departure, departure < arrival { return false }
        return true
    }
}
