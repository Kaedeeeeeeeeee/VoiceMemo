import SwiftUI
import SwiftData

struct RecordingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recording.date, order: .reverse) private var recordings: [Recording]
    @State private var showRecordingSheet = false
    @State private var recorder = iOSAudioRecorder()
    @State private var recordingToRename: Recording?
    @State private var renameText = ""
    @State private var recordingToDelete: Recording?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if recordings.isEmpty {
                        emptyState
                    } else {
                        recordingsList
                    }
                }

                // Floating record button
                Button {
                    showRecordingSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 64, height: 64)
                            .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                        Image(systemName: "mic.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("语音备忘")
            .sheet(isPresented: $showRecordingSheet) {
                iOSRecordingSheet(recorder: recorder) { url, duration in
                    saveRecording(url: url, duration: duration)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("暂无录音", systemImage: "mic.slash")
        } description: {
            Text("点击下方按钮开始录音，或从 Apple Watch 同步录音")
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(recordings) { recording in
                NavigationLink(destination: RecordingDetailView(recording: recording)) {
                    RecordingListRow(recording: recording)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        recordingToDelete = recording
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        renameText = recording.title
                        recordingToRename = recording
                    } label: {
                        Label("重命名", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .alert("确认删除", isPresented: .init(
            get: { recordingToDelete != nil },
            set: { if !$0 { recordingToDelete = nil } }
        )) {
            Button("取消", role: .cancel) { recordingToDelete = nil }
            Button("删除", role: .destructive) {
                if let recording = recordingToDelete {
                    deleteRecording(recording)
                }
                recordingToDelete = nil
            }
        } message: {
            Text("删除后无法恢复，确定要删除这条录音吗？")
        }
        .alert("重命名录音", isPresented: .init(
            get: { recordingToRename != nil },
            set: { if !$0 { recordingToRename = nil } }
        )) {
            TextField("录音名称", text: $renameText)
            Button("取消", role: .cancel) { recordingToRename = nil }
            Button("确定") {
                if let recording = recordingToRename, !renameText.isEmpty {
                    recording.title = renameText
                }
                recordingToRename = nil
            }
        }
    }

    private func saveRecording(url: URL, duration: TimeInterval) {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        let recording = Recording(
            title: Date.now.recordingTitle,
            duration: duration,
            fileURL: url.lastPathComponent,
            fileSize: fileSize,
            source: .phone
        )
        modelContext.insert(recording)
    }

    private func deleteRecording(_ recording: Recording) {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDir.appendingPathComponent(recording.fileURL)
        try? FileManager.default.removeItem(at: fileURL)
        modelContext.delete(recording)
    }
}

struct RecordingListRow: View {
    let recording: Recording

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recording.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(recording.formattedDuration, systemImage: "waveform")
                    if recording.source == .watch {
                        Label("Watch", systemImage: "applewatch")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(recording.date.shortDisplay)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
        .padding(.vertical, 4)
    }
}

struct iOSRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recorder: iOSAudioRecorder
    let onSave: (URL, TimeInterval) -> Void

    private let barCount = 40
    @State private var amplitudeHistory: [CGFloat] = Array(repeating: 0, count: 40)
    @State private var phaseOffsets: [CGFloat] = (0..<40).map { _ in CGFloat.random(in: 0...0.3) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text(formattedTime)
                    .font(.system(size: 56, weight: .thin, design: .monospaced))
                    .foregroundStyle(recorder.isRecording ? .red : .primary)

                // Waveform audio level
                HStack(spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { index in
                        let amplitude = amplitudeHistory[index]
                        let jittered = amplitude + phaseOffsets[index] * amplitude
                        let baseHeight: CGFloat = 2
                        let maxHeight: CGFloat = 60
                        let height = baseHeight + min(jittered, 1.0) * (maxHeight - baseHeight)
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: 3, height: height)
                    }
                }
                .frame(height: 60)
                .animation(.easeOut(duration: 0.1), value: amplitudeHistory)

                Spacer()

                // Controls
                HStack(spacing: 32) {
                    Button {
                        if recorder.isPaused {
                            recorder.resumeRecording()
                        } else {
                            recorder.pauseRecording()
                        }
                    } label: {
                        Image(systemName: recorder.isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.yellow)
                    }

                    Button {
                        if let result = recorder.stopRecording() {
                            onSave(result.url, result.duration)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.red)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("录音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        _ = recorder.stopRecording()
                        dismiss()
                    }
                }
            }
            .onAppear {
                _ = recorder.startRecording()
            }
            .onChange(of: normalizedPower) {
                // Shift history left and append new sample, creating a scrolling waveform
                amplitudeHistory.removeFirst()
                amplitudeHistory.append(normalizedPower)
            }
        }
    }

    private var formattedTime: String {
        let total = Int(recorder.currentTime)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var normalizedPower: CGFloat {
        guard recorder.isRecording, !recorder.isPaused else { return 0 }
        let minDb: Float = -50
        let clampedPower = max(recorder.averagePower, minDb)
        let linear = CGFloat((clampedPower - minDb) / (0 - minDb))
        return pow(linear, 2.0)
    }

}
