import SwiftUI

struct SettingsView: View {
    @Environment(LanguageManager.self) var languageManager

    var body: some View {
        ZStack {
            RadialBackgroundView()

            VStack(spacing: 24) {
                Spacer()

                // Settings card
                VStack(spacing: 16) {
                    HStack {
                        Text("语言")
                            .foregroundStyle(GlassTheme.textPrimary)
                        Spacer()
                        Picker("语言", selection: Bindable(languageManager).selectedLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .tint(GlassTheme.accent)
                    }
                }
                .padding(24)
                .glassCard()
                .padding(.horizontal)

                // App info card
                VStack(spacing: 16) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(GlassTheme.accent)

                    Text("PodNote")
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
