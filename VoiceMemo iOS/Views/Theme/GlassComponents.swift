import SwiftUI

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var radius: CGFloat = GlassTheme.cardRadius
    var fill: Color = GlassTheme.surfaceLight
    var border: Color = GlassTheme.borderSubtle

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
    func glassCard(
        radius: CGFloat = GlassTheme.cardRadius,
        fill: Color = GlassTheme.surfaceLight,
        border: Color = GlassTheme.borderSubtle
    ) -> some View {
        modifier(GlassCard(radius: radius, fill: fill, border: border))
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    var fill: Color = GlassTheme.surfaceLight

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: GlassTheme.buttonRadius)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: GlassTheme.buttonRadius)
                            .stroke(GlassTheme.borderSubtle, lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Glass Chip

struct GlassChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(isActive ? .black : GlassTheme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isActive ? .white : GlassTheme.surfaceLight)
                        .overlay(
                            Capsule()
                                .stroke(isActive ? .clear : GlassTheme.borderSubtle, lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Tab Bar

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

    var label: String {
        switch self {
        case .home: return "录音"
        case .history: return "历史"
        case .settings: return "设置"
        }
    }
}

struct GlassTabBar: View {
    @Binding var selectedTab: AppTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    ZStack {
                        if selectedTab == tab {
                            Capsule()
                                .fill(.white.opacity(0.18))
                                .matchedGeometryEffect(id: "tabPill", in: tabNamespace)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                            if selectedTab == tab {
                                Text(tab.label)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? .white : GlassTheme.textMuted)
                        .padding(.horizontal, selectedTab == tab ? 16 : 12)
                        .padding(.vertical, 10)
                    }
                    .frame(maxWidth: selectedTab == tab ? .infinity : nil)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.25), radius: 16, y: 4)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 40)
        .fixedSize(horizontal: false, vertical: true)
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
                    Color.white.opacity(0.03),
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

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(GlassTheme.textTertiary)
            .textCase(.none)
    }
}
