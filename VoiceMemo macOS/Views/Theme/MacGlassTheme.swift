import SwiftUI

enum MacGlassTheme {
    // MARK: - Colors (same as iOS GlassTheme)
    static let background = Color(white: 0.06)
    static let surfaceLight = Color.white.opacity(0.08)
    static let surfaceMedium = Color.white.opacity(0.12)
    static let surfaceHeavy = Color.white.opacity(0.18)
    static let borderSubtle = Color.white.opacity(0.1)
    static let borderMedium = Color.white.opacity(0.15)
    static let accent = Color(red: 0.937, green: 0.267, blue: 0.267) // #ef4444

    // MARK: - Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)
    static let textMuted = Color.white.opacity(0.3)

    // MARK: - Radii (adjusted for macOS)
    static let cardRadius: CGFloat = 20
    static let buttonRadius: CGFloat = 12
    static let chipRadius: CGFloat = 16

    // MARK: - Helpers
    static func uppercaseLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2)
            .fontWeight(.semibold)
            .tracking(1.5)
            .foregroundStyle(textTertiary)
    }

    static func heroTimer(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 56, weight: .ultraLight, design: .monospaced))
            .foregroundStyle(textPrimary)
    }
}
