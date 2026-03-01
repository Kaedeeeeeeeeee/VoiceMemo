import SwiftUI
import AVFoundation

@Observable
final class AudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    var isSeeking = false

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) async {
        let loadedPlayer = await Task.detached { () -> AVAudioPlayer? in
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default)
            try? session.setActive(true)
            let p = try? AVAudioPlayer(contentsOf: url)
            p?.enableRate = true
            p?.prepareToPlay()
            return p
        }.value
        self.player = loadedPlayer
        self.player?.delegate = self
        self.duration = loadedPlayer?.duration ?? 0
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
        isSeeking = false
    }

    func setRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player?.rate = rate
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, !self.isSeeking else { return }
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
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                // Play/pause
                Button {
                    player.toggle()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(GlassTheme.textPrimary)
                        .frame(width: 28, height: 28)
                }
                .glassButton(circular: true)

                // Progress slider
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { newValue in
                            player.isSeeking = true
                            player.currentTime = newValue
                        }
                    ),
                    in: 0...max(player.duration, 0.01),
                    onEditingChanged: { editing in
                        if !editing {
                            player.seek(to: player.currentTime)
                        } else {
                            player.isSeeking = true
                        }
                    }
                )
                .tint(GlassTheme.accent)

                // Time
                Text("\(formatTime(player.currentTime))/\(formatTime(player.duration))")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(GlassTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassCard(radius: 20)
            .padding(.horizontal)
            .padding(.bottom, 2)
        }
        .onTapGesture {
            showFullPlayer = true
        }
        .task {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)
            await player.load(url: url)
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
                        set: { newValue in
                            player.isSeeking = true
                            player.currentTime = newValue
                        }
                    ),
                    in: 0...max(player.duration, 0.01),
                    onEditingChanged: { editing in
                        if !editing {
                            player.seek(to: player.currentTime)
                        } else {
                            player.isSeeking = true
                        }
                    }
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
        .task {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)
            await player.load(url: url)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
