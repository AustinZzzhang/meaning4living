import AppKit
import Combine
import SwiftUI
import Sparkle
import LivingCore

final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate {
    @Published private(set) var feedAddress: String
    @Published private(set) var status = "尚未配置更新源"
    @Published private(set) var automaticallyChecks: Bool
    @Published private(set) var isChecking = false
    private var controller: SPUStandardUpdaterController?
    private let preferences: UserDefaults
    private let enabled: Bool
    private var activeFeed: String?
    var beforeInstall: (() -> String?)?

    var isConfigured: Bool { UpdateSource.url(feedAddress) != nil }
    var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "开发版" }
    var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0" }

    /// Creates an updater with preferences/enabled and an optional bundledFeed test override; returns an updater.
    init(preferences: UserDefaults = .standard, enabled: Bool = true, bundledFeed: String? = nil) {
        self.preferences = preferences
        self.enabled = enabled
        let defaultFeed = bundledFeed ?? (Bundle.main.infoDictionary?["SUFeedURL"] as? String ?? "")
        feedAddress = preferences.string(forKey: "LivingMeaning.UpdateFeedURL") ?? defaultFeed
        automaticallyChecks = preferences.bool(forKey: "LivingMeaning.AutomaticUpdateChecks")
        super.init()
        if isConfigured { status = "可以检查新版本" }
    }

    /// Starts a configured updater after application launch; no parameters or return value.
    func startIfConfigured() {
        guard enabled, isConfigured, controller == nil else { return }
        let instance = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        controller = instance
        instance.updater.automaticallyChecksForUpdates = automaticallyChecks
        instance.updater.automaticallyDownloadsUpdates = false
        instance.updater.sendsSystemProfile = false
        do {
            try instance.updater.start()
            status = "可以检查新版本"
        } catch {
            status = "更新服务启动失败：\(error.localizedDescription)"
            controller = nil
        }
    }

    /// Persists a validated HTTPS address if no update is active; returns an error or nil.
    func configure(_ address: String) -> String? {
        guard !isChecking, controller?.updater.sessionInProgress != true else {
            return "请先完成或取消当前更新，再修改更新源。"
        }
        guard let url = UpdateSource.url(address) else { return "请输入有效的 HTTPS 更新地址（以 .xml 结尾）。" }
        feedAddress = url.absoluteString
        preferences.set(feedAddress, forKey: "LivingMeaning.UpdateFeedURL")
        status = "更新源已保存，可以检查新版本"
        startIfConfigured()
        controller?.updater.resetUpdateCycle()
        return nil
    }

    /// Toggles scheduled checking with value; user confirmation is still required to install, returns nothing.
    func setAutomaticChecks(_ value: Bool) {
        automaticallyChecks = value
        preferences.set(value, forKey: "LivingMeaning.AutomaticUpdateChecks")
        controller?.updater.automaticallyChecksForUpdates = value
    }

    /// Presents Sparkle's check, download and install flow; no parameters or return value.
    func checkForUpdates() {
        guard isConfigured else {
            status = "还没有更新源。发布者配置固定地址后，即可在这里更新。"
            return
        }
        startIfConfigured()
        controller?.checkForUpdates(nil)
    }

    /// Returns the validated feed URL for updater, keeping an active update on its original feed.
    func feedURLString(for updater: SPUUpdater) -> String? {
        activeFeed ?? UpdateSource.url(feedAddress)?.absoluteString
    }

    /// Validates source before updater performs updateCheck; throws if missing, otherwise marks the cycle active.
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard let url = UpdateSource.url(feedAddress) else {
            throw NSError(domain: "LivingMeaning.Update", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "尚未配置有效的更新源。"
            ])
        }
        activeFeed = url.absoluteString
        isChecking = true
        status = "正在检查或下载更新…"
    }

    /// Flushes application data before updater installs item; returns nothing.
    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        if let error = beforeInstall?() { status = "更新已暂停：\(error)" }
    }

    /// Reports completion for updater/updateCheck using error; returns nothing.
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        isChecking = false
        activeFeed = nil
        status = error.map { "检查结束：\($0.localizedDescription)" } ?? "本次检查已完成"
    }
}

struct UpdatePage: View {
    @ObservedObject var updater: UpdateController
    @State private var address = ""
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeading(title: "让好用的地方，继续变好。", subtitle: "在应用里检查、下载并安装新版本。")
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "arrow.down.app")
                            .font(.system(size: 34))
                            .foregroundStyle(Palette.green)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("活着的意义").font(.system(size: 20, weight: .semibold))
                            Text("版本 \(updater.version)（\(updater.build)）")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    Text(updater.status).font(.system(size: 13)).foregroundStyle(Palette.muted)
                    HStack {
                        Button("检查更新") { updater.checkForUpdates() }
                            .buttonStyle(ActionButtonStyle())
                            .disabled(!updater.isConfigured)
                        Toggle("自动检查新版本", isOn: Binding(
                            get: { updater.automaticallyChecks },
                            set: { updater.setAutomaticChecks($0) }
                        ))
                        .toggleStyle(.switch)
                        .tint(Palette.green)
                        .disabled(!updater.isConfigured)
                    }
                    Text("发现新版后由你确认安装。下载会校验发布者签名，更新保留本机设置、物品区间和密码保护。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 14) {
                    DisclosureGroup("更新源") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("填写发布者提供的固定更新地址。普通使用者无需修改已配置的地址。")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                            TextField("https://你的更新站点/appcast.xml", text: $address)
                                .textFieldStyle(.roundedBorder)
                            Button("保存更新源") { message = updater.configure(address) ?? "更新源已保存。" }
                                .disabled(updater.isChecking)
                            if let message { Text(message).font(.system(size: 12)) }
                        }
                        .padding(.top, 12)
                    }
                    if !updater.isConfigured {
                        Text("当前版本尚未连接线上发布地址，暂时不能发现远端更新。")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
        }
        .onAppear { address = updater.feedAddress }
    }
}
