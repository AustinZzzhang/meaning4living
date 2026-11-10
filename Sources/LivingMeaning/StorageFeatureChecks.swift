import Foundation
import LivingCore

enum StorageFeatureChecks {
    /// Exercises unreadable-file exit/update and real write-failure guards in temp files; returns named checks.
    static func run() throws -> [String: Bool] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var invalid = SavedState()
        invalid.hasConfirmedSchedule = true
        var record = DayRecord()
        record.overtimeSeconds = -1
        invalid.records["2026-11-09"] = record
        let fixtures = [
            ("invalidRecord", try JSONEncoder().encode(invalid)),
            ("invalidJSON", Data("unreadable fixture".utf8))
        ]
        var checks: [String: Bool] = [:]
        for (name, bytes) in fixtures {
            let url = directory.appendingPathComponent("\(name).json")
            try bytes.write(to: url)
            let store = AppStore(repository: StateRepository(url: url), isolated: true)
            checks["\(name)-loadErrorVisible"] = store.storageError != nil
            checks["\(name)-settingsCannotOverwrite"] = store.updateSettings(
                WorkSettings(), confirmSchedule: true
            ) != nil
            store.tick(at: Date().addingTimeInterval(86_400))
            checks["\(name)-noInventedRecords"] = store.records.isEmpty && !store.hasConfirmedSchedule
            checks["\(name)-quitAndUpdateAllowed"] = store.finishSession() == nil
            checks["\(name)-originalBytesPreserved"] = try Data(contentsOf: url) == bytes
        }
        let recoveredURL = directory.appendingPathComponent("rescheduled.json")
        let calendar = WorkCalendar()
        let engine = EarningsEngine(workCalendar: calendar)
        let day = calendar.calendar.date(from: DateComponents(year: 2026, month: 11, day: 9))!
        var rescheduled = SavedState()
        rescheduled.hasConfirmedSchedule = true
        rescheduled.settings.startMinute = 10 * 60 + 50
        rescheduled.settings.endMinute = 11 * 60
        let editedAt = calendar.time(17 * 60, on: day)
        engine.checkIn(at: calendar.time(16 * 60, on: day),
                       settings: rescheduled.settings, records: &rescheduled.records)
        engine.accrue(from: calendar.time(16 * 60, on: day), to: editedAt,
                      settings: rescheduled.settings, records: &rescheduled.records)
        rescheduled.settings.endMinute = 23 * 60
        engine.reconcileCurrentData(at: editedAt, settings: rescheduled.settings, records: &rescheduled.records)
        try JSONEncoder().encode(rescheduled).write(to: recoveredURL)
        let recovered = AppStore(
            repository: StateRepository(url: recoveredURL),
            date: calendar.addingDays(1, to: editedAt), isolated: true
        )
        checks["rescheduledFileLoadsWithoutReset"] = recovered.storageError == nil
            && recovered.settings == rescheduled.settings && recovered.records == rescheduled.records
        checks["recoveredStoreCanFinishSession"] = recovered.finishSession() == nil
        let writable = directory.appendingPathComponent("valid.json")
        let repository = StateRepository(url: writable)
        try repository.save(SavedState())
        let store = AppStore(repository: repository, isolated: true)
        try FileManager.default.removeItem(at: writable)
        try FileManager.default.createDirectory(at: writable, withIntermediateDirectories: false)
        checks["actualWriteFailureStillBlocksQuitAndUpdate"] = store.finishSession() != nil
        return checks
    }
}
