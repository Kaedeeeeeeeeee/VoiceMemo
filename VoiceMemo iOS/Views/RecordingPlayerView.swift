import SwiftUI
import AVFoundation

@Observable
final class AudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.enableRate = true
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func play() {
        player?.rate = playbackRate
        player?.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.currentTime = self.player?.currentTime ?? 0
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }
}

// MARK: - Mini Player Bar

struct MiniPlayerBar: View {
    let recording: Recording
    @Binding var showFullPlayer: Bool
    @State private var player = AudioPlayerManager()
    @State private var miniBarLevels: [CGFloat] = (0..<5).map { _ in CGFloat.random(in: 0.3...0.7) }

    var body: some View {
        Button {
            showFullPlayer = true
        } label: {
            HStack(spacing: 12) {
                // Play/pause
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(GlassTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(GlassTheme.surfaceMedium, in: Circle())
                }
                .buttonStyle(.plain)

                // Mini waveform bars
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule()
                            .fill(GlassTheme.accent)
                            .frame(width: 2, height: player.isPlaying ? miniBarLevels[i] * 16 : 4)
                            .animation(
                                .easeInOut(duration: 0.3)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.1),
                                value: player.isPlaying
                            )
                    }
                }

                Spacer()

                // Time
                Text(formatTime(player.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(GlassTheme.textSecondary)
                Text("/")
                    .font(.caption2)
                    .foregroundStyle(GlassTheme.textMuted)
                Text(formatTime(player.duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(GlassTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard(radius: 28, fill: GlassTheme.surfaceMedium)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
        .onAppear {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)
            player.load(url: url)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Full Player Sheet

struct FullPlayerSheet: View {
    let recording: Recording
    @State private var player = AudioPlayerManager()
    private let availableRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 24) {
            // Title
            VStack(spacing: 4) {
                Text(recording.title)
                    .font(.headline)
                    .foregroundStyle(GlassTheme.textPrimary)
                    .lineLimit(1)
                Text(recording.date.shortDisplay)
                    .font(.caption)
                    .foregroundStyle(GlassTheme.textTertiary)
            }
            .padding(.top, 16)

            // Slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 0.01)
                )
                .tint(GlassTheme.accent)

                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text(formatTime(player.duration))
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(GlassTheme.textTertiary)
            }
            .padding(.horizontal)

            // Controls
            HStack(spacing: 32) {
                Button {
                    player.seek(to: max(0, player.currentTime - 15))
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundStyle(GlassTheme.textSecondary)
                }

                Button {
                    player.toggle()
                } label: {
                    Circle()
                        .fill(GlassTheme.textPrimary)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .foregroundStyle(.black)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    player.seek(to: min(player.duration, player.currentTime + 15))
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundStyle(GlassTheme.textSecondary)
                }
            }

            // Speed selector
            Menu {
                ForEach(availableRates, id: \.self) { rate in
                    Button {
                        player.setRate(rate)
                    } label: {
                        HStack {
                            Text("\(rate, specifier: "%.2g")x")
                            if player.playbackRate == rate {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text("\(player.playbackRate, specifier: "%.2g")x")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(GlassTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassCard(radius: 12)
            }

            Spacer()
        }
        .onAppear {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)
            player.load(url: url)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
