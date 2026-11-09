import SwiftUI
import LivingCore

struct CalendarPage: View {
    @ObservedObject var store: AppStore
    @State private var month = Date()
    @State private var selected = Date()
    @State private var editing = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeading(title: "工作有日历，生活有留白。", subtitle: "按真实日期计薪，选中日期即可调整休息或补班。")
            Surface {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        Text(DateText.string(month, pattern: "yyyy年 M月"))
                            .font(.system(size: 20, weight: .semibold))
                        Spacer()
                        Button("今天") {
                            month = store.snapshot.date
                            selected = store.snapshot.date
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.green)
                        Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                            .buttonStyle(.plain)
                            .help("上个月")
                        Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                            .buttonStyle(.plain)
                            .help("下个月")
                    }
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                            Text(day).font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.bottom, 5)
                        }
                        let days = store.workCalendar.days(inMonthOf: month)
                        let offset = (store.workCalendar.calendar.component(.weekday, from: days[0]) + 5) % 7
                        ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 57) }
                        ForEach(days, id: \.self) { date in
                            dayCell(date)
                        }
                    }
                    HStack(spacing: 16) {
                        Label("工作日", systemImage: "circle.fill").foregroundStyle(Palette.green)
                        Label("休息日", systemImage: "circle.fill").foregroundStyle(Palette.muted)
                        Text("休：放假 · 班：补班 · 自：个人覆盖")
                        Spacer()
                        let total = store.workCalendar.monthTotals(for: month, settings: store.settings)
                        Text("本月 \(total.days) 个工作日")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.muted)
                }
            }
            Surface {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text(DateText.string(selected, pattern: "M月d日 EEEE"))
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text(store.workCalendar.scheduleLabel(selected, settings: store.settings))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.green)
                    }
                    Picker("日期安排", selection: overrideBinding) {
                        Text("跟随日历").tag(0)
                        Text("设为工作日").tag(1)
                        Text("设为休息日").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    let key = store.workCalendar.key(for: selected)
                    if let record = store.records[key] {
                        if record.plan != nil {
                            DayRecordCard(record: record, settings: store.settings, date: store.snapshot.date)
                            Text("按记录时排班与费率结算；更改日历不会重算已有记录。")
                                .font(.system(size: 11)).foregroundStyle(Palette.muted)
                            Button("补卡／更正记录") { editing = true }
                        } else {
                            Text("旧版本记录：\(ItemCatalog.loss(record.overtimeLoss, settings: store.settings))")
                                .font(.system(size: 12)).foregroundStyle(Palette.muted)
                            Text("旧版本未保存打卡、赚取与白嫖明细，不补造历史。").font(.system(size: 11))
                        }
                    } else {
                        Text("无记录：未使用应用的日期不会自动补成白嫖。")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                }
            }
            HStack {
                Text("本月已记录超时亏损")
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text(ItemCatalog.loss(store.monthLoss(for: month), settings: store.settings))
                    .foregroundStyle(Palette.red)
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            let year = store.workCalendar.calendar.component(.year, from: month)
            Text(store.settings.useChinaHolidayCalendar
                 ? (ChinaHolidayCalendar.supports(year: year)
                    ? "已内置 \(String(year)) 年中国大陆官方放假与调休安排；个人覆盖优先。"
                    : "\(String(year)) 年节假日安排待更新，暂按每周设置。")
                 : "当前使用自定义每周作息，未启用中国大陆节假日。")
                .font(.system(size: 11)).foregroundStyle(Palette.muted)
            Text("日历使用系统时区，不读取个人日程。当前日期随设置重算，历史班次保存当时的时区、排班和费率。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
        }
        .onAppear {
            month = store.snapshot.date
            selected = store.snapshot.date
        }
        .sheet(isPresented: $editing) {
            let key = store.workCalendar.key(for: selected)
            if let record = store.records[key] {
                AttendanceEditor(store: store, key: key, record: record)
            }
        }
        .onChange(of: store.presentationHidden) { hidden in if hidden { editing = false } }
    }

    private var overrideBinding: Binding<Int> {
        Binding(
            get: {
                guard let value = store.settings.dateOverrides[store.workCalendar.key(for: selected)] else { return 0 }
                return value ? 1 : 2
            },
            set: { value in store.setDay(selected, workday: value == 0 ? nil : value == 1) }
        )
    }

    /// Moves the displayed month by offset and selects its first day; returns nothing.
    private func moveMonth(_ offset: Int) {
        let calendar = store.workCalendar.calendar
        let start = calendar.dateInterval(of: .month, for: month)!.start
        month = calendar.date(byAdding: .month, value: offset, to: start)!
        selected = month
    }

    /// Returns a selectable cell for date with work/rest, today and override indicators.
    private func dayCell(_ date: Date) -> some View {
        let calendar = store.workCalendar.calendar
        let workday = store.workCalendar.isWorkday(date, settings: store.settings)
        let active = calendar.isDate(date, inSameDayAs: selected)
        let today = calendar.isDate(date, inSameDayAs: store.snapshot.date)
        let overridden = store.settings.dateOverrides[store.workCalendar.key(for: date)] != nil
        let official = store.settings.useChinaHolidayCalendar ? store.workCalendar.officialDayInfo(date) : nil
        return Button { selected = date } label: {
            VStack(spacing: 5) {
                HStack(spacing: 3) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: 14, weight: today ? .bold : .medium))
                    if overridden {
                        Text("自").font(.system(size: 8)).foregroundStyle(Palette.muted)
                    } else if let official {
                        Text(official.isWorkday ? "班" : "休")
                            .font(.system(size: 8)).foregroundStyle(official.isWorkday ? Palette.green : Palette.red)
                    }
                }
                .foregroundStyle(today ? Palette.green : Palette.ink)
                Circle().fill(workday ? Palette.green : Color.gray.opacity(0.25)).frame(width: 4, height: 4)
                if let official {
                    Text(official.name).font(.system(size: 8)).lineLimit(1).foregroundStyle(Palette.muted)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 57)
            .background(active ? Palette.green.opacity(0.07) : Palette.background.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9).stroke(active ? Palette.green.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help("\(DateText.string(date, pattern: "M月d日")) · "
              + store.workCalendar.scheduleLabel(date, settings: store.settings))
    }
}
