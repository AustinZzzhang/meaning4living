import SwiftUI
import LivingCore

struct MenuPopoverView: View {
    @ObservedObject var store: AppStore
    var openApp: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(store.presentation.headline)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                StatusPill(phase: store.snapshot.phase)
            }
            Text(store.presentation.amount)
                .font(.system(size: store.settings.sensitiveMode ? 26 : 36, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.color(for: store.snapshot.phase))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            AttendanceButtons(store: store)
            HStack {
                Image(systemName: "clock")
                Text(store.snapshot.timerCaption).monospacedDigit()
            }
            .font(.system(size: 15, weight: .medium))
            Divider()
            HStack {
                Text(store.snapshot.phase == .overtime ? "每秒亏损" : "每秒收入")
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text(store.presentation.rate).monospacedDigit()
            }
            .font(.system(size: 13))
            summaryRow("当日赚取", amount: store.snapshot.earned, color: Palette.green)
            summaryRow("其中白嫖", amount: store.snapshot.freeloadAmount, color: .purple)
            summaryRow("超时亏损", amount: store.snapshot.overtimeLoss, color: Palette.red, loss: true)
            Text("白嫖已包含在赚取中").font(.system(size: 10)).foregroundStyle(Palette.muted)
            Divider()
            HStack {
                Button(action: openApp) {
                    Label("打开应用", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)
                Spacer()
                Button("退出", action: quit)
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.muted)
                    .help("停止计时并退出；退出期间不会累计亏损")
            }
            .font(.system(size: 12, weight: .medium))
        }
        .padding(22)
        .frame(width: 324)
        .foregroundStyle(Palette.ink)
        .background(.white)
        .preferredColorScheme(.light)
    }

    /// Formats a title/amount/color summary row using sensitive settings; loss selects a minus, returns a view.
    private func summaryRow(_ title: String, amount: Double, color: Color, loss: Bool = false) -> some View {
        HStack {
            Text(title).foregroundStyle(Palette.muted)
            Spacer()
            Text(store.settings.sensitiveMode
                 ? (amount == 0 ? "暂无" : ItemCatalog.item(for: amount, tiers: store.settings.activeItemTiers))
                 : MoneyText.currency(amount, negative: loss))
                .foregroundStyle(color).monospacedDigit()
        }
        .font(.system(size: 12))
    }
}

struct TouchBarPreview: View {
    var snapshot: EarningsSnapshot
    var settings = WorkSettings()

    var body: some View {
        HStack(spacing: 12) {
            Text("esc")
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .frame(width: 36, height: 30)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill").foregroundStyle(Palette.color(for: snapshot.phase))
                Text("活着的意义").foregroundStyle(.white)
            }
            .font(.system(size: 12, weight: .medium))
            separator
            Text(EarningsPresentation(snapshot: snapshot, settings: settings).compactAmount)
                .font(.system(size: settings.sensitiveMode ? 13 : 19, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.color(for: snapshot.phase))
                .frame(minWidth: 85)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            separator
            Text(snapshot.timerCaption)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(snapshot.phase == .overtime ? Palette.red : .white)
                .frame(maxWidth: .infinity)
            separator
            Text(snapshot.phase.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Palette.color(for: snapshot.phase), in: Capsule())
        }
        .padding(10)
        .background(Color(white: 0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private var separator: some View {
        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 14)
    }
}

struct DisplayPage: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeading(title: "抬头看一眼，就够了。", subtitle: "菜单栏常驻显示，Touch Bar 随应用一起呈现。")
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    Text("菜单栏").font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 10) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(Palette.color(for: store.snapshot.phase))
                        Text(store.presentation.menuText)
                            .monospacedDigit()
                            .foregroundStyle(Palette.color(for: store.snapshot.phase))
                        Spacer()
                        Image(systemName: "wifi")
                        Text(DateText.string(store.snapshot.date, pattern: "HH:mm"))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .padding(14)
                    .background(Palette.background, in: RoundedRectangle(cornerRadius: 9))
                    Toggle("紧凑模式：菜单栏只显示金额", isOn: Binding(
                        get: { store.settings.compactMenuBar },
                        set: { compact in
                            var settings = store.settings
                            settings.compactMenuBar = compact
                            store.updateSettings(settings)
                        }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 12))
                    .tint(Palette.green)
                    Text("所有 Mac 都支持菜单栏，不需要 Touch Bar。刘海屏和窄屏自动分两行显示金额与计时。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    HStack {
                        Button("恢复菜单栏显示") { store.restoreMenuBar?() }
                        Text("图标太多时，可开启紧凑模式，或按住 ⌘ 将本应用移到更靠右的位置。")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    Text("演示隐私").font(.system(size: 15, weight: .semibold))
                    PrivacyOptions(store: store)
                    Button("手动开启演示隐私") { store.togglePresentationPrivacy?() }
                        .buttonStyle(ActionButtonStyle())
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Touch Bar").font(.system(size: 15, weight: .semibold))
                    Text("工作状态示例").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    TouchBarPreview(snapshot: workingExample, settings: store.settings)
                    Text("超时状态示例").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    TouchBarPreview(snapshot: overtimeExample, settings: store.settings)
                    Text("在配备 Touch Bar 的 Mac 上，应用处于前台时显示。切换到其他应用后，"
                        + "Touch Bar 会跟随切换；菜单栏仍持续更新。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("以上为布局预览，实际可用宽度受系统控制条设置影响。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private var overtimeExample: EarningsSnapshot {
        EarningsSnapshot.previewOvertime(at: store.snapshot.date)
    }

    private var workingExample: EarningsSnapshot {
        EarningsSnapshot.previewWorking(at: store.snapshot.date)
    }
}

extension EarningsSnapshot {
    /// Creates a labeled working design sample on date; returns a synthetic snapshot at 16:11:24.
    static func previewWorking(at date: Date) -> EarningsSnapshot {
        var settings = WorkSettings()
        let calendar = WorkCalendar()
        settings.dateOverrides[calendar.key(for: date)] = true
        let time = calendar.time(16 * 60 + 11, on: date).addingTimeInterval(24)
        var records: [String: DayRecord] = [:]
        EarningsEngine().checkIn(
            at: calendar.time(settings.startMinute, on: date), settings: settings, records: &records
        )
        return EarningsEngine().snapshot(at: time, settings: settings, records: records)
    }

    /// Creates a clearly labeled overtime design sample at date; returns a synthetic preview snapshot.
    static func previewOvertime(at date: Date) -> EarningsSnapshot {
        var settings = WorkSettings()
        let calendar = WorkCalendar()
        settings.dateOverrides[calendar.key(for: date)] = true
        let time = calendar.time(18 * 60 + 54, on: date).addingTimeInterval(16)
        var record = DayRecord()
        record.overtimeSeconds = 1456
        record.overtimeLoss = 12.96
        return EarningsEngine().snapshot(
            at: time,
            settings: settings,
            records: [calendar.key(for: time): record]
        )
    }
}
