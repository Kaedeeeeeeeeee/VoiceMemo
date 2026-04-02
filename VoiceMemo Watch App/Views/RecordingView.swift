import SwiftUI
import SwiftData
import WatchKit

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = WatchAudioRecorder()
    @State private var recordingURL: URL?
    @State private var amplitudeHistory: [CGFloat] = Array(repeating: 0, count: 20)
    @State private var animationPhase: CGFloat = 0
    @State private var stopButtonProgress: CGFloat = 0
    @State private var isLongPressingStop = false
    @State private var showCompletionMessage = false
    var autoStart = false

    private let stopHoldDuration: CGFloat = 1.5

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

            if showCompletionMessage {
                // Completion screen
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green)

                    Text("录音已保存")
                        .font(.headline)
                        .foregroundStyle(WatchGlassTheme.textPrimary)

                    Text("请前往 iPhone 或 Mac 查看")
                        .font(.caption)
                        .foregroundStyle(WatchGlassTheme.textTertiary)
                        .multilineTextAlignment(.center)

                    Button {
                        dismiss()
                    } label: {
                        Text("完成")
                            .font(.subheadline)
                    }
                    .buttonStyle(.glass)
                    .padding(.top, 8)
                }
                .padding()
            } else {
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

                    if recorder.isRecording {
                        Text("长按停止按钮结束录音")
                            .font(.system(size: 10))
                            .foregroundStyle(WatchGlassTheme.textMuted)
                    }

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

                            // Stop button (long press)
                            WatchLongPressStopButton(progress: stopButtonProgress, size: 44)
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            if !isLongPressingStop {
                                                isLongPressingStop = true
                                                startStopHoldTimer()
                                            }
                                        }
                                        .onEnded { _ in
                                            cancelStopHold()
                                        }
                                )
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

        let recordingId = recording.id.uuidString

        // Listen for transfer completion
        let context = modelContext
        NotificationCenter.default.addObserver(
            forName: .fileTransferCompleted,
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let notifId = userInfo["recordingId"] as? String,
                  notifId == recordingId,
                  let success = userInfo["success"] as? Bool,
                  success else { return }

            let descriptor = FetchDescriptor<Recording>(predicate: #Predicate { $0.id.uuidString == recordingId })
            if let rec = try? context.fetch(descriptor).first {
                rec.isSynced = true
                try? context.save()
            }
        }

        // Send to iPhone
        let metadata: [String: Any] = [
            "id": recordingId,
            "title": recording.title,
            "duration": recording.duration,
            "date": recording.date.timeIntervalSince1970,
            "fileSize": fileSize
        ]
        WatchConnectivityService.shared.sendRecording(url: result.url, metadata: metadata)

        // Show completion message instead of dismissing
        withAnimation {
            showCompletionMessage = true
        }
    }

    // MARK: - Long Press Stop

    private func startStopHoldTimer() {
        stopButtonProgress = 0
        let startTime = Date()

        // Light haptic at start
        WKInterfaceDevice.current().play(.click)

        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(CGFloat(elapsed) / stopHoldDuration, 1.0)
            stopButtonProgress = progress

            if progress >= 1.0 {
                timer.invalidate()
                isLongPressingStop = false

                // Strong haptic on complete
                WKInterfaceDevice.current().play(.success)

                stopAndSave()

                withAnimation(.easeOut(duration: 0.3)) {
                    stopButtonProgress = 0
                }
            }
        }
    }

    private func cancelStopHold() {
        isLongPressingStop = false
        withAnimation(.easeOut(duration: 0.3)) {
            stopButtonProgress = 0
        }
    }
}

// MARK: - Watch Long Press Stop Button

private struct WatchLongPressStopButton: View {
    let progress: CGFloat
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(WatchGlassTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: size + 6, height: size + 6)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.016), value: progress)

            Image(systemName: "stop.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
        .frame(width: size + 10, height: size + 10)
    }
}
