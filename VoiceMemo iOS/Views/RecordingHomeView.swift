import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct RecordingHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recorder = iOSAudioRecorder()
    @State private var showFilePicker = false
    @State private var showTemplateAlert = false
    @State private var amplitudeHistory: [CGFloat] = Array(repeating: 0, count: 50)
    @State private var animationPhase: CGFloat = 0
    var switchToTab: (AppTab) -> Void

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
                        .glassButton(circular: true)

                        // Stop
                        Button {
                            Task {
                                if let result = await recorder.stopRecording() {
                                    saveRecording(url: result.url, duration: result.duration)
                                }
                            }
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.title2)
                                .frame(width: 72, height: 72)
                        }
                        .glassButton(circular: true, tint: GlassTheme.accent)

                        // Bookmark (placeholder)
                        Button { } label: {
                            Image(systemName: "star")
                                .font(.title3)
                                .frame(width: 56, height: 56)
                        }
                        .glassButton(circular: true)
                        .disabled(true)
                    }
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

                    // Concentric circles mic button
                    ZStack {
                        // Outer ring
                        Circle()
                            .fill(.clear)
                            .frame(width: 260, height: 260)
                            .adaptiveGlassEffect(in: Circle())

                        // Middle ring
                        Color.clear
                            .frame(width: 200, height: 200)
                            .adaptiveGlassEffect(in: Circle())

                        // Inner button
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
        .alert("即将上线", isPresented: $showTemplateAlert) {
            Button("好的") { }
        } message: {
            Text("笔记模板功能即将上线，敬请期待")
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
            print("Failed to import audio: \(error)")
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

