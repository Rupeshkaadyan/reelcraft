import SwiftUI
import UIKit

/// Reelcraft design tokens. Every colour and size in the app comes from here.
enum Theme {
    // MARK: Colour roles
    static let bg = Color(hex: 0x0A0A0C)
    static let surface = Color(hex: 0x141419)
    static let surfaceRaised = Color(hex: 0x1D1D24)
    static let surfaceStroke = Color(hex: 0x2A2A33)
    /// 3.3:1 on the app background: passes WCAG AA for input affordances.
    static let inputStroke = Color(hex: 0x63636F)
    static let ink = Color(hex: 0xF7F7F5)
    static let inkSecondary = Color(hex: 0x9A9AA5)
    static let inkTertiary = Color(hex: 0x6B6B76)
    static let ember = Color(hex: 0xFF5C38)
    static let mint = Color(hex: 0x7CFFB2)
    static let amber = Color(hex: 0xFFC93C)
    static let danger = Color(hex: 0xFF5D5D)

    // MARK: Type scale
    static func display(_ size: CGFloat = 30) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func title(_ size: CGFloat = 22) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .regular, design: .default) }
    static func label(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .default) }
    static func mono(_ size: CGFloat = 12) -> Font { .system(size: size, weight: .medium, design: .monospaced) }

    // MARK: Metrics
    static let radiusS: CGFloat = 10
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 24
    static let gutter: CGFloat = 16
    static let hairline: CGFloat = 1

    // MARK: Gradients
    static var emberGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFF7A4D), ember], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var canvasGradient: LinearGradient {
        LinearGradient(colors: [Color(hex: 0x1A1A22), Color(hex: 0x08080B)], startPoint: .top, endPoint: .bottom)
    }
    static var cardGradient: LinearGradient {
        LinearGradient(colors: [surfaceRaised, surface], startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Primitives

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 15, weight: .bold)) }
                Text(title).font(Theme.label(15))
            }
            .foregroundStyle(Theme.bg)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.emberGradient, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(Theme.label(14))
            }
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: Theme.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}

struct GhostButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(Theme.label(13))
            }
            .foregroundStyle(Theme.inkSecondary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: Theme.hairline))
        }
        .buttonStyle(.plain)
    }
}

struct Chip: View {
    let title: String
    var selected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.label(12))
                .foregroundStyle(selected ? Theme.bg : Theme.inkSecondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(selected ? AnyShapeStyle(Theme.ember) : AnyShapeStyle(Theme.surfaceRaised), in: Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : Theme.surfaceStroke, lineWidth: Theme.hairline))
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.title(19)).foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle).font(Theme.body(12)).foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.surfaceRaised).frame(width: 76, height: 76)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Theme.ember)
            }
            Text(title).font(Theme.title(18)).foregroundStyle(Theme.ink)
            Text(message)
                .font(Theme.body(13))
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                GhostButton(title: actionTitle, systemImage: "plus", action: action)
                    .padding(.top, 2)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

struct ScreenBackground: View {
    var body: some View {
        Theme.bg.ignoresSafeArea()
    }
}

extension View {
    func cardSurface(radius: CGFloat = Theme.radiusM) -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: Theme.hairline)
            )
    }
}

// MARK: - Formatting

enum Format {
    static func timecode(_ seconds: Double, showMillis: Bool = true) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let m = total / 60
        let s = total % 60
        if showMillis {
            let cs = Int(((seconds - Double(total)) * 100).rounded())
            return String(format: "%d:%02d.%02d", m, s, cs)
        }
        return String(format: "%d:%02d", m, s)
    }

    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        return timecode(seconds, showMillis: false)
    }

    static func minutes(_ seconds: Double) -> String {
        String(format: "%.1f", seconds / 60)
    }
}
