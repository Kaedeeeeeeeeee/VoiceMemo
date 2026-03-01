import SwiftUI

struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @State private var selectedTab = 0
    @State private var showFullPlayer = false
    @State private var isLoaded = false
    @State private var pdfShareItems: [Any]?

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
                        case 2: AIConversationView(recording: recording)
                        default: TranscriptView(recording: recording)
                        }
                    }
                    .padding(.bottom, selectedTab == 2 ? 0 : 44)
                }

                // Mini player bar (hidden on conversation tab)
                if selectedTab != 2 {
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
                            let text = recording.applyingSpeakerNames(to: transcription)
                            if let url = PDFRenderer.render(title: recording.title, content: text, type: "转写") {
                                pdfShareItems = [url]
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
                            if let url = PDFRenderer.render(title: recording.title, content: summary, type: "摘要") {
                                pdfShareItems = [url]
                            }
                        } label: {
                            Label("分享摘要 PDF", systemImage: "doc.richtext")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(GlassTheme.textSecondary)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { pdfShareItems != nil },
            set: { if !$0 { pdfShareItems = nil } }
        )) {
            if let items = pdfShareItems {
                ActivitySheet(items: items)
                    .presentationDetents([.medium, .large])
            }
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
            ForEach(Array(["转写", "摘要", "对话"].enumerated()), id: \.offset) { index, title in
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
}
