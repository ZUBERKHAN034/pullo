import SwiftUI

extension Color {
    static let unread = Color(red: 0.38, green: 0.64, blue: 1)

    static let textStrong = Color.white.opacity(0.85)
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.48)
    static let textMuted = Color.white.opacity(0.35)

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
