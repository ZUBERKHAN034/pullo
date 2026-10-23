import AppKit
import SwiftUI

enum TextTone: CaseIterable {
    case strong, secondary, tertiary, muted

    func opacity(increasedContrast: Bool) -> Double {
        switch self {
        case .strong: increasedContrast ? 0.95 : 0.85
        case .secondary: increasedContrast ? 0.8 : 0.6
        case .tertiary: increasedContrast ? 0.72 : 0.48
        case .muted: increasedContrast ? 0.66 : 0.35
        }
    }

    var color: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor.white.withAlphaComponent(opacity(increasedContrast: Self.increasedContrast(in: appearance)))
        })
    }

    static func increasedContrast(in appearance: NSAppearance) -> Bool {
        let highContrast: [NSAppearance.Name] = [
            .accessibilityHighContrastDarkAqua, .accessibilityHighContrastAqua,
            .accessibilityHighContrastVibrantDark, .accessibilityHighContrastVibrantLight,
        ]
        return highContrast.contains(appearance.name) || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
}

extension Color {
    static let unread = Color(red: 0.38, green: 0.64, blue: 1)

    static let textStrong = TextTone.strong.color
    static let textSecondary = TextTone.secondary.color
    static let textTertiary = TextTone.tertiary.color
    static let textMuted = TextTone.muted.color

    static let surfaceSubtle = Color.white.opacity(0.08)
    static let surface = Color.white.opacity(0.1)
    static let surfaceStrong = Color.white.opacity(0.14)
    static let hairline = Color.white.opacity(0.1)
}

extension ShapeStyle where Self == Color {
    static var unread: Color { Color.unread }
    static var textStrong: Color { Color.textStrong }
    static var textSecondary: Color { Color.textSecondary }
    static var textTertiary: Color { Color.textTertiary }
    static var textMuted: Color { Color.textMuted }
    static var surfaceSubtle: Color { Color.surfaceSubtle }
    static var surface: Color { Color.surface }
    static var surfaceStrong: Color { Color.surfaceStrong }
    static var hairline: Color { Color.hairline }
}
