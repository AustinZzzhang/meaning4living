import SwiftUI
import LivingCore

struct AttendanceButtons: View {
    @ObservedObject var store: AppStore
    @State private var earlyConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.hasConfirmedSchedule {
                Button("先设置薪资与作息") { store.selectedPage = .settings }.buttonStyle(ActionButtonStyle())
            } else if store.snapshot.phase != .rest && store.snapshot.phase != .checkedOut {
                HStack {
                    if store.snapshot.checkInAt == nil {
                        Button("上班打卡") { _ = store.punch(arriving: true) }
                            .buttonStyle(ActionButtonStyle())
                    } else {
                        Label("已上班打卡", systemImage: "checkmark.circle").foregroundStyle(Palette.green)
                    }
                    Spacer()
                    Button("下班打卡") {
                        if let shift = store.snapshot.shift, store.snapshot.date < shift.end {
                            earlyConfirmation = true
                        } else {
                            _ = store.punch(arriving: false)
                        }
                    }
                    .buttonStyle(ActionButtonStyle(color: Palette.color(for: store.snapshot.phase)))
                    .disabled(store.snapshot.phase == .beforeWork)
                }
            }
            if let message = store.actionMessage {
                Text(message).font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }
        .alert("提前下班并结算今天？", isPresented: $earlyConfirmation) {
            Button("取消", role: .cancel) {}
            Button("下班并结算") { _ = store.punch(arriving: false) }
        } message: {
            Text("剩余计划工作时间将一次性计入白嫖，并包含在今日赚取中。之后不再产生超时亏损。")
        }
    }
}

struct DayRecordCard: View {
    let record: DayRecord
    let settings: WorkSettings
    let date: Date

    var body: some View {
        let amounts = DailyAmounts.calculate(record: record, asOf: date)
        VStack(alignment: .leading, spacing: 12) {
            Text(record.isSettled ? "当日已结算 ✓" : "当日记录")
                .font(.system(size: 15, weight: .semibold))
            HStack(spacing: 20) {
                amountColumn("当日赚取", amount: amounts.earned, color: Palette.green)
                amountColumn("其中白嫖", amount: amounts.freeload, color: .purple)
                amountColumn("超时亏损", amount: record.overtimeLoss, color: Palette.red, negative: true)
            }
            Text("白嫖金额已包含在赚取中，不重复相加。").font(.system(size: 11)).foregroundStyle(Palette.muted)
            HStack {
                Text("上班：\(punchText(record.checkInAt))")
                Spacer()
                Text("下班：\(punchText(record.checkOutAt))")
            }
            .font(.system(size: 12))
            Text("未打卡 \(MoneyText.duration(amounts.lateSeconds)) · 提前下班 \(MoneyText.duration(amounts.earlySeconds))")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            if record.checkOutAt != nil, amounts.earlySeconds > 0 {
                Text("已包含提前下班的剩余计划时段。").font(.system(size: 11)).foregroundStyle(.purple)
            }
            if !record.manualChanges.isEmpty {
                Text("已手动更正 \(record.manualChanges.count) 次").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
        }
    }

    /// Formats amount using sensitive settings, title and color; negative selects loss formatting, returns a column.
    private func amountColumn(_ title: String, amount: Double, color: Color, negative: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 11)).foregroundStyle(Palette.muted)
            Text(settings.sensitiveMode
                 ? (amount == 0 ? (negative ? "暂无损失" : "尚未积累")
                    : ItemCatalog.item(for: amount, tiers: settings.activeItemTiers))
                 : MoneyText.currency(amount, negative: negative))
                .font(.system(size: settings.sensitiveMode ? 14 : 19, weight: .semibold))
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Formats optional punch in the recorded timezone; returns a time or explicit missing label.
    private func punchText(_ punch: Date?) -> String {
        guard let punch else { return "未打卡" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        formatter.timeZone = record.plan.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .autoupdatingCurrent
        return formatter.string(from: punch)
    }
}

struct AttendanceEditor: View {
    @ObservedObject var store: AppStore
    let key: String
    let record: DayRecord
    @Environment(\.dismiss) private var dismiss
    @State private var hasArrival = false
    @State private var hasDeparture = false
    @State private var arrival = Date()
    @State private var departure = Date()
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("补卡／更正记录 · \(key)").font(.headline)
            Toggle("记录上班打卡", isOn: $hasArrival)
            if hasArrival { DatePicker("上班时间", selection: $arrival) }
            Toggle("记录下班打卡", isOn: $hasDeparture)
            if hasDeparture { DatePicker("下班时间", selection: $departure) }
            Text("按该日保存的排班与费率重算白嫖。亏损只按已记录的运行时段重算，不补扣关闭期间。")
                .font(.system(size: 12)).foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("时间按班次记录时的时区：\(record.plan?.timeZoneID ?? "系统时区")")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            if record.legacyLoss > 0 {
                Text("旧版本已有亏损没有明细，原金额保留。").font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            if let error { Text(error).foregroundStyle(Palette.red).font(.system(size: 12)) }
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("保存更正") {
                    error = store.correctAttendance(
                        key: key, checkIn: hasArrival ? arrival : nil, checkOut: hasDeparture ? departure : nil
                    )
                    if error == nil { dismiss() }
                }
                .buttonStyle(ActionButtonStyle())
            }
        }
        .padding(28).frame(width: 500)
        .foregroundStyle(Palette.ink).background(Palette.background).preferredColorScheme(.light)
        .onAppear {
            hasArrival = record.checkInAt != nil
            hasDeparture = record.checkOutAt != nil
            arrival = record.checkInAt ?? record.plan?.shift.start ?? Date()
            departure = record.checkOutAt ?? record.plan?.shift.end ?? Date()
        }
        .onChange(of: store.presentationHidden) { hidden in if hidden { dismiss() } }
        .environment(\.timeZone, record.plan.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .autoupdatingCurrent)
    }
}

struct PresentationPrivacyView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "eye.slash").font(.system(size: 42)).foregroundStyle(Palette.green)
            Text("演示隐私已开启").font(.title2)
            Text(store.presentationReason).foregroundStyle(Palette.muted)
            Text("菜单栏、金额、物品和打卡详情已隐藏，后台计时继续。")
                .font(.system(size: 13)).foregroundStyle(Palette.muted)
            Button("切换手动隐私（⌃⌥⌘P）") { store.togglePresentationPrivacy?() }
                .buttonStyle(ActionButtonStyle())
            Text("自动检测到镜像或外接屏时，需断开对应连接，或关闭下面的自动选项。")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            PrivacyOptions(store: store)
        }
        .padding(40).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

struct PrivacyOptions: View {
    @ObservedObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("屏幕镜像时自动隐藏", isOn: Binding(
                get: { store.settings.hideMenuBarWhenMirroring },
                set: { value in
                    var next = store.settings
                    next.hideMenuBarWhenMirroring = value
                    store.updateSettings(next)
                }
            ))
            Toggle("连接外接显示器时也隐藏", isOn: Binding(
                get: { store.settings.hideWhenExternalDisplay },
                set: { value in
                    var next = store.settings
                    next.hideWhenExternalDisplay = value
                    store.updateSettings(next)
                }
            ))
            Text("会议软件共享和第三方录屏不一定能被检测。共享前可按 ⌃⌥⌘P 手动隐藏，再按一次解除手动隐藏。")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            if !store.privacyShortcutAvailable {
                Text("快捷键被占用或注册失败，请通过本页按钮或应用菜单切换演示隐私。")
                    .font(.system(size: 11)).foregroundStyle(Palette.red)
            }
        }
        .toggleStyle(.switch).tint(Palette.green)
    }
}
