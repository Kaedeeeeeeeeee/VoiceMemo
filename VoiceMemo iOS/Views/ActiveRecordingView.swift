import SwiftUI
import Foundation

struct ActiveRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    let recorder: iOSAudioRecorder
    let onSave: (URL, TimeInterval) -> Void

    @State private var amplitudeHistory: [CGFloat] = Array(repeating: 0, count: 50)
    @State private var animationPhase: CGFloat = 0
    @State private var hasSaved = false

    var body: some View {
        ZStack {
            RadialBackgroundView()

            VStack(spacing: 0) {
                // Header labels
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
                        Circle()
                            .fill(GlassTheme.surfaceMedium)
                            .overlay(
                                Circle()
                                    .stroke(GlassTheme.borderSubtle, lineWidth: 0.5)
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                                    .font(.title3)
                                    .foregroundStyle(GlassTheme.textPrimary)
                            )
                    }
                    .buttonStyle(.plain)

                    // Stop
                    Button {
                        if let result = recorder.stopRecording() {
                            hasSaved = true
                            onSave(result.url, result.duration)
                        }
                        dismiss()
                    } label: {
                        Circle()
                            .fill(GlassTheme.accent)
                            .frame(width: 72, height: 72)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.white)
                                    .frame(width: 22, height: 22)
                            )
                    }
                    .buttonStyle(.plain)

                    // Bookmark (placeholder)
                    Button { } label: {
                        Circle()
                            .fill(GlassTheme.surfaceMedium)
                            .overlay(
                                Circle()
                                    .stroke(GlassTheme.borderSubtle, lineWidth: 0.5)
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "star")
                                    .font(.title3)
                                    .foregroundStyle(GlassTheme.textMuted)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                }
                .padding(.bottom, 24)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    _ = recorder.stopRecording()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("取消")
                    }
                    .foregroundStyle(GlassTheme.textSecondary)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            _ = recorder.startRecording()
        }
        .onChange(of: normalizedPower) {
            amplitudeHistory.removeFirst()
            amplitudeHistory.append(normalizedPower)
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
