import AppKit
import SwiftUI
import LivingCore

struct RootView: View {
    @ObservedObject var store: AppStore
    var quit: () -> Void

    var body: some View {
        if store.presentationHidden {
            PresentationPrivacyView(store: store)
        } else {
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Palette.line).frame(width: 1)
                VStack(spacing: 0) {
                    if let error = store.storageError {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.red)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Palette.red.opacity(0.07))
                    }
                    ScrollView {
                        Group {
                            if !store.hasConfirmedSchedule {
                                SettingsGateView(store: store, gate: store.settingsLock)
                            } else {
                                switch store.selectedPage {
                                case .home: DashboardView(store: store, quit: quit)
                                case .calendar: CalendarPage(store: store)
                                case .display: DisplayPage(store: store)
                                case .settings: SettingsGateView(store: store, gate: store.settingsLock)
                                case .updates: UpdatePage(updater: store.updates)
                                }
                            }
                        }
                        .padding(30)
                        .frame(maxWidth: 960, alignment: .topLeading)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(Palette.background)
            }
            .foregroundStyle(Palette.ink)
            .frame(minWidth: 900, minHeight: 710)
            .preferredColorScheme(.light)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityLabel("活着的意义 · 伯恩山犬")
                Text("活着的意义").font(.system(size: 22, weight: .bold))
                Text("认真工作，也准时生活。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            VStack(spacing: 7) {
                ForEach(AppPage.allCases) { page in
                    Button {
                        store.selectedPage = page
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: page.icon).frame(width: 20)
                            Text(page.rawValue)
                            Spacer()
                        }
                        .font(.system(size: 14, weight: store.selectedPage == page ? .semibold : .regular))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .foregroundStyle(store.selectedPage == page ? Palette.green : Palette.ink)
                        .background(
                            store.selectedPage == page ? Palette.green.opacity(0.09) : .clear,
                            in: RoundedRectangle(cornerRadius: 11)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 7) {
                Text(DateText.string(store.snapshot.date, pattern: "M月d日 EEEE"))
                    .font(.system(size: 12, weight: .medium))
                Text("每一秒，都算数。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .frame(width: 198)
        .background(Color(red: 0.975, green: 0.98, blue: 0.982))
    }
}

struct DashboardView: View {
    @ObservedObject var store: AppStore
    var quit: () -> Void
    private var snapshot: EarningsSnapshot { store.snapshot }
    private var accent: Color { Palette.color(for: snapshot.phase) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                SectionHeading(
                    title: snapshot.phase == .overtime ? "到点了，去生活吧。" : "今天，也在慢慢积累。",
                    subtitle: DateText.string(snapshot.date, pattern: "yyyy年M月d日 EEEE")
                )
                Spacer()
                StatusPill(phase: snapshot.phase)
            }
            earningsCard
            if let record = store.records[snapshot.dayKey], record.plan != nil {
                Surface { DayRecordCard(record: record, settings: store.settings, date: snapshot.date) }
            }
            HStack(spacing: 16) {
                settingsTile(
                    title: "月薪",
                    value: store.presentation.salary,
                    icon: "banknote"
                )
                settingsTile(
                    title: "工作时间",
                    value: scheduleText,
                    icon: "clock"
                )
            }
            Surface {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("本周日历").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button("查看完整日历  ›") { store.selectedPage = .calendar }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                    weekStrip
                }
            }
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("关闭窗口后，仍会在菜单栏计时。").font(.system(size: 11))
                    Text("退出应用即可停止超时亏损，退出期间不补扣。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                Button("退出应用", action: quit)
                    .buttonStyle(ActionButtonStyle(color: snapshot.phase == .overtime ? Palette.red : Palette.green))
            }
        }
    }

    private var scheduleText: String {
        let suffix = store.settings.isOvernight ? " 次日" : ""
        return "\(MoneyText.clock(store.settings.startMinute)) – \(MoneyText.clock(store.settings.endMinute))\(suffix)"
    }

    private var earningsCard: some View {
        Surface {
            VStack(alignment: .leading, spacing: 19) {
                HStack {
                    Text(store.presentation.headline)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Spacer()
                    Text(snapshot.phase == .checkedOut ? "结算完成" : "实时更新")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
                Text(store.presentation.amount)
                    .font(.system(size: store.settings.sensitiveMode ? 40 : 58, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel(store.presentation.accessibilityLabel)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.background)
                        Capsule().fill(accent)
                            .frame(width: geometry.size.width * snapshot.progress)
                    }
                }
                .frame(height: 7)
                HStack {
                    Label(snapshot.phase.title, systemImage: "circle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(accent)
                    Spacer()
                    Text(snapshot.timerCaption)
                        .font(.system(size: 18, weight: .semibold))
                        .monospacedDigit()
                }
                Rectangle().fill(Palette.line).frame(height: 1)
                AttendanceButtons(store: store)
                HStack(alignment: .firstTextBaseline) {
                    Text(snapshot.phase == .overtime ? "每秒亏损" : "每秒收入")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                    Text(store.presentation.rate)
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                    Spacer()
                    Text(snapshot.phase == .overtime ? store.presentation.earned : monthNote)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
            }
        }
    }

    private var monthNote: String {
        let day = snapshot.shift?.day ?? snapshot.date
        return "\(DateText.string(day, pattern: "M月")) · \(snapshot.monthWorkdays) 个工作日"
    }

    private var weekStrip: some View {
        let calendar = store.workCalendar.calendar
        let today = calendar.startOfDay(for: snapshot.date)
        let offset = (calendar.component(.weekday, from: today) + 5) % 7
        let monday = store.workCalendar.addingDays(-offset, to: today)
        return HStack(spacing: 0) {
            ForEach(0..<7) { index in
                let day = store.workCalendar.addingDays(index, to: monday)
                let current = calendar.isDate(day, inSameDayAs: today)
                let workday = store.workCalendar.isWorkday(day, settings: store.settings)
                VStack(spacing: 10) {
                    Text(["一", "二", "三", "四", "五", "六", "日"][index])
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    Text("\(calendar.component(.day, from: day))")
                        .font(.system(size: 14, weight: current ? .bold : .medium))
                        .foregroundStyle(current ? Palette.green : Palette.ink)
                        .frame(width: 34, height: 34)
                        .background(current ? Palette.green.opacity(0.1) : .clear, in: Circle())
                    Circle().fill(workday ? Palette.green : Color.gray.opacity(0.2)).frame(width: 4, height: 4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Builds a settings shortcut card using title, formatted value and symbol; returns a button view.
    private func settingsTile(title: String, value: String, icon: String) -> some View {
        Button {
            store.selectedPage = .settings
        } label: {
            Surface {
                VStack(alignment: .leading, spacing: 12) {
                    Label(title, systemImage: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                    HStack {
                        Text(value).font(.system(size: 20, weight: .semibold)).minimumScaleFactor(0.7).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
