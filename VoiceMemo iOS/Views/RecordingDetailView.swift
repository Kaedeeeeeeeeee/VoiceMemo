import SwiftUI

struct RecordingDetailView: View {
    @Bindable var recording: Recording
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Player
            RecordingPlayerView(recording: recording)
                .padding()

            Divider()

            // Tabs
            Picker("", selection: $selectedTab) {
                Text("转写").tag(0)
                Text("摘要").tag(1)
                Text("对话").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

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
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
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
                }
            }
        }
    }

    private var audioFileURL: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDir.appendingPathComponent(recording.fileURL)
    }
}
