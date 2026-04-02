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
    @State private var recordingToDelete: Recording?

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
        .navigationTitle("PodNote")
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
        List {
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
            .onDelete { indexSet in
                if let index = indexSet.first {
                    recordingToDelete = recordings[index]
                }
            }
        }
        .listStyle(.carousel)
        .alert("确认删除", isPresented: Binding(
            get: { recordingToDelete != nil },
            set: { if !$0 { recordingToDelete = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let recording = recordingToDelete {
                    deleteRecording(recording)
                }
                recordingToDelete = nil
            }
            Button("取消", role: .cancel) {
                recordingToDelete = nil
            }
        } message: {
            Text("确定要删除这条录音吗？此操作不可撤销。")
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
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            playingRecordingID = recording.id
        } catch {
            print("Playback failed: \(error) for file: \(fileURL.path)")
        }
    }

    private func deleteRecording(_ recording: Recording) {
        // Stop playback if this recording is playing
        if playingRecordingID == recording.id {
            audioPlayer?.stop()
            playingRecordingID = nil
        }

        // Delete audio file
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent(recording.fileURL)
        try? FileManager.default.removeItem(at: fileURL)

        // Delete from SwiftData
        modelContext.delete(recording)
    }
}
