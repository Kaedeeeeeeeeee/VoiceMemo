import SwiftUI
import UniformTypeIdentifiers

struct MacRecordingDetailView: View {
    @Bindable var recording: Recording
    @State private var selectedTab = 0
    @State private var player = MacAudioPlayerManager()

    var body: some View {
        ZStack(alignment: .bottom) {
            MacRadialBackgroundView()

            VStack(spacing: 0) {
                // Tab selector
                macTabSelector
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Tab content
                Group {
                    switch selectedTab {
                    case 0: MacTranscriptView(recording: recording)
                    case 1: MacSummaryView(recording: recording)
                    case 2: MacAIConversationView(recording: recording)
                    default: MacTranscriptView(recording: recording)
                    }
                }
                .padding(.bottom, selectedTab == 2 ? 0 : 44)

                // Mini player (hidden on chat tab)
                if selectedTab != 2 {
                    macMiniPlayer
                }
            }
        }
        .background(MacGlassTheme.background)
        .navigationTitle(recording.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if let transcription = recording.transcription {
                        Button {
                            var text = recording.applyingSpeakerNames(to: transcription)
                            let markers = recording.markersSection(markdown: false)
                            if !markers.isEmpty { text += "\n\n" + markers }
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        } label: {
                            Label("复制转写文本", systemImage: "doc.on.doc")
                        }

                        Button {
                            let text = recording.applyingSpeakerNames(to: transcription)
                            exportPDF(title: recording.title, content: text, type: "转写", markers: recording.sortedMarkers)
                        } label: {
                            Label("导出转写 PDF", systemImage: "doc.richtext")
                        }
                    }

                    if let summary = recording.summary {
                        Divider()
                        Button {
                            var text = summary
                            let markers = recording.markersSection(markdown: false)
                            if !markers.isEmpty { text += "\n\n" + markers }
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        } label: {
                            Label("复制摘要文本", systemImage: "doc.on.doc")
                        }

                        Button {
                            exportPDF(title: recording.title, content: summary, type: "摘要", markers: recording.sortedMarkers)
                        } label: {
                            Label("导出摘要 PDF", systemImage: "doc.richtext")
                        }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(MacGlassTheme.textSecondary)
                }
            }
        }
        .task {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)
            await player.load(url: url)
        }
    }

    private var macTabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(["转写", "摘要", "对话"].enumerated()), id: \.offset) { index, title in
                Button {
                    selectedTab = index
                } label: {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(selectedTab == index ? .semibold : .regular)
                        .foregroundStyle(selectedTab == index ? MacGlassTheme.textPrimary : MacGlassTheme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == index ?
                                MacGlassTheme.surfaceMedium : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .macGlassCard(radius: 14)
    }

    private var macMiniPlayer: some View {
        HStack(spacing: 8) {
            Button {
                player.toggle()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(MacGlassTheme.textPrimary)
                    .frame(width: 24, height: 24)
            }
            .macGlassButton(circular: true)

            Slider(
                value: Binding(
                    get: { player.currentTime },
                    set: { newValue in
                        player.isSeeking = true
                        player.currentTime = newValue
                    }
                ),
                in: 0...max(player.duration, 0.01),
                onEditingChanged: { editing in
                    if !editing {
                        player.seek(to: player.currentTime)
                    } else {
                        player.isSeeking = true
                    }
                }
            )
            .tint(MacGlassTheme.accent)

            Text("\(formatTime(player.currentTime))/\(formatTime(player.duration))")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(MacGlassTheme.textSecondary)

            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0] as [Float], id: \.self) { rate in
                    Button {
                        player.setRate(rate)
                    } label: {
                        HStack {
                            Text("\(rate, specifier: "%.2g")x")
                            if player.playbackRate == rate {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text("\(player.playbackRate, specifier: "%.2g")x")
                    .font(.caption2)
                    .foregroundStyle(MacGlassTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .macGlassCard(radius: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .macGlassCard(radius: 16)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func exportPDF(title: String, content: String, type: String, markers: [RecordingMarker] = []) {
        guard let url = MacPDFRenderer.render(title: title, content: content, type: type, markers: markers) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(title)_\(type).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.begin { response in
            if response == .OK, let destURL = panel.url {
                try? FileManager.default.copyItem(at: url, to: destURL)
            }
        }
    }
}
