import SwiftUI
import LivingCore

struct SettingsGateView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var gate: SettingsLock
    @State private var password = ""

    var body: some View {
        Group {
            if gate.canView {
                SettingsPage(store: store)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    SectionHeading(title: "设置已保护", subtitle: "输入保护密码后，才能查看和修改设置。")
                    Surface {
                        VStack(alignment: .leading, spacing: 18) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 32))
                                .foregroundStyle(Palette.green)
                            SecureField("保护密码", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 320)
                                .onSubmit(unlock)
                            if let error = gate.error {
                                Text(error).font(.system(size: 12)).foregroundStyle(Palette.red)
                            }
                            HStack {
                                Button("解锁设置", action: unlock).buttonStyle(ActionButtonStyle())
                                Button("重试读取") { gate.refresh() }.buttonStyle(.plain)
                            }
                            Text("离开设置、切换应用或关闭窗口后会重新锁定。")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
        }
        .onAppear { gate.refresh() }
        .onDisappear {
            password = ""
            gate.lock()
        }
        .onChange(of: gate.isUnlocked) { _ in password = "" }
    }

    /// Submits the local password to the gate and clears it; no parameters or return value.
    private func unlock() {
        gate.unlock(password)
        password = ""
    }
}

struct PasswordSettingsCard: View {
    @ObservedObject var gate: SettingsLock
    @State private var current = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var message: String?
    @State private var succeeded = false

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Label("设置保护密码", systemImage: "lock.shield")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    Text(gate.isProtected ? "已开启" : "未开启")
                        .font(.system(size: 12))
                        .foregroundStyle(gate.isProtected ? Palette.green : Palette.muted)
                }
                Text("开启后，每次重新进入设置需要密码。密码校验信息保存在这台 Mac 的钥匙串中。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                if gate.isProtected {
                    SecureField("当前密码（修改或关闭保护时填写）", text: $current)
                }
                SecureField(gate.isProtected ? "新密码，至少 6 位" : "设置密码，至少 6 位", text: $password)
                SecureField("再次输入新密码", text: $confirmation)
                HStack(spacing: 16) {
                    Button(gate.isProtected ? "修改密码" : "开启密码保护") {
                        finish(gate.setPassword(password, confirmation: confirmation, current: current))
                    }
                    .buttonStyle(ActionButtonStyle())
                    if gate.isProtected {
                        Button("关闭保护") { finish(gate.disable(current: current)) }
                            .buttonStyle(.plain)
                            .foregroundStyle(Palette.red)
                        Spacer()
                        Button("立即锁定") { gate.lock() }.buttonStyle(.plain)
                    }
                }
                if let message {
                    Text(message).font(.system(size: 12)).foregroundStyle(succeeded ? Palette.green : Palette.red)
                }
            }
            .textFieldStyle(.roundedBorder)
        }
        .onDisappear {
            current = ""
            password = ""
            confirmation = ""
        }
    }

    /// Shows error or success for a password operation and clears fields; returns nothing.
    private func finish(_ error: String?) {
        succeeded = error == nil
        message = error ?? "保护设置已保存。"
        current = ""
        password = ""
        confirmation = ""
    }
}

struct SensitiveSettingsCard: View {
    @Binding var draft: WorkSettings

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 17) {
                Toggle("敏感模式", isOn: $draft.sensitiveMode)
                    .toggleStyle(.switch)
                    .font(.system(size: 15, weight: .semibold))
                    .tint(Palette.green)
                Text("隐藏工资和精确金额，改用物品表达收入与亏损。主窗口、菜单栏、Touch Bar 和日历同步生效。")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                Picker("物品方案", selection: $draft.itemPreset) {
                    ForEach(ItemPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.itemPreset) { preset in
                    if preset == .custom, draft.customItemTiers.isEmpty {
                        draft.customItemTiers = ItemPreset.food.tiers
                    }
                }
                HStack {
                    Text("金额下限（含）").frame(width: 110, alignment: .leading)
                    Text("展示物品")
                    Spacer()
                }
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
                if draft.itemPreset == .custom {
                    ForEach($draft.customItemTiers) { $tier in
                        ItemTierEditor(tier: $tier) {
                            draft.customItemTiers.removeAll { $0.id == tier.id }
                        }
                    }
                    Button("添加价格区间") {
                        let next = (draft.customItemTiers.last?.minimum ?? 0) + 100
                        draft.customItemTiers.append(ItemTier(minimum: next, item: "一件喜欢的东西"))
                    }
                    .disabled(draft.customItemTiers.count >= 20)
                } else {
                    ForEach(draft.itemPreset.tiers) { tier in
                        HStack {
                            Text("≥ \(MoneyText.currency(tier.minimum))").frame(width: 110, alignment: .leading)
                            Text(tier.item)
                            Spacer()
                        }
                        .font(.system(size: 12))
                    }
                    Button("以这套方案开始自定义") {
                        draft.customItemTiers = draft.itemPreset.tiers
                        draft.itemPreset = .custom
                    }
                }
                Text("区间按下限递增，直到下一档下限之前。低于首档显示“一点小确幸”，"
                    + "最高档没有上限。赚取和超时损失使用同一组区间；这些是趣味折算价。")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ItemTierEditor: View {
    @Binding var tier: ItemTier
    var remove: () -> Void
    @State private var minimumText = ""

    var body: some View {
        HStack(spacing: 12) {
            TextField("下限", text: $minimumText)
                .frame(width: 110)
                .onChange(of: minimumText) { text in
                    let value = Double(text.trimmingCharacters(in: .whitespaces))
                    tier.minimum = value?.isFinite == true ? value! : -1
                }
            TextField("例如：一杯奶茶", text: $tier.item)
            Button(action: remove) {
                Image(systemName: "minus.circle").foregroundStyle(Palette.red)
            }
            .buttonStyle(.plain)
            .help("删除此区间")
        }
        .textFieldStyle(.roundedBorder)
        .onAppear { minimumText = String(tier.minimum) }
    }
}
