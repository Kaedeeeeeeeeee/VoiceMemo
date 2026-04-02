import SwiftUI
import SwiftData
import AppKit

struct MacRecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = MacAudioRecorder()
    @State private var amplitudeHistory: [CGFloat] = Array(repeating: 0, count: 50)
    @State private var animationPhase: CGFloat = 0
    @State private var stopButtonProgress: CGFloat = 0
    @State private var isLongPressingStop = false

    private let stopHoldDuration: CGFloat = 1.5

    var body: some View {
        ZStack {
            MacRadialBackgroundView()

            if recorder.isRecording {
                recordingUI
                    .transition(.scale(scale: 0.05, anchor: .center).combined(with: .opacity))
            } else {
                idleUI
                    .transition(.scale(scale: 0.05, anchor: .center).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: recorder.isRecording)
        .onChange(of: normalizedPower) {
            amplitudeHistory.removeFirst()
            amplitudeHistory.append(normalizedPower)
        }
        .task {
            await recorder.refreshAvailableApps()
        }
    }

    // MARK: - Recording UI

    private var recordingUI: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                MacGlassTheme.uppercaseLabel("Live Audio")
                Text(recorder.recordingMode == .appAudio ? "应用音频录制中" : "麦克风录制中")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(MacGlassTheme.textPrimary)
            }
            .padding(.top, 24)

            Spacer()

            // Waveform
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    drawWaveform(context: context, size: size, date: timeline.date)
                }
                .frame(height: 100)
                .onChange(of: timeline.date) {
                    animationPhase += 0.05
                }
            }
            .padding(.horizontal, 16)

            // Status capsule
            HStack(spacing: 8) {
                MacPulsingDot()
                Text(recorder.isPaused ? "已暂停" : "录音中")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(recorder.isPaused ? MacGlassTheme.textTertiary : MacGlassTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .macGlassCard(radius: 16)
            .padding(.top, 16)

            // Timer
            MacGlassTheme.heroTimer(formattedTime)
                .padding(.top, 16)

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
                    Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                        .frame(width: 48, height: 48)
                }
                .macGlassButton(circular: true, tint: .white)

                // Stop (long press)
                MacLongPressStopButton(progress: stopButtonProgress, size: 64)
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
            }
            // Hint text
            Text("长按停止按钮结束录音")
                .font(.caption)
                .foregroundStyle(MacGlassTheme.textMuted)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Idle UI

    private var idleUI: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                MacGlassTheme.uppercaseLabel("AI Transcription")
                Text("PodNote")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(MacGlassTheme.textPrimary)
            }
            .padding(.bottom, 24)

            // Mode toggle
            HStack(spacing: 8) {
                ForEach(RecordingMode.allCases, id: \.rawValue) { mode in
                    MacGlassChip(
                        title: mode.rawValue,
                        isActive: recorder.recordingMode == mode
                    ) {
                        recorder.recordingMode = mode
                    }
                }
            }
            .padding(.bottom, 16)

            // App picker (only for app audio mode)
            if recorder.recordingMode == .appAudio {
                VStack(spacing: 8) {
                    Text("选择要录制的应用")
                        .font(.subheadline)
                        .foregroundStyle(MacGlassTheme.textTertiary)

                    AppPickerView(
                        selectedApp: $recorder.selectedApp,
                        availableApps: recorder.availableApps
                    )
                    .padding(.horizontal, 24)

                    Button {
                        Task { await recorder.refreshAvailableApps() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                            Text("刷新")
                                .font(.caption)
                        }
                        .foregroundStyle(MacGlassTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)
            }

            // Record button
            ZStack {
                // Dot grid background
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let gridSize: CGFloat = 280
                    let spacing: CGFloat = 12
                    let dotRadius: CGFloat = 1.5
                    let maxDist = gridSize / 2

                    var row = -gridSize / 2
                    while row <= gridSize / 2 {
                        var col = -gridSize / 2
                        while col <= gridSize / 2 {
                            let dist = sqrt(row * row + col * col)
                            if dist <= maxDist {
                                let opacity = 0.5 * (1 - dist / maxDist)
                                let point = CGPoint(x: center.x + col, y: center.y + row)
                                let path = Path(ellipseIn: CGRect(
                                    x: point.x - dotRadius,
                                    y: point.y - dotRadius,
                                    width: dotRadius * 2,
                                    height: dotRadius * 2
                                ))
                                context.fill(path, with: .color(MacGlassTheme.accent.opacity(opacity)))
                            }
                            col += spacing
                        }
                        row += spacing
                    }
                }
                .frame(width: 280, height: 280)
                .allowsHitTesting(false)

                Button {
                    Task { _ = await recorder.startRecording() }
                } label: {
                    Image(systemName: recorder.recordingMode == .appAudio ? "app.connected.to.app.below.fill" : "mic.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                        .frame(width: 110, height: 110)
                }
                .macGlassButton(circular: true)
                .disabled(recorder.recordingMode == .appAudio && recorder.selectedApp == nil)
            }

            // Status
            HStack(spacing: 6) {
                Circle()
                    .fill(MacGlassTheme.textMuted)
                    .frame(width: 6, height: 6)
                Text("准备录音")
                    .font(.caption)
                    .foregroundStyle(MacGlassTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .macGlassCard(radius: 16)
            .padding(.top, 16)

            Text(recorder.recordingMode == .appAudio ? "选择应用后开始录制音频" : "轻触开始捕捉你的想法")
                .font(.caption)
                .foregroundStyle(MacGlassTheme.textMuted)
                .padding(.top, 8)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private func saveRecording(url: URL, duration: TimeInterval) {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        let recording = Recording(
            title: Date.now.recordingTitle,
            duration: duration,
            fileURL: url.lastPathComponent,
            fileSize: fileSize,
            source: .mac
        )
        modelContext.insert(recording)

        // Auto-transcribe
        AutoTranscriptionManager.shared.startTranscription(for: recording)
    }

    // MARK: - Long Press Stop

    private func startStopHoldTimer() {
        stopButtonProgress = 0
        let startTime = Date()

        // Haptic at start
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)

        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(CGFloat(elapsed) / stopHoldDuration, 1.0)
            stopButtonProgress = progress

            if progress >= 1.0 {
                timer.invalidate()
                isLongPressingStop = false

                // Haptic on complete
                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)

                Task { @MainActor in
                    if let result = await recorder.stopRecording() {
                        saveRecording(url: result.url, duration: result.duration)
                    }
                    withAnimation(.easeOut(duration: 0.3)) {
                        stopButtonProgress = 0
                    }
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

    private var formattedTime: String {
        let total = Int(recorder.currentTime)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private var normalizedPower: CGFloat {
        guard recorder.isRecording, !recorder.isPaused else { return 0 }
        let minDb: Float = -50
        let clampedPower = max(recorder.averagePower, minDb)
        let linear = CGFloat((clampedPower - minDb) / (0 - minDb))
        return pow(linear, 2.0)
    }

    private func drawWaveform(context: GraphicsContext, size: CGSize, date: Date) {
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
                with: .color(MacGlassTheme.accent.opacity(layer.opacity)),
                lineWidth: 1.5
            )
        }
    }
}

// MARK: - Mac Long Press Stop Button

private struct MacLongPressStopButton: View {
    let progress: CGFloat
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(MacGlassTheme.surfaceMedium)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(MacGlassTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: size + 8, height: size + 8)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.016), value: progress)

            Image(systemName: "stop.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
        .frame(width: size + 12, height: size + 12)
    }
}
