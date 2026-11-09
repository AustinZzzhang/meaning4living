import SwiftUI
import LivingCore

struct SettingsPage: View {
    @ObservedObject var store: AppStore
    @State private var draft = WorkSettings()
    @State private var salary = "18000"
    @State private var didSave = false
    @State private var section = 0

    private var candidate: WorkSettings {
        var value = draft
        let text = salary.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        value.monthlySalary = Double(text) ?? -1
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeading(title: "把时间，换算成自己的刻度。", subtitle: "设置月薪与作息，让每一秒都有清晰的数字。")
            if !store.hasConfirmedSchedule {
                Text("首次使用：请确认月薪和作息并保存，之后才会开始记录当天收入与打卡。")
                    .font(.system(size: 12)).foregroundStyle(Palette.green)
            }
            Picker("设置分类", selection: $section) {
                Text("薪资作息").tag(0)
                Text("敏感模式").tag(1)
                Text("密码保护").tag(2)
            }
            .pickerStyle(.segmented)
            if section == 1 {
                SensitiveSettingsCard(draft: $draft)
            }
            if section == 0 {
                salarySettings
                calculationExplanation
            }
            if section != 2 { saveButton }
            if section == 2 { PasswordSettingsCard(gate: store.settingsLock) }
        }
        .onAppear {
            draft = store.settings
            salary = String(format: "%.2f", store.settings.monthlySalary)
        }
        .onChange(of: draft) { _ in didSave = false }
        .onDisappear { salary = "" }
    }

    private var salarySettings: some View {
        Surface {
                VStack(alignment: .leading, spacing: 22) {
                    Text("薪资与作息").font(.system(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("月薪").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        HStack(spacing: 10) {
                            Text("¥").foregroundStyle(Palette.muted)
                            Group {
                                if draft.sensitiveMode {
                                    SecureField("月薪已隐藏，仍可修改", text: $salary)
                                } else {
                                    TextField("例如 18000", text: $salary)
                                }
                            }
                                .textFieldStyle(.plain)
                                .font(.system(size: 22, weight: .medium))
                                .onChange(of: salary) { _ in didSave = false }
                            Text("元 / 月").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        }
                        .padding(15)
                        .background(Palette.background, in: RoundedRectangle(cornerRadius: 10))
                    }
                    HStack(spacing: 28) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("上班时间").font(.system(size: 12)).foregroundStyle(Palette.muted)
                            DatePicker("", selection: timeBinding(start: true), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.field)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("下班时间").font(.system(size: 12)).foregroundStyle(Palette.muted)
                            DatePicker("", selection: timeBinding(start: false), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.field)
                        }
                        Spacer()
                        if draft.isOvernight {
                            Text("下班为次日")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.green)
                        }
                    }
                    Divider()
                    Toggle("采用中国大陆法定节假日与调休", isOn: $draft.useChinaHolidayCalendar)
                        .toggleStyle(.switch).tint(Palette.green)
                    Text("已内置 2025–2027 年官方安排。个人日期覆盖优先；未收录年份会提示待更新。")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("每周工作日").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        HStack(spacing: 8) {
                            ForEach(0..<7) { index in
                                let weekday = (index + 1) % 7 + 1
                                let active = draft.weekdays.contains(weekday)
                                Button {
                                    if active {
                                        draft.weekdays.remove(weekday)
                                    } else {
                                        draft.weekdays.insert(weekday)
                                    }
                                    didSave = false
                                } label: {
                                    Text(["周一", "周二", "周三", "周四", "周五", "周六", "周日"][index])
                                        .font(.system(size: 12, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .foregroundStyle(active ? Palette.green : Palette.muted)
                                        .background(
                                            active ? Palette.green.opacity(0.1) : Palette.background,
                                            in: RoundedRectangle(cornerRadius: 9)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(weekday) 工作日")
                                .accessibilityValue(active ? "已选择" : "未选择")
                            }
                        }
                        Text("普通日期按每周设置，官方放假、补班会覆盖；日历中可再单独调整。")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                    }
                }
        }
    }

    private var calculationExplanation: some View {
        Surface {
                VStack(alignment: .leading, spacing: 12) {
                    Text("怎么算").font(.system(size: 14, weight: .semibold))
                    Text("每秒薪资 = 月薪 ÷ 当月计划工作总秒数")
                        .font(.system(size: 13, weight: .medium))
                    if candidate.validationMessage == nil {
                        let totals = store.workCalendar.monthTotals(for: store.snapshot.date, settings: candidate)
                        Text(draft.sensitiveMode
                            ? "本月 \(totals.days) 个工作日 · 精确金额已隐藏"
                            : "本月 \(totals.days) 个工作日 · 每秒 \(MoneyText.rate(previewRate))")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.green)
                    }
                    Text("整个班次计薪，暂不扣午休。白嫖包含在赚取内；下班打卡停止亏损。"
                        + "保存工资或作息后，当前日期会立即重算；已经过去的日期保留原记录。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
    }

    private var saveButton: some View {
        HStack {
                if let error = candidate.validationMessage {
                    Text(error).font(.system(size: 12)).foregroundStyle(Palette.red)
                } else if didSave {
                    Label("已保存到本机", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.green)
                }
                Spacer()
                Button("保存设置") {
                    didSave = store.updateSettings(candidate, confirmSchedule: true) == nil
                }
                .buttonStyle(ActionButtonStyle())
                .disabled(candidate.validationMessage != nil)
                .opacity(candidate.validationMessage == nil ? 1 : 0.5)
        }
    }

    private var previewRate: Double {
        store.workCalendar.rate(for: store.snapshot.date, settings: candidate)
    }

    /// Binds a time picker to start/end minute fields; start selects the field and returns a Date binding.
    private func timeBinding(start: Bool) -> Binding<Date> {
        Binding(
            get: {
                store.workCalendar.time(start ? draft.startMinute : draft.endMinute, on: store.snapshot.date)
            },
            set: { date in
                let parts = store.workCalendar.calendar.dateComponents([.hour, .minute], from: date)
                let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                if start {
                    draft.startMinute = minute
                } else {
                    draft.endMinute = minute
                }
                didSave = false
            }
        )
    }
}
