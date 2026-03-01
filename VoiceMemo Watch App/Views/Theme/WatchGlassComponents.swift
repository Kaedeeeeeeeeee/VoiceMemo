import SwiftUI

struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .glassEffect(.regular, in: .rect(cornerRadius: WatchGlassTheme.cardRadius))
    }
}

extension View {
    func watchGlassCard() -> some View {
        modifier(GlassCard())
    }
}

struct PulsingDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(WatchGlassTheme.accent)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(WatchGlassTheme.accent.opacity(0.5), lineWidth: 2)
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
