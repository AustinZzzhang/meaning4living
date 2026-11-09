import AppKit
import LivingCore

struct MenuBarArtwork {
    let image: NSImage
    let text: String
    let usesTwoLines: Bool

    /// Draws a bounded full-color status image for snapshot/settings and maximumWidth; returns its image and text.
    static func make(
        snapshot: EarningsSnapshot,
        settings: WorkSettings,
        maximumWidth: CGFloat
    ) -> MenuBarArtwork {
        let display = EarningsPresentation(snapshot: snapshot, settings: settings)
        let limit = max(48, maximumWidth)
        let oneLineFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let fullText = display.menuText
        let fullSize = (fullText as NSString).size(withAttributes: [.font: oneLineFont])
        let twoLines = !settings.compactMenuBar && snapshot.phase != .rest && snapshot.phase != .checkedOut
            && fullSize.width + 17 > limit
        let font = twoLines ? NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold) : oneLineFont
        let prefix = snapshot.phase == .awaitingCheckIn ? "白嫖 " : ""
        let first = twoLines ? prefix + display.compactAmount : fullText
        let second = twoLines ? snapshot.timerText : ""
        let available = limit - 17
        let firstLine = fittedText(first, font: font, width: available)
        let secondLine = fittedText(second, font: font, width: available)
        let longest = max(
            (firstLine as NSString).size(withAttributes: [.font: font]).width,
            (secondLine as NSString).size(withAttributes: [.font: font]).width
        )
        let size = NSSize(width: min(limit, ceil(longest) + 17), height: 22)
        let color: NSColor
        switch snapshot.phase {
        case .working, .checkedOut: color = NSColor(srgbRed: 0.03, green: 0.70, blue: 0.35, alpha: 1)
        case .awaitingCheckIn: color = .systemPurple
        case .overtime: color = NSColor(srgbRed: 0.97, green: 0.24, blue: 0.28, alpha: 1)
        case .beforeWork, .rest: color = .secondaryLabelColor
        }
        let image = NSImage(size: size, flipped: false) { _ in
            color.setFill()
            for index in 0..<3 {
                NSBezierPath(
                    roundedRect: NSRect(x: CGFloat(index * 4), y: 5, width: 3, height: CGFloat(5 + index * 3)),
                    xRadius: 1,
                    yRadius: 1
                ).fill()
            }
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            if twoLines {
                (firstLine as NSString).draw(at: NSPoint(x: 16, y: 10), withAttributes: attributes)
                (secondLine as NSString).draw(at: NSPoint(x: 16, y: 0), withAttributes: attributes)
            } else {
                let height = (firstLine as NSString).size(withAttributes: attributes).height
                (firstLine as NSString).draw(at: NSPoint(x: 16, y: (22 - height) / 2), withAttributes: attributes)
            }
            return true
        }
        image.isTemplate = false
        image.accessibilityDescription = "活着的意义，\(display.accessibilityLabel)"
        return MenuBarArtwork(image: image, text: fullText, usesTwoLines: twoLines)
    }

    /// Truncates text by whole characters to fit font and width; returns bounded text with an ellipsis if needed.
    private static func fittedText(_ text: String, font: NSFont, width: CGFloat) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        if (text as NSString).size(withAttributes: attributes).width <= width { return text }
        var result = text
        while !result.isEmpty {
            result.removeLast()
            let candidate = result + "…"
            if (candidate as NSString).size(withAttributes: attributes).width <= width { return candidate }
        }
        return "…"
    }

    /// Chooses a width budget from screen width and top safe inset; returns a compact budget on narrow/notched screens.
    static func widthLimit(screenWidth: CGFloat, topInset: CGFloat) -> CGFloat {
        topInset > 0 || screenWidth <= 1512 ? 112 : 180
    }
}
