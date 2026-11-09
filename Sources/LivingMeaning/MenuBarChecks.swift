import AppKit
import LivingCore

enum MenuBarChecks {
    /// Renders the actual status button through update into directory; returns whether color and width checks pass.
    static func run(
        button: NSStatusBarButton,
        update: (EarningsSnapshot) -> Void,
        directory: URL,
        hasTouchBarController: Bool
    ) throws -> Bool {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var checks: [String: Bool] = [:]
        var details: [String: Any] = ["touchBarControllerCreated": hasTouchBarController]
        let calendar = WorkCalendar()
        var fixtureSettings = WorkSettings()
        fixtureSettings.dateOverrides[calendar.key(for: Date())] = true
        let time = calendar.time(12 * 60, on: Date())
        let engine = EarningsEngine(workCalendar: calendar)
        let awaiting = engine.snapshot(at: time, settings: fixtureSettings, records: [:])
        var records: [String: DayRecord] = [:]
        engine.checkOut(at: time, settings: fixtureSettings, records: &records)
        let settled = engine.snapshot(at: time, settings: fixtureSettings, records: records)
        for (name, snapshot) in [
            ("working", EarningsSnapshot.previewWorking(at: Date())),
            ("overtime", EarningsSnapshot.previewOvertime(at: Date())),
            ("awaiting", awaiting),
            ("settled", settled)
        ] {
            update(snapshot)
            button.window?.layoutIfNeeded()
            button.displayIfNeeded()
            guard let bitmap = button.bitmapImageRepForCachingDisplay(in: button.bounds) else {
                throw NSError(domain: "MenuBarChecks", code: 1)
            }
            button.cacheDisplay(in: button.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?
                .write(to: directory.appendingPathComponent("\(name)-status.png"))
            let coloredPixels = countAccentPixels(bitmap, phase: snapshot.phase)
            checks["\(name)HasVisiblePhaseColor"] = coloredPixels > 10
            checks["\(name)HasInformation"] = button.accessibilityValue() as? String
                == EarningsPresentation(snapshot: snapshot, settings: WorkSettings()).menuText
            checks["\(name)FitsNarrowMenuBar"] = button.frame.width <= 124
            details["\(name)Width"] = button.frame.width
            details["\(name)AccentPixels"] = coloredPixels
        }
        checks["notchedScreenUsesNarrowLayout"] = MenuBarArtwork.widthLimit(screenWidth: 1728, topInset: 32) == 112
        checks["smallScreenUsesNarrowLayout"] = MenuBarArtwork.widthLimit(screenWidth: 1440, topInset: 0) == 112
        checks["wideScreenKeepsSingleLineSpace"] = MenuBarArtwork.widthLimit(screenWidth: 1920, topInset: 0) == 180
        var settings = WorkSettings()
        settings.sensitiveMode = true
        settings.itemPreset = .custom
        settings.customItemTiers = [ItemTier(minimum: 0, item: "一件自己一直很喜欢的礼物")]
        let privateImage = MenuBarArtwork.make(
            snapshot: .previewWorking(at: Date()), settings: settings, maximumWidth: 112
        )
        checks["longPrivateItemFits"] = privateImage.image.size.width <= 112
        checks["privateImageDoesNotExposeAmount"] = !privateImage.text.contains("¥")
        checks["narrowLayoutKeepsTimer"] = privateImage.usesTwoLines && privateImage.text.contains(":")
        settings.compactMenuBar = true
        let compact = MenuBarArtwork.make(
            snapshot: .previewWorking(at: Date()), settings: settings, maximumWidth: 112
        )
        checks["manualCompactModeRemainsSingleLine"] = !compact.usesTwoLines && !compact.text.contains(":")
        details["checks"] = checks
        details["passed"] = checks.values.allSatisfy { $0 }
        let data = try JSONSerialization.data(withJSONObject: details, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: directory.appendingPathComponent("menu-bar-checks.json"), options: .atomic)
        print(String(decoding: data, as: UTF8.self))
        return checks.values.allSatisfy { $0 }
    }

    /// Counts strong green/red/purple pixels in bitmap for phase; returns zero for a monochrome rendering.
    private static func countAccentPixels(_ bitmap: NSBitmapImageRep, phase: WorkPhase) -> Int {
        var count = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                      color.alphaComponent > 0.5 else { continue }
                let r = color.redComponent
                let g = color.greenComponent
                let b = color.blueComponent
                if [.working, .checkedOut].contains(phase),
                   g > 0.35 && g > r * 1.25 && g > b * 1.25 { count += 1 }
                if phase == .overtime && r > 0.45 && r > g * 1.4 && r > b * 1.3 { count += 1 }
                if phase == .awaitingCheckIn && b > 0.4 && r > g * 1.2 && b > g * 1.2 { count += 1 }
            }
        }
        return count
    }
}
