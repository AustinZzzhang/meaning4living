import Foundation

public struct ItemTier: Codable, Equatable, Identifiable {
    public var id: String
    public var minimum: Double
    public var item: String

    /// Creates a tier from its minimum amount and display item; id optionally preserves an edited row.
    public init(minimum: Double, item: String, id: String = UUID().uuidString) {
        self.id = id
        self.minimum = minimum
        self.item = item
    }
}

public enum ItemPreset: String, Codable, CaseIterable, Identifiable {
    case fashion
    case electronics
    case food
    case custom

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .fashion: return "衣服首饰"
        case .electronics: return "数码电子"
        case .food: return "零食美食"
        case .custom: return "自定义"
        }
    }

    public var tiers: [ItemTier] {
        let values: [(Double, String)]
        switch self {
        case .fashion:
            values = [
                (5, "一根发圈"), (30, "一对耳饰"), (80, "一条围巾"), (200, "一件衣服"),
                (500, "一双鞋子"), (1500, "一个包包"), (3000, "一条项链"), (8000, "一枚戒指")
            ]
        case .electronics:
            values = [
                (5, "一个理线器"), (30, "一根数据线"), (100, "一个充电器"), (300, "一副耳机"),
                (800, "一把机械键盘"), (2000, "一台显示器"), (5000, "一个手机"), (10000, "一台电脑")
            ]
        case .food:
            values = [
                (1, "一颗糖"), (5, "一包薯片"), (15, "一杯奶茶"), (35, "一杯咖啡"),
                (80, "一顿美餐"), (200, "一顿火锅"), (500, "一顿海鲜"), (1500, "一场美食之旅")
            ]
        case .custom:
            values = []
        }
        return values.enumerated().map {
            ItemTier(minimum: $0.element.0, item: $0.element.1, id: "\(rawValue)-\($0.offset)")
        }
    }
}

public enum ItemCatalog {
    /// Validates editable tiers for order, unique IDs and labels; returns a user-facing error or nil.
    public static func validationMessage(for tiers: [ItemTier]) -> String? {
        guard (1...20).contains(tiers.count) else { return "请设置 1 至 20 个价格区间。" }
        guard Set(tiers.map(\.id)).count == tiers.count else { return "区间标识重复，请重新添加该行。" }
        var previous = -Double.infinity
        for tier in tiers {
            guard tier.minimum.isFinite, tier.minimum >= 0, tier.minimum <= 100_000_000 else {
                return "区间下限须为 0 至 1 亿之间的有效金额。"
            }
            guard tier.minimum > previous else { return "区间下限须从小到大排列，且不能重复。" }
            let trimmed = tier.item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count <= 16,
                  !tier.item.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                return "每个物品名称需为 1 至 16 个字，不能包含换行。"
            }
            previous = tier.minimum
        }
        return nil
    }

    /// Selects the highest matching tier for the absolute amount; returns identical items for gains/losses.
    public static func item(for amount: Double, tiers: [ItemTier]) -> String {
        guard amount.isFinite, abs(amount) > 0 else { return "还没有积累" }
        return tiers.last(where: { abs(amount) >= $0.minimum })?.item
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "一点小确幸"
    }

    /// Formats a stored loss using settings, including zero handling; returns item text or a negative currency value.
    public static func loss(_ amount: Double, settings: WorkSettings) -> String {
        if !settings.sensitiveMode { return MoneyText.currency(amount, negative: true) }
        return amount > 0 ? "已损失\(item(for: amount, tiers: settings.activeItemTiers))" : "暂无损失"
    }
}

public struct EarningsPresentation {
    public let snapshot: EarningsSnapshot
    public let settings: WorkSettings

    /// Creates a presentation from snapshot and settings; returns a privacy-aware display projection.
    public init(snapshot: EarningsSnapshot, settings: WorkSettings) {
        self.snapshot = snapshot
        self.settings = settings
    }

    public var headline: String {
        if snapshot.phase == .overtime {
            return settings.sensitiveMode ? "今天已损失" : "超时亏损"
        }
        if snapshot.phase == .awaitingCheckIn {
            return settings.sensitiveMode ? "今天已白嫖到" : "已白嫖"
        }
        if snapshot.phase == .checkedOut {
            return settings.sensitiveMode ? "今天已结算" : "今日已结算"
        }
        return settings.sensitiveMode ? "今天已赚到" : "今日收入"
    }

    public var amount: String {
        if !settings.sensitiveMode { return snapshot.amountText }
        if snapshot.amount == 0 {
            return snapshot.phase == .overtime ? "暂无损失" : "慢慢积累中"
        }
        return ItemCatalog.item(for: snapshot.amount, tiers: settings.activeItemTiers)
    }

    public var compactAmount: String {
        guard settings.sensitiveMode, snapshot.amount != 0 else { return amount }
        return (snapshot.phase == .overtime ? "−" : "+") + amount
    }

    public var menuText: String {
        if snapshot.phase == .rest { return "休息日" }
        if snapshot.phase == .checkedOut { return "已下班 ✓" }
        let state = snapshot.phase == .awaitingCheckIn ? "白嫖 " : ""
        return settings.compactMenuBar ? state + compactAmount : "\(state)\(compactAmount) · \(snapshot.timerText)"
    }

    public var rate: String { settings.sensitiveMode ? "金额已隐藏" : MoneyText.rate(snapshot.rate) }
    public var salary: String { settings.sensitiveMode ? "已隐藏" : MoneyText.currency(settings.monthlySalary) }
    public var earned: String {
        if settings.sensitiveMode && snapshot.earned == 0 { return "今日尚未积累" }
        return settings.sensitiveMode
            ? "今日已赚到\(ItemCatalog.item(for: snapshot.earned, tiers: settings.activeItemTiers))"
            : "今日已赚 \(MoneyText.currency(snapshot.earned))"
    }
    public var freeload: String {
        if settings.sensitiveMode && snapshot.freeloadAmount == 0 { return "暂无白嫖" }
        return settings.sensitiveMode
            ? "白嫖\(ItemCatalog.item(for: snapshot.freeloadAmount, tiers: settings.activeItemTiers))"
            : "白嫖 \(MoneyText.currency(snapshot.freeloadAmount))"
    }
    public var overtime: String {
        settings.sensitiveMode
            ? ItemCatalog.loss(snapshot.overtimeLoss, settings: settings)
            : MoneyText.currency(snapshot.overtimeLoss, negative: true)
    }
    public var accessibilityLabel: String { "\(headline)，\(amount)，\(snapshot.timerCaption)" }
}
