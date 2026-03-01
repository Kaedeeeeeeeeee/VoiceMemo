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
                print("Failed to start recording setup: \(error)")
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
                print("Failed to enable voice processing: \(error)")
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
                    print("Error writing audio buffer: \(error)")
                }
            }

            engine.prepare()
            try engine.start()
            
            audioEngine = engine
            return url
        } catch {
            print("Failed to start engine: \(error)")
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

        audioEngine = nil
        recordingURL = nil
        recordedFrames = 0

        await Task.detached(priority: .userInitiated) {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        }.value

        return (url, duration)
    }

    func pauseRecording() {
        isPaused = true
    }

    func resumeRecording() {
        isPaused = false
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
