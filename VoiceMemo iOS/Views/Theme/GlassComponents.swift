import SwiftUI

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var radius: CGFloat = GlassTheme.cardRadius
    var tint: Color?
    var fill: Color = GlassTheme.surfaceLight
    var border: Color = GlassTheme.borderSubtle

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                content
                    .glassEffect(.regular.tint(tint), in: RoundedRectangle(cornerRadius: radius))
            } else {
                content
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
            }
        } else {
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
}

extension View {
    func glassCard(
        radius: CGFloat = GlassTheme.cardRadius,
        tint: Color? = nil
    ) -> some View {
        modifier(GlassCard(radius: radius, tint: tint))
    }
}

// MARK: - Glass Chip

struct GlassChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isActive ? .white : GlassTheme.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .tint(isActive ? GlassTheme.accent : nil)
        } else {
            Button(action: action) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isActive ? .white : GlassTheme.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(isActive ? GlassTheme.accent : GlassTheme.surfaceLight)
                            .overlay(
                                Capsule()
                                    .stroke(isActive ? .clear : GlassTheme.borderSubtle, lineWidth: 0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - App Tab

enum AppTab: Int, CaseIterable {
    case home = 0
    case history = 1
    case settings = 2

    var icon: String {
        switch self {
        case .home: return "mic.fill"
        case .history: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .home: return "录音"
        case .history: return "历史"
        case .settings: return "设置"
        }
    }
}

// MARK: - Pulsing Dot

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(GlassTheme.accent)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(GlassTheme.accent.opacity(0.5), lineWidth: 2)
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

struct RadialBackgroundView: View {
    var body: some View {
        ZStack {
            GlassTheme.background
            RadialGradient(
                colors: [
                    GlassTheme.accent.opacity(0.04),
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

// MARK: - Glass Button Style Modifier

struct GlassButtonModifier: ViewModifier {
    var prominent: Bool = false
    var circular: Bool = false
    var tintColor: Color? = nil

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if prominent && circular {
                if let tintColor {
                    content
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .tint(tintColor)
                } else {
                    content
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                }
            } else if prominent {
                if let tintColor {
                    content
                        .buttonStyle(.glassProminent)
                        .tint(tintColor)
                } else {
                    content
                        .buttonStyle(.glassProminent)
                }
            } else if circular {
                if let tintColor {
                    content
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .tint(tintColor)
                } else {
                    content
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                }
            } else {
                if let tintColor {
                    content
                        .buttonStyle(.glass)
                        .tint(tintColor)
                } else {
                    content
                        .buttonStyle(.glass)
                }
            }
        } else {
            content
                .buttonStyle(LegacyGlassButtonStyle(prominent: prominent, circular: circular, tintColor: tintColor))
        }
    }
}

private struct LegacyGlassButtonStyle: ButtonStyle {
    var prominent: Bool
    var circular: Bool
    var tintColor: Color?

    func makeBody(configuration: Configuration) -> some View {
        let shape = circular ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: GlassTheme.buttonRadius))
        let fillColor = tintColor ?? (prominent ? GlassTheme.accent : GlassTheme.surfaceLight)
        configuration.label
            .padding(.horizontal, circular ? 0 : 20)
            .padding(.vertical, circular ? 0 : 14)
            .background(
                shape
                    .fill(fillColor)
                    .overlay(
                        shape
                            .stroke(GlassTheme.borderSubtle, lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func glassButton(prominent: Bool = false, circular: Bool = false, tint: Color? = nil) -> some View {
        modifier(GlassButtonModifier(prominent: prominent, circular: circular, tintColor: tint))
    }
}

// MARK: - Glass Effect Modifier

struct GlassEffectModifier<S: Shape>: ViewModifier {
    var tint: Color?
    var shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                content
                    .glassEffect(.regular.tint(tint), in: shape)
            } else {
                content
                    .glassEffect(.regular, in: shape)
            }
        } else {
            content
                .background(
                    shape.fill(tint?.opacity(0.3) ?? GlassTheme.surfaceLight)
                )
                .overlay(
                    shape.stroke(GlassTheme.borderSubtle, lineWidth: 0.5)
                )
        }
    }
}

extension View {
    func adaptiveGlassEffect<S: Shape>(tint: Color? = nil, in shape: S) -> some View {
        modifier(GlassEffectModifier(tint: tint, shape: shape))
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    let title: String

    var body: some View {
        Text(LocalizedStringKey(title))
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(GlassTheme.textTertiary)
            .textCase(.none)
    }
}
