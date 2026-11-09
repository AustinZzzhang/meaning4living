import SwiftUI
import LivingCore

enum Palette {
    static let background = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let ink = Color(red: 0.13, green: 0.16, blue: 0.17)
    static let muted = Color(red: 0.48, green: 0.52, blue: 0.54)
    static let green = Color(red: 0.06, green: 0.63, blue: 0.34)
    static let red = Color(red: 0.93, green: 0.27, blue: 0.29)
    static let line = Color.black.opacity(0.055)

    /// Selects the semantic color for a work phase; returns green, red or gray.
    static func color(for phase: WorkPhase) -> Color {
        switch phase {
        case .working: return green
        case .overtime: return red
        case .awaitingCheckIn: return Color.purple
        case .checkedOut: return green
        case .beforeWork, .rest: return muted
        }
    }
}

struct Surface<Content: View>: View {
    let content: Content

    /// Wraps builder content in a white rounded card; returns a surface view.
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.line, lineWidth: 1))
    }
}

struct StatusPill: View {
    let phase: WorkPhase

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Palette.color(for: phase)).frame(width: 7, height: 7)
            Text(phase.title).font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Palette.color(for: phase))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.color(for: phase).opacity(0.09), in: Capsule())
    }
}

struct SectionHeading: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 25, weight: .bold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Palette.muted)
        }
    }
}

enum DateText {
    /// Formats a date with Chinese calendar labels using a format pattern; returns readable text.
    static func string(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

struct ActionButtonStyle: ButtonStyle {
    var color: Color = Palette.green

    /// Styles a button using its pressed state; returns the rendered label and background.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .foregroundStyle(.white)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 10))
    }
}
