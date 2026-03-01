import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = WatchAudioRecorder()
    @State private var recordingURL: URL?
    @State private var amplitudeHistory: [CGFloat] = Array(repeating: 0, count: 20)
    @State private var animationPhase: CGFloat = 0
    var autoStart = false

    private var normalizedPower: CGFloat {
        guard recorder.isRecording, !recorder.isPaused else { return 0 }
        let minDb: Float = -50
        let clampedPower = max(recorder.averagePower, minDb)
        let linear = CGFloat((clampedPower - minDb) / (0 - minDb))
        return pow(linear, 2.0)
    }

    var body: some View {
        ZStack {
            WatchGlassTheme.background.ignoresSafeArea()

            VStack(spacing: 8) {
                // Timer display
                Text(formattedTime)
                    .font(.system(size: 40, weight: .light, design: .monospaced))
                    .foregroundStyle(WatchGlassTheme.textPrimary)

                // Recording status capsule
                if recorder.isRecording {
                    HStack(spacing: 6) {
                        PulsingDot()
                        Text(recorder.isPaused ? "已暂停" : "录音中")
                            .font(.caption)
                            .foregroundStyle(recorder.isPaused ? WatchGlassTheme.textTertiary : WatchGlassTheme.textPrimary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
                }

                // Waveform visualization
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                    Canvas { context, size in
                        drawWaveform(context: context, size: size)
                    }
                    .frame(height: 40)
                    .onChange(of: timeline.date) {
                        animationPhase += 0.05
                    }
                }
                .padding(.horizontal, 4)

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
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)

                        // Stop button
                        Button {
                            stopAndSave()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .tint(WatchGlassTheme.accent)
                    } else {
                        // Record button
                        Button {
                            recordingURL = recorder.startRecording()
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.title)
                                .frame(width: 60, height: 60)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .tint(WatchGlassTheme.accent)
                        .accessibilityLabel("开始录音")
                    }
                }
            }
            .padding()
        }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: normalizedPower) {
            amplitudeHistory.removeFirst()
            amplitudeHistory.append(normalizedPower)
        }
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

    // MARK: - Waveform Drawing (matches iPhone style)

    private func drawWaveform(context: GraphicsContext, size: CGSize) {
        let midY = size.height / 2
        let width = size.width

        let avgAmplitude = amplitudeHistory.suffix(10).reduce(0, +) / 10.0
        let maxWaveHeight = size.height * 0.8

        let layers: [(opacity: Double, speed: Double, amplitude: Double)] = [
            (0.08, 1.0, 1.0),
            (0.15, 1.5, 0.7),
            (0.25, 2.0, 0.5),
        ]

        for layer in layers {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: midY))

            let steps = Int(width / 2)
            for i in 0...steps {
                let x = CGFloat(i) / CGFloat(steps) * width
                let normalizedX = x / width

                let angle1 = Double(normalizedX) * .pi * 3 + Double(animationPhase) * layer.speed
                let wave1 = Darwin.sin(angle1) * layer.amplitude
                let angle2 = Double(normalizedX) * .pi * 5 + Double(animationPhase) * layer.speed * 1.3
                let wave2 = Darwin.sin(angle2) * layer.amplitude * 0.5
                let envelope = Darwin.sin(Double(normalizedX) * .pi)
                let y = midY + (wave1 + wave2) * maxWaveHeight * avgAmplitude * envelope

                path.addLine(to: CGPoint(x: x, y: y))
            }

            context.stroke(
                path,
                with: .color(WatchGlassTheme.accent.opacity(layer.opacity)),
                lineWidth: 1.5
            )
        }
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
        WatchConnectivityService.shared.sendRecording(url: result.url, metadata: metadata)

        dismiss()
    }
}
