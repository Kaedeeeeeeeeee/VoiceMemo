import SwiftUI

struct SettingsView: View {
    var body: some View {
        ZStack {
            RadialBackgroundView()

            VStack(spacing: 24) {
                Spacer()

                // App info card
                VStack(spacing: 16) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(GlassTheme.accent)

                    Text("VoiceMemo")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(GlassTheme.textPrimary)

                    Text("AI 语音备忘录")
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textTertiary)

                    Divider()
                        .overlay(GlassTheme.borderSubtle)

                    HStack {
                        Text("版本")
                            .foregroundStyle(GlassTheme.textTertiary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .font(.subheadline)
                }
                .padding(24)
                .glassCard()
                .padding(.horizontal)

                Spacer()
                Spacer()
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
