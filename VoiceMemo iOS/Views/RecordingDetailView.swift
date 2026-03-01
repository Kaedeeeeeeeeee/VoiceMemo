import SwiftUI

struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @State private var selectedTab = 0
    @State private var showFullPlayer = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RadialBackgroundView()

            VStack(spacing: 0) {
                // Glass tab selector
                glassTabSelector
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Tab content
                TabView(selection: $selectedTab) {
                    TranscriptView(recording: recording)
                        .tag(0)
                    SummaryView(recording: recording)
                        .tag(1)
                    AIConversationView(recording: recording)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.bottom, 72)
            }

            // Mini player bar
            MiniPlayerBar(recording: recording, showFullPlayer: $showFullPlayer)
        }
        .background(GlassTheme.background)
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
                        ShareLink(item: transcription) {
                            Label("分享转写文本", systemImage: "doc.text")
                        }
                    }
                    if let summary = recording.summary {
                        ShareLink(item: summary) {
                            Label("分享摘要", systemImage: "text.quote")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(GlassTheme.textSecondary)
                }
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
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
