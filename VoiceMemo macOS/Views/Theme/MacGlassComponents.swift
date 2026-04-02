import SwiftUI

// MARK: - Glass Card Modifier

struct MacGlassCard: ViewModifier {
    var radius: CGFloat = MacGlassTheme.cardRadius
    var fill: Color = MacGlassTheme.surfaceLight
    var border: Color = MacGlassTheme.borderSubtle

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(border, lineWidth: 0.5)
                    )
            )
    }
}

extension View {
    func macGlassCard(
        radius: CGFloat = MacGlassTheme.cardRadius,
        fill: Color = MacGlassTheme.surfaceLight,
        border: Color = MacGlassTheme.borderSubtle
    ) -> some View {
        modifier(MacGlassCard(radius: radius, fill: fill, border: border))
    }
}

// MARK: - Glass Chip

struct MacGlassChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isActive ? .white : MacGlassTheme.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? MacGlassTheme.accent : MacGlassTheme.surfaceLight)
                        .overlay(
                            Capsule()
                                .stroke(isActive ? .clear : MacGlassTheme.borderSubtle, lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Button Style

struct MacGlassButtonStyle: ButtonStyle {
    var prominent: Bool = false
    var circular: Bool = false
    var tintColor: Color?

    func makeBody(configuration: Configuration) -> some View {
        let shape = circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: MacGlassTheme.buttonRadius))
        let fillColor = tintColor ?? (prominent ? MacGlassTheme.accent : MacGlassTheme.surfaceLight)
        configuration.label
            .padding(.horizontal, circular ? 0 : 16)
            .padding(.vertical, circular ? 0 : 10)
            .background(
                shape
                    .fill(fillColor)
                    .overlay(
                        shape
                            .stroke(MacGlassTheme.borderSubtle, lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func macGlassButton(prominent: Bool = false, circular: Bool = false, tint: Color? = nil) -> some View {
        buttonStyle(MacGlassButtonStyle(prominent: prominent, circular: circular, tintColor: tint))
    }
}

// MARK: - Glass Effect Modifier

struct MacGlassEffectModifier<S: Shape>: ViewModifier {
    var tint: Color?
    var shape: S

    func body(content: Content) -> some View {
        content
            .background(
                shape.fill(tint?.opacity(0.3) ?? MacGlassTheme.surfaceLight)
            )
            .overlay(
                shape.stroke(MacGlassTheme.borderSubtle, lineWidth: 0.5)
            )
    }
}

extension View {
    func macAdaptiveGlassEffect<S: Shape>(tint: Color? = nil, in shape: S) -> some View {
        modifier(MacGlassEffectModifier(tint: tint, shape: shape))
    }
}

// MARK: - Pulsing Dot

struct MacPulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(MacGlassTheme.accent)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(MacGlassTheme.accent.opacity(0.5), lineWidth: 2)
                    .scaleEffect(isPulsing ? 2.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Radial Background

struct MacRadialBackgroundView: View {
    var body: some View {
        ZStack {
            MacGlassTheme.background
            RadialGradient(
                colors: [
                    MacGlassTheme.accent.opacity(0.04),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Section Header

struct MacGlassSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(MacGlassTheme.textTertiary)
            .textCase(.none)
    }
}
