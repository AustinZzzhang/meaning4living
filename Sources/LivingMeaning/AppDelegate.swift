import AppKit
import Combine
import SwiftUI
import LivingCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private(set) var store: AppStore!
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var touchBarController: TouchBarController?
    private var subscriptions: Set<AnyCancellable> = []
    private var isPreviewRun = false
    private var statusText = ""
    private var menuCheckWidth: CGFloat?
    private var privacyController: PresentationPrivacyController?

    /// Builds the live app or requested preview export; notification is unused, returns nothing.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"),
           CommandLine.arguments.indices.contains(index + 1) {
            isPreviewRun = true
            PreviewExporter.export(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            return
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let smokeIndex = CommandLine.arguments.firstIndex(of: "--smoke-test")
        let menuCheckIndex = CommandLine.arguments.firstIndex(of: "--check-menu-bar")
        var smokeDirectory: URL?
        if let smokeIndex, CommandLine.arguments.indices.contains(smokeIndex + 1) {
            smokeDirectory = URL(fileURLWithPath: CommandLine.arguments[smokeIndex + 1])
        }
        if let menuCheckIndex, CommandLine.arguments.indices.contains(menuCheckIndex + 1) {
            smokeDirectory = URL(fileURLWithPath: CommandLine.arguments[menuCheckIndex + 1])
            menuCheckWidth = 112
        }
        if smokeDirectory == nil || !CommandLine.arguments.contains("--without-touch-bar") {
            touchBarController = TouchBarController()
        }
        let url = smokeDirectory?.appendingPathComponent("live-smoke-state.json")
            ?? support.appendingPathComponent("LivingMeaning/state.json")
        store = AppStore(repository: StateRepository(url: url), isolated: smokeDirectory != nil)
        if smokeDirectory != nil { store.updateSettings(store.settings, confirmSchedule: true) }
        store.updates.beforeInstall = { [weak self] in self?.store.finishSession() }
        store.restoreMenuBar = { [weak self] in self?.restoreStatusItem() }
        installMenu()
        if smokeDirectory == nil {
            privacyController = PresentationPrivacyController(settings: store.settings) { [weak self] hidden, reason in
                self?.applyPresentationPrivacy(hidden: hidden, reason: reason)
            }
            store.privacyShortcutAvailable = privacyController?.shortcutAvailable == true
            store.togglePresentationPrivacy = { [weak self] in self?.privacyController?.toggleManual() }
        }
        installStatusItem()
        openMainWindow()
        store.$snapshot.sink { [weak self] snapshot in
            self?.updateStatus(snapshot)
            guard let self else { return }
            self.touchBarController?.update(snapshot, settings: self.store.settings)
        }
        .store(in: &subscriptions)
        if let smokeDirectory {
            if menuCheckIndex != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                    do {
                        guard let button = statusItem?.button else { exit(1) }
                        let passed = try MenuBarChecks.run(
                            button: button,
                            update: updateStatus,
                            directory: smokeDirectory,
                            hasTouchBarController: touchBarController != nil
                        )
                        exit(passed ? 0 : 1)
                    } catch {
                        fputs("Menu bar check failed: \(error)\n", stderr)
                        exit(1)
                    }
                }
            } else {
                runSmokeTest(in: smokeDirectory)
            }
        }
        store.$settings.sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateStatus(self.store.snapshot)
                self.touchBarController?.update(self.store.snapshot, settings: self.store.settings)
                self.privacyController?.configure(self.store.settings)
            }
        }
        .store(in: &subscriptions)
        store.updates.startIfConfigured()
    }

    /// Locks settings when the app loses focus; notification is unused, returns nothing.
    func applicationDidResignActive(_ notification: Notification) {
        store?.settingsLock.lock()
    }

    /// Locks settings when its window closes; notification is unused, returns nothing.
    func windowWillClose(_ notification: Notification) {
        store?.settingsLock.lock()
    }

    /// Flushes state before sender quits, including update installs; returns cancel if saving fails.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isPreviewRun, let store, let error = store.finishSession() else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "数据尚未保存，已暂停退出或更新"
        alert.informativeText = "\(error)\n请修复保存问题后重试，避免丢失当前设置和计时。"
        alert.addButton(withTitle: "返回应用")
        alert.runModal()
        return .terminateCancel
    }

    /// Flushes live state before termination; notification is unused and the method returns nothing.
    func applicationWillTerminate(_ notification: Notification) {
        if !isPreviewRun { store?.finishSession() }
    }

    /// Keeps the menu-bar app alive after its last window closes; sender is unused, returns false.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Opens the window on Dock click; sender/flag are unused, returns true to acknowledge reopening.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }

    /// Shows and activates a reusable settings/dashboard window. No parameters or return value.
    @objc func openMainWindow() {
        popover.performClose(nil)
        if window == nil {
            let host = NSHostingController(rootView: RootView(store: store, quit: { NSApp.terminate(nil) }))
            let created = NSWindow(contentViewController: host)
            created.title = "活着的意义"
            created.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            created.setContentSize(NSSize(width: 1080, height: 840))
            created.minSize = NSSize(width: 900, height: 740)
            created.isReleasedWhenClosed = false
            created.titlebarAppearsTransparent = true
            created.backgroundColor = NSColor(Palette.background)
            created.appearance = NSAppearance(named: .aqua)
            created.touchBar = touchBarController?.touchBar
            created.delegate = self
            created.center()
            created.setFrameAutosaveName("LivingMeaning.MainWindow")
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Switches to settings and opens the window; invoked by the app menu, returns nothing.
    @objc private func openSettings() {
        store.selectedPage = .settings
        openMainWindow()
    }

    /// Toggles the menu-bar popover at the status button; no parameters or return value.
    @objc private func togglePopover() {
        guard !store.presentationHidden, let button = statusItem?.button else { return }
        guard store.hasConfirmedSchedule else {
            openSettings()
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.tick()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Creates the status item and SwiftUI popover; no parameters or return value.
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "LivingMeaning.Status"
        item.isVisible = !store.presentationHidden
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: MenuPopoverView(
                store: store,
                openApp: { [weak self] in self?.openMainWindow() },
                quit: { NSApp.terminate(nil) }
            )
        )
        popover.appearance = NSAppearance(named: .aqua)
        updateStatus(store.snapshot)
    }

    /// Updates menu text, accessibility and tooltip from snapshot; returns nothing.
    private func updateStatus(_ snapshot: EarningsSnapshot) {
        guard let button = statusItem?.button else { return }
        statusItem?.isVisible = !store.presentationHidden
        if store.presentationHidden {
            statusText = ""
            button.image = nil
            button.title = ""
            button.toolTip = nil
            button.setAccessibilityLabel("演示隐私已开启")
            button.setAccessibilityValue("")
            return
        }
        if !store.hasConfirmedSchedule {
            statusText = "请设置薪资"
            button.imagePosition = .noImage
            button.image = nil
            button.title = statusText
            button.toolTip = "首次使用：确认薪资与作息后开始记录"
            button.setAccessibilityLabel(statusText)
            button.setAccessibilityValue(statusText)
            statusItem?.length = NSStatusItem.variableLength
            return
        }
        let display = EarningsPresentation(snapshot: snapshot, settings: store.settings)
        let screen = button.window?.screen ?? NSScreen.main
        let width = menuCheckWidth ?? MenuBarArtwork.widthLimit(
            screenWidth: screen?.frame.width ?? 1440,
            topInset: screen?.safeAreaInsets.top ?? 0
        )
        let artwork = MenuBarArtwork.make(snapshot: snapshot, settings: store.settings, maximumWidth: width)
        statusText = artwork.text
        button.imagePosition = .imageOnly
        button.title = ""
        button.attributedTitle = NSAttributedString(string: "")
        button.image = artwork.image
        statusItem?.length = artwork.image.size.width + 12
        button.toolTip = "活着的意义 · \(display.compactAmount) · \(snapshot.phase.title) · \(snapshot.timerCaption)"
        button.setAccessibilityLabel("活着的意义，\(display.accessibilityLabel)")
        button.setAccessibilityValue(display.menuText)
    }

    /// Applies hidden/reason to all presentation surfaces immediately; returns nothing and leaves accounting running.
    private func applyPresentationPrivacy(hidden: Bool, reason: String) {
        guard let store else { return }
        if hidden { popover.performClose(nil) }
        if store.presentationHidden != hidden || store.presentationReason != reason {
            store.setPresentationPrivacy(hidden: hidden, reason: reason)
        }
        touchBarController?.setPrivacy(hidden)
        updateStatus(store.snapshot)
    }

    /// Toggles the manual presentation privacy latch from the app menu; no parameters or return value.
    @objc private func togglePrivacy() {
        privacyController?.toggleManual()
    }

    /// Recreates a missing or displaced status item and refreshes it; no parameters or return value.
    @objc private func restoreStatusItem() {
        popover.performClose(nil)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
        installStatusItem()
    }

    /// Installs native menus with keyboard shortcuts; no parameters or return value.
    private func installMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "活着的意义")
        let open = NSMenuItem(title: "打开活着的意义", action: #selector(openMainWindow), keyEquivalent: "0")
        open.target = self
        appMenu.addItem(open)
        let settings = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        appMenu.addItem(settings)
        let updates = NSMenuItem(title: "检查更新…", action: #selector(openUpdates), keyEquivalent: "")
        updates.target = self
        appMenu.addItem(updates)
        let restore = NSMenuItem(title: "恢复菜单栏显示", action: #selector(restoreStatusItem), keyEquivalent: "")
        restore.target = self
        appMenu.addItem(restore)
        let privacy = NSMenuItem(title: "切换演示隐私（⌃⌥⌘P）", action: #selector(togglePrivacy), keyEquivalent: "")
        privacy.target = self
        appMenu.addItem(privacy)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏活着的意义", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出活着的意义", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "最小化", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        NSApp.mainMenu = menu
    }

    /// Opens the update page and checks the configured feed; no parameters or return value.
    @objc private func openUpdates() {
        store.selectedPage = .updates
        openMainWindow()
        store.updates.checkForUpdates()
    }

    /// Exercises the live clock, window and popover in isolated directory; writes results and exits, returns nothing.
    private func runSmokeTest(in directory: URL) {
        let start = store.snapshot.date
        let visible = window?.isVisible == true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [self] in
            let clockAdvanced = store.snapshot.date.timeIntervalSince(start) >= 1
            let statusUpdated = statusText == store.presentation.menuText && statusItem?.button?.image != nil
            togglePopover()
            let popoverOpened = popover.isShown
            popover.performClose(nil)
            window?.performClose(nil)
            let remainsRunning = window?.isVisible == false && statusItem?.isVisible == true
            openMainWindow()
            let reopened = window?.isVisible == true
            openSettings()
            let settingsOpened = store.selectedPage == .settings
            let previousItem = statusItem
            restoreStatusItem()
            let statusRestored = statusItem !== previousItem && statusItem?.isVisible == true
                && statusText == store.presentation.menuText
            togglePopover()
            applyPresentationPrivacy(hidden: true, reason: "隔离验证")
            let privacyHides = statusItem?.isVisible == false && statusItem?.button?.image == nil
                && statusItem?.button?.toolTip == nil && !popover.isShown && store.presentationHidden
            store.tick()
            let privacySurvivesTick = statusItem?.isVisible == false
                && (touchBarController?.displayedValues().allSatisfy(\.isEmpty) ?? true)
            restoreStatusItem()
            let restoreRespectsPrivacy = statusItem?.isVisible == false
            applyPresentationPrivacy(hidden: false, reason: "")
            let privacyRestores = statusItem?.isVisible == true && statusItem?.button?.image != nil
                && !store.presentationHidden
            store.finishSession()
            let report: [String: Bool] = [
                "mainWindowVisible": visible,
                "liveClockAdvanced": clockAdvanced,
                "menuBarUpdated": statusUpdated,
                "popoverOpened": popoverOpened,
                "closingWindowKeepsMenuBar": remainsRunning,
                "windowReopened": reopened,
                "settingsShortcut": settingsOpened,
                "menuBarRestored": statusRestored,
                "privacyHidesStatusAndPopover": privacyHides,
                "privacySurvivesTimerUpdate": privacySurvivesTick,
                "manualRestoreRespectsPrivacy": restoreRespectsPrivacy,
                "privacyRestoresStatus": privacyRestores,
                "stateSaved": store.storageError == nil
            ]
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: directory.appendingPathComponent("live-smoke-report.json"), options: .atomic)
                print(String(data: data, encoding: .utf8)!)
                guard report.values.allSatisfy({ $0 }) else { exit(1) }
                NSApp.terminate(nil)
            } catch {
                fputs("Live smoke test failed: \(error)\n", stderr)
                exit(1)
            }
        }
    }
}
