import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import WidgetKit

struct RecordingHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = iOSAudioRecorder()
    @State private var showFilePicker = false
    @State private var showTemplateAlert = false
    @State private var amplitudeHistory: [CGFloat] = Array(repeating: 0, count: 50)
    @State private var animationPhase: CGFloat = 0
    @State private var stopButtonProgress: CGFloat = 0
    @State private var isLongPressingStop = false
    @GestureState private var isPressingStop = false
    @State private var pendingMarkers: [(timestamp: TimeInterval, text: String, photoFileName: String?)] = []
    @State private var showAddMarker = false
    @State private var markerTimestamp: TimeInterval = 0
    var switchToTab: (AppTab) -> Void
    @Binding var triggerRecord: Bool

    private let stopHoldDuration: CGFloat = 1.5

    var body: some View {
        ZStack {
            RadialBackgroundView()

            ZStack {
                if recorder.isRecording {
                    // Active recording UI
                    VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        GlassTheme.uppercaseLabel("Live Audio")
                        Text("正在录音")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(GlassTheme.textPrimary)
                    }
                    .padding(.top, 16)

                    Spacer()

                    // Waveform visualization
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                        Canvas { context, size in
                            drawWaveform(context: context, size: size, date: timeline.date)
                        }
                        .frame(height: 120)
                        .onChange(of: timeline.date) {
                            animationPhase += 0.05
                        }
                    }
                    .padding(.horizontal, 8)

                    // Recording status capsule
                    HStack(spacing: 8) {
                        PulsingDot()
                        Text(recorder.isPaused ? "已暂停" : "录音中")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(recorder.isPaused ? GlassTheme.textTertiary : GlassTheme.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCard(radius: 20)
                    .padding(.top, 16)

                    // Timer
                    GlassTheme.heroTimer(formattedTime)
                        .padding(.top, 20)

                    Spacer()

                    // Control buttons
                    HStack(spacing: 40) {
                        // Pause/Resume
                        Button {
                            if recorder.isPaused {
                                recorder.resumeRecording()
                            } else {
                                recorder.pauseRecording()
                            }
                        } label: {
                            Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                                .font(.title3)
                                .frame(width: 56, height: 56)
                        }
                        .glassButton(circular: true, tint: .white)

                        // Stop (long press)
                        LongPressStopButton(
                            progress: stopButtonProgress,
                            size: 72,
                            tint: GlassTheme.accent
                        )
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

                        // Bookmark
                        Button {
                            markerTimestamp = recorder.currentTime
                            showAddMarker = true
                        } label: {
                            Image(systemName: pendingMarkers.isEmpty ? "bookmark" : "bookmark.fill")
                                .font(.title3)
                                .frame(width: 56, height: 56)
                        }
                        .glassButton(circular: true)
                    }

                    // Hint text
                    Text("长按停止按钮结束录音")
                        .font(.caption)
                        .foregroundStyle(GlassTheme.textMuted)
                        .padding(.bottom, 24)
                    }
                    .transition(.scale(scale: 0.05, anchor: .center).combined(with: .opacity))
                } else {
                    // Idle UI
                    VStack(spacing: 0) {
                    Spacer()

                    // Title block
                    VStack(spacing: 6) {
                        GlassTheme.uppercaseLabel("AI Transcription")
                        Text("PodNote")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(GlassTheme.textPrimary)
                    }
                    .padding(.bottom, 40)

                    // Mic button
                    ZStack {
                        Canvas { context, size in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            let gridSize: CGFloat = 380
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
                                        context.fill(path, with: .color(GlassTheme.accent.opacity(opacity)))
                                    }
                                    col += spacing
                                }
                                row += spacing
                            }
                        }
                        .frame(width: 380, height: 380)
                        .allowsHitTesting(false)

                        Button {
                            Task {
                                _ = await recorder.startRecording()
                            }
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.white)
                                .frame(width: 140, height: 140)
                        }
                        .glassButton(circular: true)
                    }

                    // Status capsule
                    HStack(spacing: 6) {
                        Circle()
                            .fill(GlassTheme.textMuted)
                            .frame(width: 6, height: 6)
                        Text("准备录音")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCard(radius: 20)
                    .padding(.top, 20)

                    Text("轻触开始捕捉你的想法")
                        .font(.caption)
                        .foregroundStyle(GlassTheme.textMuted)
                        .padding(.top, 12)

                    Spacer()

                    // Bottom action buttons
                    HStack(spacing: 16) {
                        Button {
                            showFilePicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.down")
                                Text("导入音频")
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textSecondary)
                        }
                        .glassButton()

                        Button {
                            showTemplateAlert = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text")
                                Text("笔记模板")
                            }
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textSecondary)
                        }
                        .glassButton()
                    }
                    .padding(.bottom, 24)
                    }
                    .transition(.scale(scale: 0.05, anchor: .center).combined(with: .opacity))
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: normalizedPower) {
            amplitudeHistory.removeFirst()
            amplitudeHistory.append(normalizedPower)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: recorder.isRecording)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleImportedFile(result)
        }
        .sheet(isPresented: $showAddMarker) {
            AddMarkerSheet(timestamp: markerTimestamp) { text, photoFileName in
                pendingMarkers.append((timestamp: markerTimestamp, text: text, photoFileName: photoFileName))
            }
        }
        .alert("即将上线", isPresented: $showTemplateAlert) {
            Button("好的") { }
        } message: {
            Text("笔记模板功能即将上线，敬请期待")
        }
        .onChange(of: triggerRecord) {
            if triggerRecord && !recorder.isRecording {
                triggerRecord = false
                Task {
                    _ = await recorder.startRecording()
                }
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

        // Attach pending markers
        for pending in pendingMarkers {
            let marker = RecordingMarker(
                timestamp: pending.timestamp,
                text: pending.text,
                photoFileName: pending.photoFileName
            )
            marker.recording = recording
            modelContext.insert(marker)
        }
        pendingMarkers.removeAll()

        // Auto-transcribe
        AutoTranscriptionManager.shared.startTranscription(for: recording)

        // Update shared UserDefaults for widgets
        updateWidgetData()
    }

    private func updateWidgetData() {
        guard let defaults = UserDefaults(suiteName: "group.com.zhangshifeng.VoiceMemo") else { return }

        // Fetch recent recordings from model context
        let descriptor = FetchDescriptor<Recording>(sortBy: [SortDescriptor(\Recording.date, order: .reverse)])
        guard let recordings = try? modelContext.fetch(descriptor) else { return }

        if let latest = recordings.first {
            defaults.set(latest.title, forKey: "lastRecordingTitle")
            defaults.set(latest.date.timeIntervalSince1970, forKey: "lastRecordingDate")
        }

        let recentItems = recordings.prefix(3).map { recording in
            ["title": recording.title, "date": String(recording.date.timeIntervalSince1970)]
        }
        if let data = try? JSONEncoder().encode(recentItems),
           let json = String(data: data, encoding: .utf8) {
            defaults.set(json, forKey: "recentRecordingsJSON")
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Long Press Stop

    private func startStopHoldTimer() {
        stopButtonProgress = 0
        let startTime = Date()

        // Light haptic at start
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(CGFloat(elapsed) / stopHoldDuration, 1.0)
            stopButtonProgress = progress

            if progress >= 1.0 {
                timer.invalidate()
                isLongPressingStop = false

                // Strong haptic on complete
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                UINotificationFeedbackGenerator().notificationOccurred(.success)

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

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let sourceURL = urls.first else { return }
        guard sourceURL.startAccessingSecurityScopedResource() else { return }
        defer { sourceURL.stopAccessingSecurityScopedResource() }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "imported_\(UUID().uuidString).m4a"
        let destURL = documentsDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: destURL.path)[.size] as? Int64) ?? 0
            let recording = Recording(
                title: sourceURL.deletingPathExtension().lastPathComponent,
                duration: 0,
                fileURL: fileName,
                fileSize: fileSize,
                source: .phone
            )
            modelContext.insert(recording)
        } catch {
            #if DEBUG
            print("Failed to import audio: \(error)")
            #endif
        }
    }

    // MARK: - Recording Properties & Methods
    
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

        // Average amplitude for wave height
        let avgAmplitude = amplitudeHistory.suffix(10).reduce(0, +) / 10.0
        let maxWaveHeight = size.height * 0.8

        // Draw multiple layers
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
                with: .color(GlassTheme.accent.opacity(layer.opacity)),
                lineWidth: 1.5
            )
        }
    }
}

// MARK: - Long Press Stop Button

private struct LongPressStopButton: View {
    let progress: CGFloat
    let size: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(GlassTheme.surfaceMedium)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: size + 8, height: size + 8)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.016), value: progress)

            // Stop icon
            Image(systemName: "stop.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
        .frame(width: size + 12, height: size + 12)
    }
}
