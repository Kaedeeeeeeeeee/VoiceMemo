import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = WatchAudioRecorder()
    @State private var connectivity = WatchConnectivityService()
    @State private var recordingURL: URL?
    var autoStart = false

    var body: some View {
        VStack(spacing: 12) {
            // Timer display
            Text(formattedTime)
                .font(.system(size: 40, weight: .light, design: .monospaced))
                .foregroundStyle(recorder.isRecording ? .red : .primary)

            // Audio level indicator
            AudioLevelView(power: recorder.averagePower, isRecording: recorder.isRecording)
                .frame(height: 30)

            Spacer()

            // Controls
            HStack(spacing: 20) {
                if recorder.isRecording {
                    // Pause/Resume button
                    Button {
                        if recorder.isPaused {
                            recorder.resumeRecording()
                        } else {
                            recorder.pauseRecording()
                        }
                    } label: {
                        Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)

                    // Stop button
                    Button {
                        stopAndSave()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    // Record button
                    ZStack {
                        Circle()
                            .fill(.red)
                        Image(systemName: "mic.fill")
                            .font(.title)
                            .foregroundStyle(.black)
                    }
                    .frame(width: 60, height: 60)
                    .contentShape(Circle())
                    .onTapGesture {
                        recordingURL = recorder.startRecording()
                    }
                    .accessibilityElement()
                    .accessibilityLabel("开始录音")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .padding()
        .navigationTitle("录音")
        .onAppear {
            if autoStart && !recorder.isRecording {
                recordingURL = recorder.startRecording()
            }
        }
    }

    private var formattedTime: String {
        let total = Int(recorder.currentTime)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func stopAndSave() {
        guard let result = recorder.stopRecording() else { return }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: result.url.path)[.size] as? Int64) ?? 0

        let recording = Recording(
            title: Date.now.recordingTitle,
            duration: result.duration,
            fileURL: result.url.lastPathComponent,
            fileSize: fileSize,
            source: .watch
        )
        modelContext.insert(recording)

        // Send to iPhone
        let metadata: [String: Any] = [
            "id": recording.id.uuidString,
            "title": recording.title,
            "duration": recording.duration,
            "date": recording.date.timeIntervalSince1970,
            "fileSize": fileSize
        ]
        connectivity.sendRecording(url: result.url, metadata: metadata)
    }
}

struct AudioLevelView: View {
    let power: Float
    let isRecording: Bool

    private let barCount = 30
    @State private var amplitudeHistory: [CGFloat] = Array(repeating: 0, count: 30)
    @State private var phaseOffsets: [CGFloat] = (0..<30).map { _ in CGFloat.random(in: 0...0.3) }

    private var normalizedPower: CGFloat {
        guard isRecording else { return 0 }
        let minDb: Float = -50
        let clampedPower = max(power, minDb)
        let linear = CGFloat((clampedPower - minDb) / (0 - minDb))
        return pow(linear, 2.0)
    }

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<barCount, id: \.self) { index in
                let amplitude = amplitudeHistory[index]
                let jittered = amplitude + phaseOffsets[index] * amplitude
                let baseHeight: CGFloat = 1.5
                let maxHeight: CGFloat = 30
                let height = baseHeight + min(jittered, 1.0) * (maxHeight - baseHeight)
                Capsule()
                    .fill(Color.primary)
                    .frame(width: 2, height: height)
            }
        }
        .animation(.easeOut(duration: 0.1), value: amplitudeHistory)
        .onChange(of: normalizedPower) {
            amplitudeHistory.removeFirst()
            amplitudeHistory.append(normalizedPower)
        }
    }
}
