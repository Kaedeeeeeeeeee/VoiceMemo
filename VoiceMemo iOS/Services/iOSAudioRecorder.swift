import AVFoundation
import Observation

@Observable
final class iOSAudioRecorder: NSObject {
    var isRecording = false
    var isPaused = false
    var currentTime: TimeInterval = 0
    var averagePower: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?

    override init() {
        super.init()
    }

    func startRecording() -> URL? {
        let url = Self.newRecordingURL()
        self.recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            isRecording = true
            isPaused = false
            startTimer()

            return url
        } catch {
            print("Failed to start recording: \(error)")
            return nil
        }
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = audioRecorder, let url = recordingURL else { return nil }

        let duration = recorder.currentTime
        recorder.stop()

        isRecording = false
        isPaused = false
        currentTime = 0
        averagePower = 0
        stopTimer()

        audioRecorder = nil
        recordingURL = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }

        return (url, duration)
    }

    func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        stopTimer()
    }

    func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            self.currentTime = recorder.currentTime
            self.averagePower = recorder.averagePower(forChannel: 0)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    static func newRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }
}
