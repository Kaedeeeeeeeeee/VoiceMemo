import AVFoundation
import Observation

@Observable
final class MacAudioPlayerManager: NSObject, AVAudioPlayerDelegate {
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackRate: Float = 1.0
    var isSeeking = false

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) async {
        let loadedPlayer = await Task.detached { () -> AVAudioPlayer? in
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
