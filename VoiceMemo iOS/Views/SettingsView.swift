import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showPaywall = false
    private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        ZStack {
            RadialBackgroundView()

            ScrollView {
            VStack(spacing: 14) {
                // Subscription card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("订阅状态")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textTertiary)
                            Text(subscriptionManager.isSubscribed ? "PodNote Pro" : "免费版")
                                .font(.headline)
                                .foregroundStyle(GlassTheme.textPrimary)
                        }
                        Spacer()
                        if subscriptionManager.isSubscribed {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundStyle(GlassTheme.accent)
                        }
                    }

                    if subscriptionManager.isSubscribed {
                        Button {
                            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Text("管理订阅")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                            }
                            .foregroundStyle(GlassTheme.textSecondary)
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Text("升级到 Pro")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .glassButton(prominent: true)

                        Button {
                            Task { await subscriptionManager.restore() }
                        } label: {
                            Text("恢复购买")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                    }
                }
                .padding(24)
                .glassCard()
                .padding(.horizontal)

                // Settings card
                VStack(spacing: 16) {
                    HStack {
                        Text("语言")
                            .foregroundStyle(GlassTheme.textPrimary)
                        Spacer()
                        Picker("语言", selection: $languageManager.selectedLanguage) {
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

                    Divider()
                        .overlay(GlassTheme.borderSubtle)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            Text("隐私政策")
                                .foregroundStyle(GlassTheme.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.textMuted)
                        }
                        .font(.subheadline)
                    }

                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        HStack {
                            Text("使用条款")
                                .foregroundStyle(GlassTheme.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.textMuted)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(24)
                .glassCard()
                .padding(.horizontal)

            }
            .padding(.top, 8)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}
