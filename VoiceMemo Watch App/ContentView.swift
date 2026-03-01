import SwiftUI
import SwiftData
import AVFoundation

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.date, order: .reverse) private var recordings: [Recording]
    @Binding var shouldStartRecording: Bool
    @State private var playingRecordingID: UUID?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var navigateToRecording = false

    var body: some View {
        ZStack {
            WatchGlassTheme.background.ignoresSafeArea()

            Group {
                if recordings.isEmpty {
                    emptyState
                } else {
                    recordingsList
                }
            }
        }
        .navigationTitle("语音备忘")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    navigateToRecording = true
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(WatchGlassTheme.accent)
            }
        }
        .navigationDestination(isPresented: $navigateToRecording) {
            RecordingView(autoStart: true)
        }
        .onChange(of: shouldStartRecording) {
            if shouldStartRecording {
                shouldStartRecording = false
                navigateToRecording = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.largeTitle)
                .foregroundStyle(WatchGlassTheme.textSecondary)
            Text("暂无录音")
                .font(.headline)
                .foregroundStyle(WatchGlassTheme.textSecondary)
            Text("点击下方按钮开始录音")
                .font(.caption)
                .foregroundStyle(WatchGlassTheme.textMuted)
        }
    }

    private var recordingsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(recordings) { recording in
                    Button {
                        togglePlayback(recording)
                    } label: {
                        HStack {
                            RecordingRowView(recording: recording)

                            if playingRecordingID == recording.id {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(WatchGlassTheme.accent)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .watchGlassCard()
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func togglePlayback(_ recording: Recording) {
        if playingRecordingID == recording.id {
            audioPlayer?.stop()
            playingRecordingID = nil
            return
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent(recording.fileURL)

        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.play()
            playingRecordingID = recording.id
        } catch {
            print("Playback failed: \(error)")
        }
    }
}
