import AppKit
import SwiftUI
import LivingCore

enum PreviewExporter {
    /// Exports rendered views and native checks to directory, then terminates; returns nothing.
    static func export(to directory: URL) {
        DispatchQueue.main.async {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let calendar = WorkCalendar()
                let day = calendar.calendar.date(from: DateComponents(year: 2026, month: 11, day: 3))!
                var state = SavedState()
                let workingDate = calendar.time(16 * 60 + 11, on: day).addingTimeInterval(24)
                let engine = EarningsEngine(workCalendar: calendar)
                // Use engine fixtures to keep UI previews independent from production storage.
                engine.checkIn(at: calendar.time(10 * 60, on: day),
                               settings: state.settings, records: &state.records)
                engine.observe(at: workingDate, settings: state.settings, records: &state.records)
                let working = AppStore(repository: nil, date: workingDate, previewState: state)
                try render(
                    RootView(store: working, quit: {}),
                    size: NSSize(width: 1080, height: 840),
                    to: directory.appendingPathComponent("dashboard-working.png")
                )
                let overtimeDate = calendar.time(18 * 60 + 54, on: day).addingTimeInterval(16)
                engine.accrue(from: calendar.time(state.settings.endMinute, on: day), to: overtimeDate,
                              settings: state.settings, records: &state.records)
                let overtime = AppStore(repository: nil, date: overtimeDate, previewState: state)
                try render(
                    RootView(store: overtime, quit: {}),
                    size: NSSize(width: 1080, height: 840),
                    to: directory.appendingPathComponent("dashboard-overtime.png")
                )
                for page in [AppPage.calendar, .settings, .display, .updates] {
                    working.selectedPage = page
                    try render(
                        RootView(store: working, quit: {}),
                        size: NSSize(width: 1080, height: 840),
                        to: directory.appendingPathComponent("page-\(page.id).png")
                    )
                }
                try render(
                    MenuPopoverView(store: working, openApp: {}, quit: {}),
                    size: NSSize(width: 324, height: 500),
                    to: directory.appendingPathComponent("menu-working.png")
                )
                try render(
                    MenuPopoverView(store: overtime, openApp: {}, quit: {}),
                    size: NSSize(width: 324, height: 500),
                    to: directory.appendingPathComponent("menu-overtime.png")
                )
                for preset in [ItemPreset.fashion, .electronics, .food] {
                    state.settings.sensitiveMode = true
                    state.settings.itemPreset = preset
                    let privateStore = AppStore(repository: nil, date: workingDate, previewState: state)
                    try render(
                        RootView(store: privateStore, quit: {}),
                        size: NSSize(width: 1080, height: 840),
                        to: directory.appendingPathComponent("sensitive-\(preset.rawValue).png")
                    )
                }
                let privateStore = AppStore(repository: nil, date: overtimeDate, previewState: state)
                try render(
                    MenuPopoverView(store: privateStore, openApp: {}, quit: {}),
                    size: NSSize(width: 324, height: 500),
                    to: directory.appendingPathComponent("sensitive-overtime-menu.png")
                )
                try attendancePreviews(to: directory, calendar: calendar)
                privateStore.selectedPage = .settings
                privateStore.settingsLock.refresh()
                _ = privateStore.settingsLock.setPassword(
                    "preview-only-123", confirmation: "preview-only-123", current: ""
                )
                privateStore.settingsLock.lock()
                try render(
                    RootView(store: privateStore, quit: {}),
                    size: NSSize(width: 1080, height: 840),
                    to: directory.appendingPathComponent("settings-locked.png")
                )
                let featureChecks = try PrivacyFeatureChecks.run()
                guard featureChecks.values.allSatisfy({ $0 }) else {
                    throw NSError(domain: "LivingMeaning.Privacy", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "\(featureChecks.filter { !$0.value })"
                    ])
                }
                try JSONSerialization.data(withJSONObject: featureChecks, options: [.prettyPrinted, .sortedKeys])
                    .write(to: directory.appendingPathComponent("feature-checks.json"), options: .atomic)
                let touchBar = TouchBarController()
                touchBar.update(working.snapshot)
                let count = touchBar.materializeItems()
                let workingValues = touchBar.displayedValues()
                touchBar.update(overtime.snapshot)
                let overtimeValues = touchBar.displayedValues()
                let saved = try verifyPersistence(in: directory)
                let failuresHandled = try verifyStorageFailures(in: directory)
                let expectedWorking = [
                    working.snapshot.amountText, working.snapshot.timerCaption, WorkPhase.working.title
                ]
                let expectedOvertime = [
                    overtime.snapshot.amountText, overtime.snapshot.timerCaption, WorkPhase.overtime.title
                ]
                let labelsVerified = workingValues == expectedWorking && overtimeValues == expectedOvertime
                guard count == 4, saved, failuresHandled, labelsVerified else {
                    throw NSError(domain: "LivingMeaning.Preview", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "UI 冒烟检查未通过"
                    ])
                }
                let report: [String: Any] = [
                    "renderer": "NSHostingView.cacheDisplay",
                    "nativeTouchBarItems": count,
                    "nativeTouchBarLabelsVerified": labelsVerified,
                    "workingMenu": working.snapshot.menuText,
                    "workingTimer": working.snapshot.timerCaption,
                    "overtimeMenu": overtime.snapshot.menuText,
                    "overtimeTimer": overtime.snapshot.timerCaption,
                    "physicalTouchBarTested": false,
                    "settingsPersistence": saved,
                    "failedSavesNeverClaimSuccess": failuresHandled,
                    "source": "deterministic preview state; production data is not read or written"
                ]
                let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: directory.appendingPathComponent("ui-smoke-report.json"), options: .atomic)
                print("Rendered views exported; Touch Bar items: \(count); feature checks: \(featureChecks.count)")
                NSApp.terminate(nil)
            } catch {
                fputs("Preview export failed: \(error)\n", stderr)
                exit(1)
            }
        }
    }

    /// Renders awaiting, settled, holiday and privacy states into directory using calendar fixtures; returns nothing.
    private static func attendancePreviews(to directory: URL, calendar: WorkCalendar) throws {
        let engine = EarningsEngine(workCalendar: calendar)
        let day = calendar.calendar.date(from: DateComponents(year: 2026, month: 11, day: 3))!
        let date = calendar.time(10 * 60, on: day)
        var state = SavedState()
        state.settings.startMinute = 9 * 60
        state.settings.endMinute = 18 * 60
        state.settings.monthlySalary = 18_900
        engine.observe(at: date, settings: state.settings, records: &state.records)
        let awaiting = AppStore(repository: nil, date: date, previewState: state)
        try render(RootView(store: awaiting, quit: {}), size: NSSize(width: 1080, height: 840),
                   to: directory.appendingPathComponent("dashboard-awaiting.png"))
        try render(MenuPopoverView(store: awaiting, openApp: {}, quit: {}), size: NSSize(width: 324, height: 500),
                   to: directory.appendingPathComponent("menu-awaiting.png"))
        engine.checkIn(at: calendar.time(9 * 60 + 30, on: day), settings: state.settings, records: &state.records)
        let departure = calendar.time(17 * 60, on: day)
        engine.checkOut(at: departure, settings: state.settings, records: &state.records)
        let settled = AppStore(repository: nil, date: departure, previewState: state)
        try render(RootView(store: settled, quit: {}), size: NSSize(width: 1080, height: 840),
                   to: directory.appendingPathComponent("dashboard-settled.png"))
        try render(MenuPopoverView(store: settled, openApp: {}, quit: {}), size: NSSize(width: 324, height: 500),
                   to: directory.appendingPathComponent("menu-settled.png"))
        try render(AttendanceEditor(store: settled, key: "2026-11-03", record: state.records["2026-11-03"]!),
                   size: NSSize(width: 556, height: 380),
                   to: directory.appendingPathComponent("attendance-editor.png"))
        let holiday = calendar.calendar.date(from: DateComponents(year: 2026, month: 10, day: 10, hour: 17))!
        let holidayStore = AppStore(repository: nil, date: holiday, previewState: SavedState())
        holidayStore.selectedPage = .calendar
        try render(RootView(store: holidayStore, quit: {}), size: NSSize(width: 1080, height: 840),
                   to: directory.appendingPathComponent("calendar-holiday.png"))
        settled.setPresentationPrivacy(hidden: true, reason: "检测到屏幕镜像")
        try render(RootView(store: settled, quit: {}), size: NSSize(width: 1080, height: 840),
                   to: directory.appendingPathComponent("presentation-privacy.png"))
    }

    /// Renders view at size to PNG url through AppKit; returns nothing and throws on failure.
    private static func render<V: View>(_ view: V, size: NSSize, to url: URL) throws {
        let host = NSHostingView(rootView: view.environment(\.locale, Locale(identifier: "zh_CN")))
        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: -12000, y: -12000), size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = host
        host.setFrameSize(size)
        window.orderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            throw NSError(domain: "LivingMeaning.Preview", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "无法创建视图位图"
            ])
        }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "LivingMeaning.Preview", code: 2)
        }
        try data.write(to: url, options: .atomic)
        window.orderOut(nil)
        window.close()
    }

    /// Exercises real store settings edits and reloads in a temporary file; returns a verification result.
    private static func verifyPersistence(in directory: URL) throws -> Bool {
        let url = directory.appendingPathComponent("smoke-state.json")
        let repository = StateRepository(url: url)
        let store = AppStore(repository: repository, isolated: true)
        var settings = store.settings
        settings.monthlySalary = 23456
        settings.startMinute = 8 * 60
        settings.endMinute = 17 * 60
        guard store.updateSettings(settings, confirmSchedule: true) == nil else { return false }
        store.finishSession()
        let loaded = try repository.load()
        try FileManager.default.removeItem(at: url)
        return loaded.settings == settings
    }

    /// Tests failed writes and unreadable input under directory; returns true only if saves report errors.
    private static func verifyStorageFailures(in directory: URL) throws -> Bool {
        let blocked = directory.appendingPathComponent("storage-blocker")
        try Data("a file, not a directory".utf8).write(to: blocked)
        defer { try? FileManager.default.removeItem(at: blocked) }
        let unwritable = AppStore(
            repository: StateRepository(url: blocked.appendingPathComponent("state.json")), isolated: true
        )
        var changed = WorkSettings()
        changed.monthlySalary = 12345
        let writeFailed = unwritable.updateSettings(changed) != nil
        let invalid = directory.appendingPathComponent("invalid-state.json")
        let original = Data("invalid JSON preserved".utf8)
        try original.write(to: invalid)
        defer { try? FileManager.default.removeItem(at: invalid) }
        let unreadable = AppStore(repository: StateRepository(url: invalid), isolated: true)
        let blockedSave = unreadable.updateSettings(changed) != nil
        return try writeFailed && blockedSave && Data(contentsOf: invalid) == original
    }
}
