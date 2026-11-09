import AppKit
import Combine
import Darwin
import LivingCore

final class AppStore: ObservableObject {
    @Published private(set) var settings: WorkSettings
    @Published private(set) var records: [String: DayRecord]
    @Published private(set) var snapshot: EarningsSnapshot
    @Published var selectedPage: AppPage = .home {
        didSet {
            if selectedPage != .settings { settingsLock.lock() }
        }
    }
    @Published var storageError: String?
    @Published private(set) var presentationHidden = false
    @Published private(set) var presentationReason = ""
    @Published var actionMessage: String?
    @Published var privacyShortcutAvailable = true
    @Published private(set) var hasConfirmedSchedule: Bool
    let settingsLock: SettingsLock
    let updates: UpdateController
    var restoreMenuBar: (() -> Void)?
    var togglePresentationPrivacy: (() -> Void)?

    private let repository: StateRepository?
    private var session: ActiveSession
    private var timer: Timer?
    private var lastSaveUptime: TimeInterval
    private var persistenceBlocked = false
    private var isPreview: Bool
    private var observers: [NSObjectProtocol] = []

    var engine: EarningsEngine { EarningsEngine() }
    var workCalendar: WorkCalendar { engine.workCalendar }
    var presentation: EarningsPresentation { EarningsPresentation(snapshot: snapshot, settings: settings) }

    /// Returns a store using repository/date; previewState disables timing/writes, isolated disables real credentials.
    init(
        repository: StateRepository?,
        date: Date = Date(),
        previewState: SavedState? = nil,
        isolated: Bool = false
    ) {
        self.repository = repository
        self.isPreview = previewState != nil
        let testMode = isolated || previewState != nil
        self.settingsLock = SettingsLock(vault: testMode ? MemoryCredentialVault() : KeychainCredentialVault())
        let preferences = testMode
            ? UserDefaults(suiteName: "local.livingmeaning.test.\(UUID().uuidString)")!
            : .standard
        self.updates = UpdateController(
            preferences: preferences, enabled: !testMode, bundledFeed: testMode ? "" : nil
        )
        self.session = ActiveSession(startingAt: date, uptime: Self.continuousSeconds())
        self.lastSaveUptime = Self.continuousSeconds()
        var state = previewState ?? SavedState()
        var errorMessage: String?
        if previewState == nil, let repository {
            do {
                state = try repository.load()
            } catch {
                errorMessage = "无法读取数据：\(error.localizedDescription) 本次未覆盖原文件。"
                persistenceBlocked = true
            }
        }
        self.settings = state.settings
        self.hasConfirmedSchedule = previewState != nil || state.hasConfirmedSchedule
        var records = state.records
        if !testMode, !persistenceBlocked, state.hasConfirmedSchedule {
            EarningsEngine().observe(at: date, settings: state.settings, records: &records)
        }
        if !testMode, !persistenceBlocked, state.hasConfirmedSchedule {
            EarningsEngine().reconcileCurrentData(at: date, settings: state.settings, records: &records)
        }
        self.records = records
        self.snapshot = EarningsEngine().snapshot(at: date, settings: state.settings, records: records)
        self.storageError = errorMessage
        if !hasConfirmedSchedule { selectedPage = .settings }
        if !isPreview {
            startClock()
            _ = persist()
        }
    }

    /// Releases the clock and observers on destruction; no parameters or return value.
    deinit {
        timer?.invalidate()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    /// Advances the live session to date, updates visible values and periodically persists; returns nothing.
    func tick(at date: Date = Date()) {
        let uptime = Self.continuousSeconds()
        let previousKey = snapshot.dayKey
        if !isPreview, hasConfirmedSchedule {
            session.advance(
                to: date,
                uptime: uptime,
                engine: engine,
                settings: settings,
                records: &records
            )
            engine.observe(at: date, settings: settings, records: &records)
        } else if !hasConfirmedSchedule {
            session = ActiveSession(startingAt: date, uptime: uptime)
        }
        snapshot = engine.snapshot(at: date, settings: settings, records: records)
        if previousKey != snapshot.dayKey { actionMessage = nil }
        if uptime - lastSaveUptime >= 5 {
            persist()
            lastSaveUptime = uptime
        }
    }

    /// Applies value; confirmSchedule starts first-run accounting. Returns validation/storage error, or nil.
    @discardableResult
    func updateSettings(_ value: WorkSettings, confirmSchedule: Bool = false) -> String? {
        if let error = value.validationMessage { return error }
        let date = isPreview ? snapshot.date : Date()
        let previous = settings
        let previousRecords = records
        let previousConfirmed = hasConfirmedSchedule
        tick(at: date)
        settings = value
        engine.reconcileCurrentData(at: date, settings: value, records: &records)
        if confirmSchedule { hasConfirmedSchedule = true }
        if !previousConfirmed && hasConfirmedSchedule {
            engine.observe(at: date, settings: value, records: &records)
        }
        snapshot = engine.snapshot(at: date, settings: value, records: records)
        if let error = persist() {
            settings = previous
            records = previousRecords
            hasConfirmedSchedule = previousConfirmed
            snapshot = engine.snapshot(at: date, settings: previous, records: records)
            return error
        }
        return nil
    }

    /// Sets hidden/reason from display monitoring without pausing accounting; returns nothing.
    func setPresentationPrivacy(hidden: Bool, reason: String) {
        if hidden { settingsLock.lock() }
        presentationReason = reason
        presentationHidden = hidden
    }

    /// Saves an arrival or departure selected by arriving at optional date; returns a storage or validation error.
    @discardableResult
    func punch(arriving: Bool, at date: Date? = nil) -> String? {
        guard hasConfirmedSchedule else {
            actionMessage = "请先保存薪资与作息，再开始记录。"
            selectedPage = .settings
            return actionMessage
        }
        let now = date ?? (isPreview ? snapshot.date : Date())
        tick(at: now)
        let previous = records
        let changed = arriving
            ? engine.checkIn(at: now, settings: settings, records: &records)
            : engine.checkOut(at: now, settings: settings, records: &records)
        guard changed else {
            records = previous
            actionMessage = "当前无法打卡，请检查日期安排或已有打卡记录。"
            return actionMessage
        }
        snapshot = engine.snapshot(at: now, settings: settings, records: records)
        if let error = persist() {
            records = previous
            snapshot = engine.snapshot(at: now, settings: settings, records: records)
            actionMessage = error
            return error
        }
        actionMessage = arriving ? "上班打卡已保存，收入继续累计。" : "下班打卡已保存，今日已结算。"
        return nil
    }

    /// Saves corrected punches for key using frozen plan; returns an error and rolls back if persistence fails.
    func correctAttendance(key: String, checkIn: Date?, checkOut: Date?) -> String? {
        let now = isPreview ? snapshot.date : Date()
        tick(at: now)
        let previous = records
        if let error = engine.correct(key: key, checkIn: checkIn, checkOut: checkOut, now: now, records: &records) {
            return error
        }
        snapshot = engine.snapshot(at: now, settings: settings, records: records)
        if let error = persist() {
            records = previous
            snapshot = engine.snapshot(at: now, settings: settings, records: records)
            return error
        }
        return nil
    }

    /// Overrides one calendar date; nil restores the official/weekly plan. Returns nothing.
    func setDay(_ date: Date, workday: Bool?) {
        var next = settings
        next.dateOverrides[workCalendar.key(for: date)] = workday
        updateSettings(next)
    }

    /// Flushes active time before quitting; no parameters, returns a storage error or nil.
    @discardableResult
    func finishSession() -> String? {
        if !isPreview { tick() }
        return persist()
    }

    /// Returns the saved loss for the month containing date; no history is synthesized.
    func monthLoss(for date: Date) -> Double {
        let prefix = String(workCalendar.key(for: date).prefix(7))
        return records.filter { $0.key.hasPrefix(prefix) }.values.reduce(0) { $0 + $1.overtimeLoss }
    }

    /// Installs the main-run-loop clock and saves on sleep; no parameters or return value.
    private func startClock() {
        let clock = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        clock.tolerance = 0.1
        RunLoop.main.add(clock, forMode: .common)
        timer = clock
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.settingsLock.lock()
                self?.tick()
                self?.persist()
            }
            observers.append(observer)
        }
        let observer = center.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.settingsLock.lock() }
        observers.append(observer)
    }

    /// Writes current state atomically; no parameters, returns an error or nil. Previews never write.
    @discardableResult
    private func persist() -> String? {
        if isPreview { return nil }
        if persistenceBlocked { return storageError ?? "原数据无法读取，已暂停保存以保留原文件。" }
        guard let repository else { return "未配置本地存储。" }
        var state = SavedState()
        state.hasConfirmedSchedule = hasConfirmedSchedule
        state.settings = settings
        state.records = records
        do {
            try repository.save(state)
            storageError = nil
            return nil
        } catch {
            storageError = "保存失败：\(error.localizedDescription)"
            return storageError
        }
    }

    /// Reads a monotonic clock that includes sleep; no parameters, returns continuous elapsed seconds.
    private static func continuousSeconds() -> TimeInterval {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(mach_continuous_time()) * Double(info.numer) / Double(info.denom) / 1_000_000_000
    }
}

enum AppPage: String, CaseIterable, Identifiable {
    case home = "首页"
    case calendar = "日历"
    case display = "显示"
    case settings = "设置"
    case updates = "更新"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home: return "chart.bar.fill"
        case .calendar: return "calendar"
        case .display: return "rectangle.topthird.inset.filled"
        case .settings: return "slider.horizontal.3"
        case .updates: return "arrow.down.circle"
        }
    }
}
