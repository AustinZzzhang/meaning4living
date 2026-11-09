import AppKit
import LivingCore

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let brandID = NSTouchBarItem.Identifier("local.livingmeaning.brand")
    private let amountID = NSTouchBarItem.Identifier("local.livingmeaning.amount")
    private let timerID = NSTouchBarItem.Identifier("local.livingmeaning.timer")
    private let phaseID = NSTouchBarItem.Identifier("local.livingmeaning.phase")
    private var labels: [NSTouchBarItem.Identifier: NSTextField] = [:]
    private var latest: EarningsSnapshot?
    private var latestSettings = WorkSettings()
    private var privacyHidden = false
    let touchBar = NSTouchBar()

    /// Creates the four native Touch Bar items; no parameters, returns a controller.
    override init() {
        super.init()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [brandID, amountID, timerID, phaseID]
        touchBar.principalItemIdentifier = amountID
    }

    /// Builds a requested native item for touchBar and identifier; returns nil for unknown identifiers.
    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard [brandID, amountID, timerID, phaseID].contains(identifier) else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let label = NSTextField(labelWithString: "")
        let large = identifier == amountID
        label.font = .monospacedDigitSystemFont(ofSize: large ? 19 : 13, weight: large ? .semibold : .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        let widths: [NSTouchBarItem.Identifier: CGFloat] = [
            brandID: 126,
            amountID: 116,
            timerID: 170,
            phaseID: 70
        ]
        let container = NSView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: widths[identifier]!),
            container.heightAnchor.constraint(equalToConstant: 30),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 3),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -3),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        if identifier != phaseID {
            let divider = NSView()
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
            divider.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(divider)
            NSLayoutConstraint.activate([
                divider.widthAnchor.constraint(equalToConstant: 1),
                divider.heightAnchor.constraint(equalToConstant: 14),
                divider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                divider.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
        }
        labels[identifier] = label
        item.view = container
        if let latest { update(latest, settings: latestSettings) }
        return item
    }

    /// Updates labels from snapshot/settings with privacy projection and phase colors; returns nothing.
    func update(_ snapshot: EarningsSnapshot, settings: WorkSettings = WorkSettings()) {
        latest = snapshot
        latestSettings = settings
        if privacyHidden {
            for (identifier, label) in labels {
                label.stringValue = identifier == brandID ? "演示隐私已开启" : ""
                label.drawsBackground = false
                label.textColor = .lightGray
            }
            return
        }
        let color: NSColor
        switch snapshot.phase {
        case .working, .checkedOut: color = NSColor(calibratedRed: 0.1, green: 0.86, blue: 0.43, alpha: 1)
        case .awaitingCheckIn: color = .systemPurple
        case .overtime: color = NSColor(calibratedRed: 1, green: 0.31, blue: 0.33, alpha: 1)
        case .beforeWork, .rest: color = .lightGray
        }
        labels[brandID]?.stringValue = "▥  活着的意义"
        labels[brandID]?.textColor = snapshot.phase == .overtime ? color : .white
        labels[amountID]?.stringValue = EarningsPresentation(snapshot: snapshot, settings: settings).compactAmount
        labels[amountID]?.font = .systemFont(ofSize: settings.sensitiveMode ? 13 : 19, weight: .semibold)
        labels[amountID]?.textColor = color
        labels[timerID]?.stringValue = snapshot.timerCaption
        labels[timerID]?.textColor = snapshot.phase == .overtime ? color : .white
        if let label = labels[phaseID] {
            label.stringValue = snapshot.phase.title
            label.textColor = .black
            label.drawsBackground = true
            label.backgroundColor = color
            label.wantsLayer = true
            label.layer?.cornerRadius = 7
            label.layer?.masksToBounds = true
        }
    }

    /// Redacts or restores all native labels according to hidden; returns nothing.
    func setPrivacy(_ hidden: Bool) {
        privacyHidden = hidden
        if let latest { update(latest, settings: latestSettings) }
    }

    /// Materializes all public API items for a hardware-independent construction check; returns their count.
    func materializeItems() -> Int {
        touchBar.defaultItemIdentifiers.compactMap { touchBar.item(forIdentifier: $0) }.count
    }

    /// Returns current native amount, timer and phase strings for software verification; no parameters.
    func displayedValues() -> [String] {
        [amountID, timerID, phaseID].compactMap { labels[$0]?.stringValue }
    }
}
