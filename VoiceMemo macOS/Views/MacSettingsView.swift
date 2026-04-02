import SwiftUI

struct MacSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showPaywall = false
    private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        ZStack {
            MacRadialBackgroundView()

            ScrollView {
                VStack(spacing: 14) {
                    // Subscription card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("订阅状态")
                                    .font(.subheadline)
                                    .foregroundStyle(MacGlassTheme.textTertiary)
                                Text(subscriptionManager.isSubscribed ? "PodNote Pro" : "免费版")
                                    .font(.headline)
                                    .foregroundStyle(MacGlassTheme.textPrimary)
                            }
                            Spacer()
                            if subscriptionManager.isSubscribed {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title2)
                                    .foregroundStyle(MacGlassTheme.accent)
                            }
                        }

                        if subscriptionManager.isSubscribed {
                            Button {
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                HStack {
                                    Text("管理订阅")
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundStyle(MacGlassTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                Text("升级到 Pro")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .macGlassButton(prominent: true)

                            Button {
                                Task { await subscriptionManager.restore() }
                            } label: {
                                Text("恢复购买")
                                    .font(.caption)
                                    .foregroundStyle(MacGlassTheme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .macGlassCard()
                    .padding(.horizontal)

                    // Language settings
                    VStack(spacing: 16) {
                        HStack {
                            Text("语言")
                                .foregroundStyle(MacGlassTheme.textPrimary)
                            Spacer()
                            Picker("语言", selection: $languageManager.selectedLanguage) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .tint(MacGlassTheme.accent)
                            .frame(width: 120)
                        }
                    }
                    .padding(20)
                    .macGlassCard()
                    .padding(.horizontal)

                    // App info card
                    VStack(spacing: 16) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(MacGlassTheme.accent)

                        Text("PodNote")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(MacGlassTheme.textPrimary)

                        Text("AI 语音备忘录")
                            .font(.subheadline)
                            .foregroundStyle(MacGlassTheme.textTertiary)

                        Divider()
                            .overlay(MacGlassTheme.borderSubtle)

                        HStack {
                            Text("版本")
                                .foregroundStyle(MacGlassTheme.textTertiary)
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(MacGlassTheme.textSecondary)
                        }
                        .font(.subheadline)

                        Divider()
                            .overlay(MacGlassTheme.borderSubtle)

                        Button {
                            if let url = URL(string: "https://podnote-api-proxy.podnote-api.workers.dev/privacy") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Text("隐私政策")
                                    .foregroundStyle(MacGlassTheme.textSecondary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(MacGlassTheme.textMuted)
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let url = URL(string: "https://podnote-api-proxy.podnote-api.workers.dev/terms") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Text("使用条款")
                                    .foregroundStyle(MacGlassTheme.textSecondary)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(MacGlassTheme.textMuted)
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .macGlassCard()
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showPaywall) {
            MacPaywallPlaceholder()
        }
    }
}
