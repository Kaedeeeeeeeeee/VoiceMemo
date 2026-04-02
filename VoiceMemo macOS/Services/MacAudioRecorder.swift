import AVFoundation
import ScreenCaptureKit
import Observation

enum RecordingMode: String, CaseIterable {
    case appAudio = "应用音频"
    case microphone = "麦克风"
}

@Observable
final class MacAudioRecorder: NSObject {
    var isRecording = false
    var isPaused = false
    var currentTime: TimeInterval = 0
    var averagePower: Float = -80.0
    var recordingMode: RecordingMode = .appAudio

    var availableApps: [SCRunningApplication] = []
    var selectedApp: SCRunningApplication?

    private var scStream: SCStream?
    private var assetWriter: AVAssetWriter?
    var audioInput: AVAssetWriterInput?
    private var recordingURL: URL?
    private var recordingStartDate: Date?
    private var pausedDuration: TimeInterval = 0
    private var pauseStartDate: Date?

    // Mic fallback
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordedFrames: AVAudioFrameCount = 0
    private var recordingSampleRate: Double = 44100.0

    private var streamOutput: AudioStreamOutput?

    override init() {
        super.init()
    }

    // MARK: - Available Apps

    @MainActor
    func refreshAvailableApps() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            availableApps = content.applications.filter { !$0.applicationName.isEmpty }
        } catch {
            #if DEBUG
            print("Failed to get shareable content: \(error)")
            #endif
            availableApps = []
        }
    }

    // MARK: - Start Recording

    @MainActor
    func startRecording() async -> URL? {
        isRecording = true
        isPaused = false
        currentTime = 0
        averagePower = -80.0
        pausedDuration = 0
        pauseStartDate = nil

        let url = Self.newRecordingURL()
        self.recordingURL = url

        switch recordingMode {
        case .appAudio:
            return await startAppAudioRecording(url: url)
        case .microphone:
            return await startMicRecording(url: url)
        }
    }

    // MARK: - App Audio (ScreenCaptureKit)

    @MainActor
    private func startAppAudioRecording(url: URL) async -> URL? {
        guard let app = selectedApp else {
            isRecording = false
            return nil
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

            guard let display = content.displays.first else {
                isRecording = false
                return nil
            }

            let filter = SCContentFilter(display: display, including: [app], exceptingWindows: [])

            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = true
            config.sampleRate = 44100
            config.channelCount = 1

            // We only want audio, minimize video
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            // Setup AVAssetWriter
            let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
            let audioSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ]
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = true
            writer.add(input)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            self.assetWriter = writer
            self.audioInput = input

            let output = AudioStreamOutput(recorder: self)
            self.streamOutput = output

            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: .global(qos: .userInitiated))
            try await stream.startCapture()

            self.scStream = stream
            self.recordingStartDate = Date()

            return url
        } catch {
            #if DEBUG
            print("Failed to start app audio recording: \(error)")
            #endif
            isRecording = false
            return nil
        }
    }

    // MARK: - Microphone (AVAudioEngine)

    @MainActor
    private func startMicRecording(url: URL) async -> URL? {
        do {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
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

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
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
            recordedFrames = 0
            return url
        } catch {
            #if DEBUG
            print("Failed to start mic recording: \(error)")
            #endif
            isRecording = false
            return nil
        }
    }

    // MARK: - Stop Recording

    @MainActor
    func stopRecording() async -> (url: URL, duration: TimeInterval)? {
        guard let url = recordingURL else { return nil }

        let duration: TimeInterval

        switch recordingMode {
        case .appAudio:
            // Stop ScreenCaptureKit stream
            if let stream = scStream {
                try? await stream.stopCapture()
                scStream = nil
            }
            streamOutput = nil

            // Finalize AVAssetWriter
            audioInput?.markAsFinished()
            if let writer = assetWriter, writer.status == .writing {
                await writer.finishWriting()
            }
            assetWriter = nil
            audioInput = nil

            duration = currentTime

        case .microphone:
            if let engine = audioEngine {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
            audioFile = nil
            audioEngine = nil
            duration = currentTime
            recordedFrames = 0
        }

        isRecording = false
        isPaused = false
        currentTime = 0
        averagePower = -80.0
        recordingURL = nil
        recordingStartDate = nil
        pausedDuration = 0
        pauseStartDate = nil

        return (url, duration)
    }

    // MARK: - Pause / Resume

    func pauseRecording() {
        isPaused = true
        pauseStartDate = Date()
    }

    func resumeRecording() {
        if let pauseStart = pauseStartDate {
            pausedDuration += Date().timeIntervalSince(pauseStart)
        }
        pauseStartDate = nil
        isPaused = false
    }

    // MARK: - Metering

    @MainActor
    func updateMeters(buffer: AVAudioPCMBuffer) {
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

    @MainActor
    func updateMetersFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(blockBuffer)

        var data = Data(count: length)
        data.withUnsafeMutableBytes { rawBuffer in
            guard let ptr = rawBuffer.baseAddress else { return }
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr)
        }

        let floatCount = length / MemoryLayout<Float>.size
        guard floatCount > 0 else { return }

        data.withUnsafeBytes { rawBuffer in
            guard let floatPtr = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            var rms: Float = 0
            for i in 0..<floatCount {
                let sample = floatPtr[i]
                rms += sample * sample
            }
            rms = sqrt(rms / Float(floatCount))

            let minDb: Float = -80.0
            var db = 20 * log10(rms)
            if db < minDb || db.isNaN {
                db = minDb
            }

            let alpha: Float = 0.2
            self.averagePower = (alpha * db) + ((1.0 - alpha) * self.averagePower)
        }
    }

    @MainActor
    func updateTimeFromStream() {
        guard let startDate = recordingStartDate else { return }
        let elapsed = Date().timeIntervalSince(startDate) - pausedDuration
        if let pauseStart = pauseStartDate {
            currentTime = elapsed - Date().timeIntervalSince(pauseStart)
        } else {
            currentTime = elapsed
        }
    }

    // MARK: - Helpers

    static func newRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(UUID().uuidString).m4a"
        return documentsPath.appendingPathComponent(fileName)
    }
}

// MARK: - SCStream Audio Output

final class AudioStreamOutput: NSObject, SCStreamOutput {
    private weak var recorder: MacAudioRecorder?

    init(recorder: MacAudioRecorder) {
        self.recorder = recorder
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard let recorder = recorder else { return }

        Task { @MainActor in
            guard !recorder.isPaused else { return }
            recorder.updateTimeFromStream()
            recorder.updateMetersFromSampleBuffer(sampleBuffer)
        }

        // Write to AVAssetWriter
        guard let input = recorder.audioInput, input.isReadyForMoreMediaData else { return }
        if !recorder.isPaused {
            input.append(sampleBuffer)
        }
    }
}
