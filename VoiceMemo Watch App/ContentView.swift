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
        Group {
            if recordings.isEmpty {
                emptyState
            } else {
                recordingsList
            }
        }
        .navigationTitle("语音备忘")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    navigateToRecording = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 50, height: 50)
                        Image(systemName: "mic.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
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
                .foregroundStyle(.secondary)
            Text("暂无录音")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("点击下方按钮开始录音")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
                                .foregroundStyle(.blue)
                                .font(.caption)
                        }
                    }
                }
            }
            .onDelete(perform: deleteRecordings)
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

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]

            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsDir.appendingPathComponent(recording.fileURL)
            try? FileManager.default.removeItem(at: fileURL)

            modelContext.delete(recording)
        }
    }
}
