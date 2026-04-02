import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.date, order: .reverse) private var allRecordings: [Recording]
    @State private var showPaywall = false
    @State private var isRebuildingIndex = false
    @State private var rebuildProgress = ""
    @AppStorage("autoRecordCalls") private var autoRecordCalls = false
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

                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.accent)
                            let used = TrialManager.shared.monthlyAIUsageCount
                            Text(String(localized: "本月免费 AI: \(used)/3 次已用"))
                                .font(.caption)
                                .foregroundStyle(GlassTheme.textTertiary)
                        }

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

                    Divider()
                        .overlay(GlassTheme.borderSubtle)

                    HStack {
                        Text("转写语言")
                            .foregroundStyle(GlassTheme.textPrimary)
                        Spacer()
                        Picker("转写语言", selection: $languageManager.transcriptionLanguage) {
                            ForEach(TranscriptionLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .tint(GlassTheme.accent)
                    }
                }
                .padding(24)
                .glassCard()
                .padding(.horizontal)

                // Third-party integrations card
                VStack(spacing: 16) {
                    NavigationLink {
                        IntegrationSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.title3)
                                .foregroundStyle(GlassTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("第三方集成")
                                    .foregroundStyle(GlassTheme.textPrimary)
                                Text("Notion · Google Docs")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.textTertiary)
                            }
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

                // Voiceprint management card
                VStack(spacing: 16) {
                    NavigationLink {
                        SpeakerProfilesView()
                    } label: {
                        HStack {
                            Image(systemName: "waveform.badge.person.crop")
                                .font(.title3)
                                .foregroundStyle(GlassTheme.accent)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("声纹管理")
                                    .foregroundStyle(GlassTheme.textPrimary)
                                Text("管理已保存的说话人声纹")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.textTertiary)
                            }
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

                // Call recording card
                VStack(spacing: 12) {
                    Toggle(isOn: $autoRecordCalls) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("通话自动录音")
                                .foregroundStyle(GlassTheme.textPrimary)
                            Text("接听电话时自动通过 Apple Watch 录音")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                    }
                    .tint(GlassTheme.accent)

                    if autoRecordCalls {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                                .font(.subheadline)
                            Text("请确保在录音前告知对方，部分地区法律要求双方同意")
                                .font(.caption)
                                .foregroundStyle(.yellow.opacity(0.9))
                        }
                        .padding(12)
                        .background(.yellow.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(24)
                .glassCard()
                .padding(.horizontal)

                // Knowledge base index card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass.circle")
                            .font(.title3)
                            .foregroundStyle(GlassTheme.accent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("知识库索引")
                                .foregroundStyle(GlassTheme.textPrimary)
                            Text("为已转写录音生成语义搜索索引")
                                .font(.caption)
                                .foregroundStyle(GlassTheme.textTertiary)
                        }
                        Spacer()
                    }
                    .font(.subheadline)

                    Button {
                        rebuildEmbeddingIndex()
                    } label: {
                        HStack {
                            if isRebuildingIndex {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                                Text(rebuildProgress)
                            } else {
                                Text("重建知识库索引")
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .glassButton(prominent: true)
                    .disabled(isRebuildingIndex)
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

    private func rebuildEmbeddingIndex() {
        let embeddingService = EmbeddingService.shared
        let transcribed = allRecordings.filter {
            $0.transcription != nil && !($0.transcription?.isEmpty ?? true)
                && !embeddingService.hasEmbeddings(for: $0.id, context: modelContext)
        }

        guard !transcribed.isEmpty else {
            rebuildProgress = "所有录音已有索引"
            isRebuildingIndex = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                isRebuildingIndex = false
                rebuildProgress = ""
            }
            return
        }

        isRebuildingIndex = true
        Task {
            for (index, recording) in transcribed.enumerated() {
                rebuildProgress = "\(index + 1)/\(transcribed.count)"
                do {
                    try await embeddingService.generateEmbeddings(for: recording, context: modelContext)
                } catch {
                    #if DEBUG
                    print("Failed to generate embeddings for \(recording.title): \(error)")
                    #endif
                }
            }
            isRebuildingIndex = false
            rebuildProgress = ""
        }
    }
}
