import AVFoundation
import Observation

@Observable
final class iOSAudioRecorder: NSObject {
    var isRecording = false
    var isPaused = false
    var currentTime: TimeInterval = 0
    var averagePower: Float = 0

    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?
    private var recordedFrames: AVAudioFrameCount = 0
    private var recordingSampleRate: Double = 44100.0

    // Stable identifier for the in-flight recording, used by the Live Activity
    // so intents fired from its buttons can route pending markers back to the
    // correct Recording once the model is persisted in saveRecording().
    private(set) var activeRecordingId: String?
    private var accumulatedTimeBeforePause: TimeInterval = 0

    override init() {
        super.init()
    }

    @MainActor
    func startRecording() async -> URL? {
        isRecording = true
        isPaused = false
        recordedFrames = 0
        currentTime = 0
        averagePower = -80.0

        let url = Self.newRecordingURL()
        self.recordingURL = url

        let setupSuccess = await Task.detached(priority: .userInitiated) {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true)
                return true
            } catch {
                #if DEBUG
                print("Failed to start recording setup: \(error)")
                #endif
                return false
            }
        }.value

        guard setupSuccess else {
            isRecording = false
            return nil
        }

        do {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode

            do {
                try inputNode.setVoiceProcessingEnabled(true)
            } catch {
                #if DEBUG
                print("Failed to enable voice processing: \(error)")
                #endif
            }

            let inputFormat = inputNode.inputFormat(forBus: 0)
            self.recordingSampleRate = inputFormat.sampleRate > 0 ? inputFormat.sampleRate : 44100.0

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000
            ]

            audioFile = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, time in
                guard let self = self, let file = self.audioFile else { return }

                if self.isPaused { return }

                do {
                    try file.write(from: buffer)

                    Task { @MainActor in
                        self.recordedFrames += buffer.frameLength
                        self.currentTime = Double(self.recordedFrames) / self.recordingSampleRate
                        self.updateMeters(buffer: buffer)
                    }
                } catch {
                    #if DEBUG
                    print("Error writing audio buffer: \(error)")
                    #endif
                }
            }

            engine.prepare()
            try engine.start()

            audioEngine = engine
            accumulatedTimeBeforePause = 0

            let recordingId = UUID().uuidString
            activeRecordingId = recordingId
            RecordingLiveActivityController.shared.start(
                recordingId: recordingId,
                title: Date.now.recordingTitle,
                source: .phone
            )
            return url
        } catch {
            #if DEBUG
            print("Failed to start engine: \(error)")
            #endif
            isRecording = false
            return nil
        }
    }

    @MainActor
    func stopRecording() async -> (url: URL, duration: TimeInterval)? {
        guard let engine = audioEngine, let url = recordingURL else { return nil }

        let duration = self.currentTime

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioFile = nil

        isRecording = false
        isPaused = false
        currentTime = 0
        averagePower = 0
        RecordingLiveActivityController.shared.end(frozenElapsed: duration)
        activeRecordingId = nil

        audioEngine = nil
        recordingURL = nil
        recordedFrames = 0

        await Task.detached(priority: .userInitiated) {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                #if DEBUG
                print("Failed to deactivate audio session: \(error)")
                #endif
            }
        }.value

        return (url, duration)
    }

    func pauseRecording() {
        isPaused = true
        accumulatedTimeBeforePause = currentTime
        RecordingLiveActivityController.shared.update(isPaused: true, accumulatedElapsed: accumulatedTimeBeforePause)
    }

    func resumeRecording() {
        isPaused = false
        RecordingLiveActivityController.shared.update(isPaused: false, accumulatedElapsed: accumulatedTimeBeforePause)
    }

    @MainActor
    private func updateMeters(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var rms: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[i]
            rms += sample * sample
        }
        rms = sqrt(rms / Float(frameLength))

        let minDb: Float = -80.0
        var db = 20 * log10(rms)
        if db < minDb || db.isNaN {
            db = minDb
        }

        let alpha: Float = 0.2
        self.averagePower = (alpha * db) + ((1.0 - alpha) * self.averagePower)
    }

    static func newRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }
}
