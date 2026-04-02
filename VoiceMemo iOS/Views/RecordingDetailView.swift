import SwiftUI

struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @State private var selectedTab = 0
    @State private var showFullPlayer = false
    @State private var isLoaded = false
    @State private var shareItems: [Any]?
    @State private var showPaywall = false
    @State private var reminderMessage: String?
    @State private var cloudSyncMessage: String?

    private var tabTitles: [String] {
        var tabs = ["转写", "摘要", "对话"]
        if !recording.markers.isEmpty {
            tabs.insert("标记", at: 2)
        }
        return tabs
    }

    private var conversationTabIndex: Int {
        recording.markers.isEmpty ? 2 : 3
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RadialBackgroundView()

            if !isLoaded {
                VStack {
                    Spacer()
                    ProgressView()
                        .tint(GlassTheme.accent)
                        .scaleEffect(1.2)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    // Glass tab selector
                    glassTabSelector
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Tab content (lazy — only builds the selected tab)
                    Group {
                        switch selectedTab {
                        case 0: TranscriptView(recording: recording)
                        case 1: SummaryView(recording: recording)
                        case 2 where !recording.markers.isEmpty:
                            MarkerListView(recording: recording)
                        case conversationTabIndex:
                            AIConversationView(recording: recording)
                        default: TranscriptView(recording: recording)
                        }
                    }
                    .padding(.bottom, selectedTab == conversationTabIndex ? 0 : 44)
                }

                // Mini player bar (hidden on conversation tab)
                if selectedTab != conversationTabIndex {
                    MiniPlayerBar(recording: recording, showFullPlayer: $showFullPlayer)
                }
            }
        }
        .background(GlassTheme.background)
        .task {
            await Task.yield()
            isLoaded = true
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: audioFileURL) {
                        Label("分享音频", systemImage: "waveform")
                    }

                    if let transcription = recording.transcription {
                        Divider()
                        ShareLink(item: recording.applyingSpeakerNames(to: transcription)) {
                            Label("分享转写文本", systemImage: "doc.text")
                        }
                        Button {
                            guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                showPaywall = true
                                return
                            }
                            let text = recording.applyingSpeakerNames(to: transcription)
                            if let url = PDFRenderer.render(title: recording.title, content: text, type: "转写") {
                                shareItems = [url]
                            }
                        } label: {
                            Label("分享转写 PDF", systemImage: "doc.richtext")
                        }
                    }

                    if let summary = recording.summary {
                        Divider()
                        ShareLink(item: summary) {
                            Label("分享摘要文本", systemImage: "text.quote")
                        }
                        Button {
                            guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                showPaywall = true
                                return
                            }
                            if let url = PDFRenderer.render(title: recording.title, content: summary, type: "摘要") {
                                shareItems = [url]
                            }
                        } label: {
                            Label("分享摘要 PDF", systemImage: "doc.richtext")
                        }
                    }

                    // Export formats
                    if recording.transcription != nil || recording.summary != nil {
                        Divider()
                        Menu {
                            Button {
                                if let url = ExportService.exportMarkdown(recording: recording, contentType: exportContentType) {
                                    shareItems = [url]
                                }
                            } label: {
                                Label("Markdown", systemImage: "text.document")
                            }

                            Button {
                                if let url = ExportService.exportPlainText(recording: recording, contentType: exportContentType) {
                                    shareItems = [url]
                                }
                            } label: {
                                Label("纯文本", systemImage: "doc.plaintext")
                            }

                            Button {
                                guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                    showPaywall = true
                                    return
                                }
                                if let url = ExportService.exportWord(recording: recording, contentType: exportContentType) {
                                    shareItems = [url]
                                }
                            } label: {
                                Label("Word 文档", systemImage: "doc.fill")
                            }

                            Button {
                                guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                    showPaywall = true
                                    return
                                }
                                if let url = ExportService.exportZIPPackage(recording: recording) {
                                    shareItems = [url]
                                }
                            } label: {
                                Label("完整包 (ZIP)", systemImage: "archivebox")
                            }
                        } label: {
                            Label("导出格式", systemImage: "square.and.arrow.up.on.square")
                        }
                    }

                    // Send to apps
                    if recording.transcription != nil || recording.summary != nil {
                        Divider()
                        Menu {
                            ForEach(IntegrationApp.allCases, id: \.self) { app in
                                if IntegrationService.isAvailable(app) {
                                    Button {
                                        sendToApp(app)
                                    } label: {
                                        Label(app.displayName, systemImage: app.iconName)
                                    }
                                }
                            }

                            Button {
                                let content = exportText
                                IntegrationService.createReminder(title: recording.title, notes: content) { success, _ in
                                    reminderMessage = success ? "提醒事项已创建" : "创建提醒事项失败"
                                }
                            } label: {
                                Label("创建提醒事项", systemImage: "bell")
                            }

                            if NotionService.shared.isConnected {
                                Button {
                                    guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                        showPaywall = true
                                        return
                                    }
                                    Task {
                                        let success = await NotionService.shared.createPage(title: recording.title, content: exportText)
                                        cloudSyncMessage = success ? "已发送到 Notion" : "发送到 Notion 失败"
                                    }
                                } label: {
                                    Label("发送到 Notion", systemImage: "doc.text.fill")
                                }
                            }

                            if GoogleDocsService.shared.isConnected {
                                Button {
                                    guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                        showPaywall = true
                                        return
                                    }
                                    Task {
                                        let success = await GoogleDocsService.shared.createDocument(title: recording.title, content: exportText)
                                        cloudSyncMessage = success ? "已发送到 Google Docs" : "发送到 Google Docs 失败"
                                    }
                                } label: {
                                    Label("发送到 Google Docs", systemImage: "doc.richtext.fill")
                                }
                            }
                        } label: {
                            Label("发送到应用", systemImage: "arrow.up.forward.app")
                        }
                    }

                    // Share card
                    if recording.summary != nil {
                        Divider()
                        Button {
                            guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                showPaywall = true
                                return
                            }
                            if let image = ShareCardRenderer.render(recording: recording) {
                                shareItems = [image]
                            }
                        } label: {
                            Label("分享摘要卡片", systemImage: "photo")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(GlassTheme.textSecondary)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ActivitySheet(items: items)
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("提醒事项", isPresented: Binding(
            get: { reminderMessage != nil },
            set: { if !$0 { reminderMessage = nil } }
        )) {
            Button("好的") { }
        } message: {
            if let msg = reminderMessage {
                Text(msg)
            }
        }
        .alert("同步状态", isPresented: Binding(
            get: { cloudSyncMessage != nil },
            set: { if !$0 { cloudSyncMessage = nil } }
        )) {
            Button("好的") { }
        } message: {
            if let msg = cloudSyncMessage {
                Text(msg)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerSheet(recording: recording)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
        }
    }

    private var glassTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabTitles.enumerated()), id: \.offset) { index, title in
                Button {
                    selectedTab = index
                } label: {
                    Text(LocalizedStringKey(title))
                        .font(.subheadline)
                        .fontWeight(selectedTab == index ? .semibold : .regular)
                        .foregroundStyle(selectedTab == index ? GlassTheme.textPrimary : GlassTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == index ?
                                GlassTheme.surfaceMedium : Color.clear,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassCard(radius: 16)
    }

    private var audioFileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent(recording.fileURL)
    }

    private var exportContentType: ExportContentType {
        if recording.transcription != nil && recording.summary != nil {
            return .both
        } else if recording.summary != nil {
            return .summary
        } else {
            return .transcription
        }
    }

    private var exportText: String {
        if let summary = recording.summary {
            return summary
        } else if let transcription = recording.transcription {
            return recording.applyingSpeakerNames(to: transcription)
        }
        return ""
    }

    private func sendToApp(_ app: IntegrationApp) {
        let content = exportText
        switch app {
        case .bear:
            IntegrationService.openInBear(title: recording.title, text: content)
        case .obsidian:
            IntegrationService.openInObsidian(title: recording.title, text: content)
        case .things:
            IntegrationService.openInThings(title: recording.title, notes: content)
        case .omniFocus:
            IntegrationService.openInOmniFocus(title: recording.title, notes: content)
        }
    }
}
