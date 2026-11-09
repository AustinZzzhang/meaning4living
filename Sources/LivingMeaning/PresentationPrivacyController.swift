import AppKit
import Carbon
import CoreGraphics
import LivingCore

final class PresentationPrivacyController {
    private var manual: Bool
    private var settings: WorkSettings
    private let preferences: UserDefaults
    private let changed: (Bool, String) -> Void
    private var observer: NSObjectProtocol?
    private var timer: Timer?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var mirrored = false
    private var external = false
    private(set) var shortcutAvailable = false

    /// Monitors displays and registers the hotkey using settings/preferences; changed receives privacy state.
    init(settings: WorkSettings, preferences: UserDefaults = .standard, changed: @escaping (Bool, String) -> Void) {
        self.settings = settings
        self.preferences = preferences
        self.manual = preferences.bool(forKey: "LivingMeaning.ManualPresentationPrivacy")
        self.changed = changed
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier
            )
            guard status == noErr, identifier.signature == 0x4C4D5052 else { return OSStatus(eventNotHandledErr) }
            Unmanaged<PresentationPrivacyController>.fromOpaque(context).takeUnretainedValue().toggleManual()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_P), UInt32(controlKey | optionKey | cmdKey),
            EventHotKeyID(signature: 0x4C4D5052, id: 1), GetApplicationEventTarget(), 0, &hotKey
        )
        shortcutAvailable = handlerStatus == noErr && status == noErr
        if !shortcutAvailable {
            NSLog("Presentation privacy shortcut unavailable (%d); app menu remains available.", status)
        }
        refresh()
    }

    /// Removes observers, timer and the registered hotkey; no parameters or return value.
    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        timer?.invalidate()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }

    /// Updates privacy settings and immediately reevaluates display state; returns nothing.
    func configure(_ settings: WorkSettings) {
        self.settings = settings
        refresh()
    }

    /// Toggles the manual privacy latch independently of automatic display detection; returns nothing.
    func toggleManual() {
        manual.toggle()
        preferences.set(manual, forKey: "LivingMeaning.ManualPresentationPrivacy")
        refresh()
    }

    /// Reads display mirror/connection state and reports privacy without capture access; no parameters or return.
    func refresh() {
        var count: UInt32 = 0
        if CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 {
            var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
            if CGGetOnlineDisplayList(count, &displays, &count) == .success {
                let active = displays.prefix(Int(count))
                mirrored = active.contains { CGDisplayIsInMirrorSet($0) != 0 }
                external = active.contains { CGDisplayIsBuiltin($0) == 0 }
            }
        }
        let reason = PresentationPrivacyRule.reason(
            manual: manual, mirrored: mirrored, external: external, settings: settings
        )
        changed(reason != nil, reason ?? "")
    }
}
