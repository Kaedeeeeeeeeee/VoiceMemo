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
    @State private var isHoldingStop = false
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

            VStack(spacing: 6) {
                    // Timer display
                    Text(formattedTime)
                        .font(.system(size: 34, weight: .light, design: .monospaced))
                        .foregroundStyle(WatchGlassTheme.textPrimary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

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
                        .frame(height: 28)
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

                    Spacer(minLength: 0)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    HStack(spacing: 20) {
                        if recorder.isRecording {
                            // Pause/Resume button.
                            // The .glass button style adds its own padding around
                            // the label — to land at a ~44pt visual diameter
                            // matching the stop button, keep the icon frame small.
                            Button {
                                if recorder.isPaused {
                                    recorder.resumeRecording()
                                } else {
                                    recorder.pauseRecording()
                                }
                            } label: {
                                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)

                            // Stop button (long press).
                            // Uses the high-level onLongPressGesture modifier because
                            // watchOS delivers unreliable .onEnded events for composed
                            // LongPress+Drag sequences — `pressing:` is the only
                            // callback the system guarantees to fire on release.
                            WatchLongPressStopButton(progress: stopButtonProgress, size: 44)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                                .onLongPressGesture(
                                    minimumDuration: stopHoldDuration,
                                    maximumDistance: 200,
                                    perform: {
                                        completeStopHold()
                                    },
                                    onPressingChanged: { pressing in
                                        if pressing {
                                            startStopHoldTimer()
                                        } else {
                                            cancelStopHold()
                                        }
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
                    .fixedSize()
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
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
        // Capture the active recording id before stopRecording() clears it —
        // the iPhone uses this id to correlate the incoming file with the
        // Live Activity session and any pending lock-screen markers.
        let liveActivityRecordingId = recorder.activeRecordingId
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
        try? modelContext.save()

        // Send to iPhone — sync-flag flip is handled by WatchConnectivityService
        // when the transfer finishes, so this view no longer needs a notification
        // observer (previous implementation leaked observers and captured a
        // view-scoped model context that crashed after dismissal).
        var metadata: [String: Any] = [
            "id": recording.id.uuidString,
            "title": recording.title,
            "duration": recording.duration,
            "date": recording.date.timeIntervalSince1970,
            "fileSize": fileSize
        ]
        if let liveActivityRecordingId {
            metadata["liveActivityRecordingId"] = liveActivityRecordingId
        }
        WatchConnectivityService.shared.sendRecording(url: result.url, metadata: metadata)

        // Dismiss back to the recordings list. The new recording will show up
        // there automatically via @Query, so the list itself is the confirmation.
        // We intentionally avoid an in-view "完成" screen because toggling the
        // ZStack branches right as the AVAudioSession deactivates caused watchOS
        // to render the post-stop view as a black void.
        dismiss()
    }

    // MARK: - Long Press Stop
    //
    // Visual progress is driven by a single SwiftUI animation so Core
    // Animation interpolates at display refresh rate. The actual stop
    // trigger is owned by .onLongPressGesture(perform:), which the system
    // fires exactly when minimumDuration has been reached.

    private func startStopHoldTimer() {
        isHoldingStop = true

        // Reset without animation, then drive the ring to 1 over the hold duration.
        var txn = Transaction()
        txn.disablesAnimations = true
        withTransaction(txn) {
            stopButtonProgress = 0
        }

        // Light haptic at start
        WKInterfaceDevice.current().play(.click)

        withAnimation(.linear(duration: stopHoldDuration)) {
            stopButtonProgress = 1.0
        }
    }

    private func cancelStopHold() {
        // If the press already completed, don't undo the visual state —
        // completeStopHold() + showCompletionMessage own it now.
        guard isHoldingStop else { return }
        isHoldingStop = false
        withAnimation(.easeOut(duration: 0.3)) {
            stopButtonProgress = 0
        }
    }

    private func completeStopHold() {
        isHoldingStop = false
        // The linear animation is already at (or near) 1.0; leave it there so
        // the ring stays full while we transition to the completion screen.

        // Strong haptic on complete
        WKInterfaceDevice.current().play(.success)

        stopAndSave()
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

            Image(systemName: "stop.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
        .frame(width: size + 10, height: size + 10)
    }
}
