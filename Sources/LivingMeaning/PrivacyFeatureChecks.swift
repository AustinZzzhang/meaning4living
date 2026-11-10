import Foundation
import LivingCore

enum PrivacyFeatureChecks {
    /// Exercises isolated settings locks, real test-only keychain and privacy UI projections; returns named results.
    static func run() throws -> [String: Bool] {
        var checks: [String: Bool] = [:]
        let vault = MemoryCredentialVault()
        let gate = SettingsLock(vault: vault)
        gate.refresh()
        checks["unprotectedSettingsVisible"] = gate.canView && !gate.isProtected
        let password = "fixture-only-123456"
        checks["enablePassword"] = gate.setPassword(password, confirmation: password, current: "") == nil
        gate.lock()
        checks["lockedSettingsHidden"] = !gate.canView
        checks["wrongPasswordStaysLocked"] = !gate.unlock("incorrect") && !gate.canView
        checks["correctPasswordUnlocks"] = gate.unlock(password) && gate.canView
        let replacement = "fixture-only-replacement"
        checks["changeRequiresOldPassword"] = gate.setPassword(
            replacement, confirmation: replacement, current: "incorrect"
        ) != nil
        checks["changePassword"] = gate.setPassword(
            replacement, confirmation: replacement, current: password
        ) == nil
        gate.lock()
        checks["oldPasswordRevoked"] = !gate.unlock(password)
        checks["replacementPasswordWorks"] = gate.unlock(replacement)
        vault.failWrites = true
        checks["failedDisableRetainsProtection"] = gate.disable(current: replacement) != nil && gate.isProtected
        vault.failWrites = false
        gate.lock()
        checks["failedWriteKeepsVerifier"] = gate.unlock(replacement)
        checks["disablePassword"] = gate.disable(current: replacement) == nil && !gate.isProtected && gate.canView

        vault.failReads = true
        gate.refresh()
        checks["keychainUnavailableFailsClosed"] = !gate.canView && gate.error != nil
        vault.failReads = false
        vault.data = Data("malformed verifier".utf8)
        gate.refresh()
        checks["corruptVerifierFailsClosed"] = !gate.canView
        vault.data = nil
        gate.refresh()
        _ = gate.setPassword(password, confirmation: password, current: "")
        gate.lock()
        for _ in 0..<5 { _ = gate.unlock("wrong") }
        checks["repeatedFailuresAreThrottled"] = !gate.unlock(password) && !gate.canView

        let service = "local.livingmeaning.test.\(UUID().uuidString)"
        let keychain = KeychainCredentialVault(service: service)
        defer { try? keychain.write(nil) }
        let data = try JSONEncoder().encode(PasswordCredential(password: password))
        try keychain.write(data)
        checks["keychainRoundTrip"] = try keychain.read() == data
        let loaded = SettingsLock(vault: keychain)
        loaded.refresh()
        checks["relaunchStartsLocked"] = loaded.isProtected && !loaded.canView
        checks["relaunchUnlocks"] = loaded.unlock(password)
        checks["keychainRemoval"] = loaded.disable(current: password) == nil
        checks["keychainRemovalVerified"] = try keychain.read() == nil

        let preview = AppStore(repository: nil, previewState: SavedState())
        preview.settingsLock.refresh()
        _ = preview.settingsLock.setPassword(password, confirmation: password, current: "")
        preview.selectedPage = .settings
        preview.selectedPage = .home
        checks["leavingSettingsRelocks"] = !preview.settingsLock.canView

        let touchBar = TouchBarController()
        _ = touchBar.materializeItems()
        var settings = WorkSettings()
        settings.sensitiveMode = true
        for preset in [ItemPreset.fashion, .electronics, .food, .custom] {
            settings.itemPreset = preset
            if preset == .custom { settings.customItemTiers = [ItemTier(minimum: 0, item: "一份快乐")] }
            touchBar.update(preview.snapshot, settings: settings)
            checks["privateTouchBar-\(preset.rawValue)"] = touchBar.displayedValues().allSatisfy { !$0.contains("¥") }
        }
        let visibleValues = touchBar.displayedValues()
        touchBar.setPrivacy(true)
        checks["presentationRedactsNativeTouchBar"] = touchBar.displayedValues().allSatisfy(\.isEmpty)
        touchBar.update(preview.snapshot, settings: settings)
        checks["timerUpdatesCannotUnhideTouchBar"] = touchBar.displayedValues().allSatisfy(\.isEmpty)
        touchBar.setPrivacy(false)
        checks["presentationRestoresNativeTouchBar"] = touchBar.displayedValues() == visibleValues
        _ = preview.settingsLock.unlock(password)
        preview.setPresentationPrivacy(hidden: true, reason: "test")
        checks["presentationRelocksSettings"] = !preview.settingsLock.canView && preview.presentationHidden
        checks.merge(try attendancePersistenceChecks(), uniquingKeysWith: { _, new in new })
        checks.merge(try StorageFeatureChecks.run(), uniquingKeysWith: { _, new in new })

        let suite = "local.livingmeaning.test-updates.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suite)!
        defer { preferences.removePersistentDomain(forName: suite) }
        let updates = UpdateController(preferences: preferences, enabled: false, bundledFeed: "")
        checks["unconfiguredUpdaterIsExplicit"] = !updates.isConfigured
        let bundled = "https://fixture-owner.github.io/living-meaning/appcast.xml"
        let official = UpdateController(preferences: preferences, enabled: false, bundledFeed: bundled)
        checks["bundledOfficialFeedWorksWithoutPreferences"] = official.isConfigured && official.feedAddress == bundled
        checks["invalidUpdateSourceRejected"] = updates.configure("http://example.com/appcast.xml") != nil
        checks["validUpdateSourceSaved"] = updates.configure("https://example.com/appcast.xml") == nil
        updates.setAutomaticChecks(true)
        let reloaded = UpdateController(preferences: preferences, enabled: false, bundledFeed: bundled)
        checks["updatePreferencesPersist"] = reloaded.isConfigured && reloaded.automaticallyChecks
        checks["explicitSavedFeedOverridesBundle"] = reloaded.feedAddress == "https://example.com/appcast.xml"
        return checks
    }

    /// Exercises immediate punch persistence and rollback on write failure in temporary storage; returns results.
    private static func attendancePersistenceChecks() throws -> [String: Bool] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let calendar = WorkCalendar()
        let day = calendar.calendar.date(from: DateComponents(year: 2026, month: 11, day: 3))!
        let arrival = calendar.time(10 * 60, on: day)
        let departure = calendar.time(17 * 60, on: day)
        let url = directory.appendingPathComponent("state.json")
        let repository = StateRepository(url: url)
        var configured = SavedState()
        configured.hasConfirmedSchedule = true
        try repository.save(configured)
        let store = AppStore(repository: repository, date: arrival, isolated: true)
        var checks: [String: Bool] = [:]
        checks["arrivalSavedImmediately"] = try store.punch(arriving: true, at: arrival) == nil
            && repository.load().records["2026-11-03"]?.checkInAt == arrival
        checks["departureSavedImmediately"] = try store.punch(arriving: false, at: departure) == nil
            && repository.load().records["2026-11-03"]?.checkOutAt == departure
        let saved = store.records["2026-11-03"]!
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        checks["failedCorrectionRollsBack"] = store.correctAttendance(
            key: "2026-11-03", checkIn: arrival, checkOut: nil
        ) != nil && store.records["2026-11-03"] == saved
        let blocker = directory.appendingPathComponent("blocker")
        try Data("file".utf8).write(to: blocker)
        let failed = AppStore(
            repository: StateRepository(url: blocker.appendingPathComponent("state.json")),
            date: arrival, isolated: true
        )
        _ = failed.updateSettings(failed.settings, confirmSchedule: true)
        // Use a valid persisted state then obstruct its destination to test a real punch write failure.
        let failedURL = directory.appendingPathComponent("failed-punch.json")
        try StateRepository(url: failedURL).save(configured)
        let failedPunch = AppStore(repository: StateRepository(url: failedURL), date: arrival, isolated: true)
        try FileManager.default.removeItem(at: failedURL)
        try FileManager.default.createDirectory(at: failedURL, withIntermediateDirectories: false)
        checks["failedArrivalRollsBack"] = failedPunch.punch(arriving: true, at: arrival) != nil
            && failedPunch.records["2026-11-03"]?.checkInAt == nil
        checks["failedDepartureRollsBack"] = failedPunch.punch(arriving: false, at: departure) != nil
            && failedPunch.records["2026-11-03"]?.checkOutAt == nil && !failedPunch.snapshot.isSettled
        checks["failedFirstSetupRollsBack"] = !failed.hasConfirmedSchedule && failed.records.isEmpty
        let firstURL = directory.appendingPathComponent("first-run.json")
        let first = AppStore(repository: StateRepository(url: firstURL), date: arrival, isolated: true)
        first.tick(at: arrival)
        checks["firstRunWaitsForSchedule"] = !first.hasConfirmedSchedule && first.records.isEmpty
            && first.punch(arriving: true, at: arrival) != nil
        var firstSettings = WorkSettings()
        firstSettings.monthlySalary = 27_000
        checks["firstRunConfirmationPersists"] = try first.updateSettings(
            firstSettings, confirmSchedule: true
        ) == nil && StateRepository(url: firstURL).load().hasConfirmedSchedule
        return checks
    }
}
