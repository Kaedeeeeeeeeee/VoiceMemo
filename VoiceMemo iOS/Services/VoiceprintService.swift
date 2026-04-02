import Foundation
import AVFoundation
import Accelerate
import Observation

@Observable
final class VoiceprintService {
    var isProcessing = false

    struct SpeakerMatchResult {
        let profileName: String
        let profileID: UUID
        let confidence: Double
    }

    private static let matchThreshold: Double = 0.85
    private static let targetSampleRate: Double = 16000
    private static let frameLength: Int = 400     // 25ms at 16kHz
    private static let hopLength: Int = 160       // 10ms at 16kHz
    private static let nFFT: Int = 512            // next power of 2 above frameLength
    private static let nMelFilters: Int = 26
    private static let nMFCCCoeffs: Int = 13
    private static let maxSegmentsPerSpeaker: Int = 10
    private static let maxTotalDuration: Double = 60.0 // seconds

    // MARK: - Public API

    /// Extract MFCC embedding from audio segments for a given speaker
    func extractEmbedding(audioURL: URL, segments: [SpeakerSegment]) throws -> [Double] {
        var allMFCCFrames: [[Float]] = []

        let cappedSegments = capSegments(segments)

        for segment in cappedSegments {
            let samples = try loadAudioSamples(url: audioURL, startTime: segment.startTime, duration: segment.duration)
            guard samples.count > Self.frameLength else { continue }

            let emphasized = preEmphasis(samples)
            let frames = frameSignal(emphasized)
            let filterbank = melFilterbank()

            for frame in frames {
                let windowed = applyHammingWindow(frame)
                let power = powerSpectrum(windowed)
                let coeffs = mfcc(powerSpectrum: power, filterbank: filterbank)
                allMFCCFrames.append(coeffs)
            }
        }

        guard !allMFCCFrames.isEmpty else {
            return Array(repeating: 0.0, count: Self.nMFCCCoeffs)
        }

        return averageMFCCs(allMFCCFrames)
    }

    /// Enroll a speaker: compute embedding, create or update SpeakerProfile
    func enrollSpeaker(name: String, audioURL: URL, segments: [SpeakerSegment], existingProfile: SpeakerProfile?) throws -> SpeakerProfile {
        let newEmbedding = try extractEmbedding(audioURL: audioURL, segments: segments)
        let totalDuration = segments.reduce(0.0) { $0 + $1.duration }

        if let profile = existingProfile {
            // Weighted running average
            let oldCount = Double(profile.sampleCount)
            let newCount = Double(segments.count)
            let totalCount = oldCount + newCount

            var merged = [Double](repeating: 0, count: Self.nMFCCCoeffs)
            for i in 0..<Self.nMFCCCoeffs {
                merged[i] = (profile.embedding[i] * oldCount + newEmbedding[i] * newCount) / totalCount
            }

            profile.embedding = merged
            profile.sampleCount += segments.count
            profile.totalSampleDuration += totalDuration
            profile.updatedAt = .now
            return profile
        } else {
            return SpeakerProfile(
                name: name,
                embedding: newEmbedding,
                sampleCount: segments.count,
                totalSampleDuration: totalDuration
            )
        }
    }

    /// Match all speakers in utterances against stored profiles
    func matchSpeakers(audioURL: URL, utterances: [SpeakerUtterance], profiles: [SpeakerProfile]) -> [String: SpeakerMatchResult] {
        guard !profiles.isEmpty else { return [:] }

        // Group utterances by speaker
        var speakerSegments: [String: [SpeakerSegment]] = [:]
        for utterance in utterances {
            let segment = SpeakerSegment(
                startTime: Double(utterance.startMs) / 1000.0,
                endTime: Double(utterance.endMs) / 1000.0
            )
            speakerSegments[utterance.speaker, default: []].append(segment)
        }

        var results: [String: SpeakerMatchResult] = [:]

        for (speaker, segments) in speakerSegments {
            guard let embedding = try? extractEmbedding(audioURL: audioURL, segments: segments) else { continue }

            var bestMatch: SpeakerMatchResult?
            var bestScore: Double = 0

            for profile in profiles {
                let similarity = cosineSimilarity(embedding, profile.embedding)
                if similarity > bestScore && similarity >= Self.matchThreshold {
                    bestScore = similarity
                    bestMatch = SpeakerMatchResult(
                        profileName: profile.name,
                        profileID: profile.id,
                        confidence: similarity
                    )
                }
            }

            if let match = bestMatch {
                results[speaker] = match
            }
        }

        return results
    }

    // MARK: - Audio Loading

    /// Read audio file, extract PCM float samples at 16kHz mono
    private func loadAudioSamples(url: URL, startTime: Double, duration: Double) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        let sourceFormat = audioFile.processingFormat

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw VoiceprintError.audioFormatError
        }

        // Calculate frame positions in source file
        let startFrame = AVAudioFramePosition(startTime * sourceFormat.sampleRate)
        let frameCount = AVAudioFrameCount(duration * sourceFormat.sampleRate)

        guard startFrame < audioFile.length else {
            throw VoiceprintError.invalidSegment
        }

        let actualFrameCount = min(frameCount, AVAudioFrameCount(audioFile.length - startFrame))
        audioFile.framePosition = startFrame

        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: actualFrameCount) else {
            throw VoiceprintError.bufferError
        }
        try audioFile.read(into: sourceBuffer, frameCount: actualFrameCount)

        // Convert to 16kHz mono
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw VoiceprintError.audioFormatError
        }

        let targetFrameCount = AVAudioFrameCount(duration * Self.targetSampleRate)
        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCount + 1024) else {
            throw VoiceprintError.bufferError
        }

        var isDone = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if isDone {
                outStatus.pointee = .noDataNow
                return nil
            }
            isDone = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        try converter.convert(to: targetBuffer, error: nil, withInputFrom: inputBlock)

        guard let channelData = targetBuffer.floatChannelData else {
            throw VoiceprintError.bufferError
        }

        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: Int(targetBuffer.frameLength)))
        return samples
    }

    // MARK: - MFCC Pipeline

    /// Apply pre-emphasis filter: y[n] = x[n] - 0.97 * x[n-1]
    private func preEmphasis(_ samples: [Float]) -> [Float] {
        guard samples.count > 1 else { return samples }
        var result = [Float](repeating: 0, count: samples.count)
        result[0] = samples[0]
        for i in 1..<samples.count {
            result[i] = samples[i] - 0.97 * samples[i - 1]
        }
        return result
    }

    /// Frame the signal into overlapping windows
    private func frameSignal(_ samples: [Float]) -> [[Float]] {
        var frames: [[Float]] = []
        var start = 0
        while start + Self.frameLength <= samples.count {
            let frame = Array(samples[start..<(start + Self.frameLength)])
            frames.append(frame)
            start += Self.hopLength
        }
        return frames
    }

    /// Apply Hamming window to a frame
    private func applyHammingWindow(_ frame: [Float]) -> [Float] {
        var window = [Float](repeating: 0, count: frame.count)
        vDSP_hamm_window(&window, vDSP_Length(frame.count), 0)
        var result = [Float](repeating: 0, count: frame.count)
        vDSP_vmul(frame, 1, window, 1, &result, 1, vDSP_Length(frame.count))
        return result
    }

    /// Compute power spectrum via FFT
    private func powerSpectrum(_ frame: [Float]) -> [Float] {
        let n = Self.nFFT
        let log2n = vDSP_Length(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return [Float](repeating: 0, count: n / 2 + 1)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        // Zero-pad frame to nFFT
        var paddedFrame = [Float](repeating: 0, count: n)
        let copyCount = min(frame.count, n)
        paddedFrame[0..<copyCount] = frame[0..<copyCount]

        // Split complex
        var realPart = [Float](repeating: 0, count: n / 2)
        var imagPart = [Float](repeating: 0, count: n / 2)

        // Pack into split complex
        paddedFrame.withUnsafeBufferPointer { bufferPointer in
            bufferPointer.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) { complexPtr in
                var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(n / 2))
            }
        }

        // FFT
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Compute magnitude squared (power spectrum)
        let spectrumSize = n / 2 + 1
        var power = [Float](repeating: 0, count: spectrumSize)

        // DC component
        power[0] = realPart[0] * realPart[0]
        // Nyquist
        if spectrumSize > 1 {
            power[spectrumSize - 1] = imagPart[0] * imagPart[0]
        }

        // Other bins
        for i in 1..<(n / 2) {
            power[i] = realPart[i] * realPart[i] + imagPart[i] * imagPart[i]
        }

        // Scale
        var scale: Float = 1.0 / Float(n)
        vDSP_vsmul(power, 1, &scale, &power, 1, vDSP_Length(spectrumSize))

        return power
    }

    /// Build mel filterbank
    private func melFilterbank() -> [[Float]] {
        let nFilters = Self.nMelFilters
        let nFFT = Self.nFFT
        let sampleRate = Int(Self.targetSampleRate)
        let spectrumSize = nFFT / 2 + 1

        func hzToMel(_ hz: Double) -> Double {
            return 2595.0 * log10(1.0 + hz / 700.0)
        }

        func melToHz(_ mel: Double) -> Double {
            return 700.0 * (pow(10.0, mel / 2595.0) - 1.0)
        }

        let lowMel = hzToMel(0)
        let highMel = hzToMel(Double(sampleRate) / 2.0)

        // nFilters + 2 equally spaced points in mel scale
        var melPoints = [Double](repeating: 0, count: nFilters + 2)
        for i in 0..<(nFilters + 2) {
            melPoints[i] = lowMel + (highMel - lowMel) * Double(i) / Double(nFilters + 1)
        }

        // Convert back to Hz and then to FFT bin indices
        let binPoints = melPoints.map { mel -> Int in
            let hz = melToHz(mel)
            return Int(floor(hz * Double(nFFT) / Double(sampleRate)))
        }

        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: spectrumSize), count: nFilters)

        for i in 0..<nFilters {
            let start = binPoints[i]
            let center = binPoints[i + 1]
            let end = binPoints[i + 2]

            // Rising slope
            if center > start {
                for j in start..<center where j < spectrumSize {
                    filterbank[i][j] = Float(j - start) / Float(center - start)
                }
            }
            // Falling slope
            if end > center {
                for j in center..<end where j < spectrumSize {
                    filterbank[i][j] = Float(end - j) / Float(end - center)
                }
            }
        }

        return filterbank
    }

    /// Apply filterbank, log, DCT to get MFCCs
    private func mfcc(powerSpectrum: [Float], filterbank: [[Float]]) -> [Float] {
        let nFilters = Self.nMelFilters
        let nCoeffs = Self.nMFCCCoeffs

        // Apply mel filterbank
        var melEnergies = [Float](repeating: 0, count: nFilters)
        for i in 0..<nFilters {
            var energy: Float = 0
            vDSP_dotpr(powerSpectrum, 1, filterbank[i], 1, &energy, vDSP_Length(min(powerSpectrum.count, filterbank[i].count)))
            melEnergies[i] = max(energy, 1e-10)
        }

        // Log
        var logEnergies = [Float](repeating: 0, count: nFilters)
        var count = Int32(nFilters)
        vvlogf(&logEnergies, &melEnergies, &count)

        // DCT (Type II) to get MFCCs
        var coeffs = [Float](repeating: 0, count: nFilters)
        for k in 0..<nCoeffs {
            var sum: Float = 0
            for n in 0..<nFilters {
                sum += logEnergies[n] * cos(Float.pi * Float(k) * (Float(n) + 0.5) / Float(nFilters))
            }
            coeffs[k] = sum
        }

        return Array(coeffs.prefix(nCoeffs))
    }

    /// Average multiple MFCC frames into a single embedding vector
    private func averageMFCCs(_ frames: [[Float]]) -> [Double] {
        let nCoeffs = Self.nMFCCCoeffs
        var avg = [Double](repeating: 0, count: nCoeffs)

        for frame in frames {
            for i in 0..<min(frame.count, nCoeffs) {
                avg[i] += Double(frame[i])
            }
        }

        let count = Double(frames.count)
        for i in 0..<nCoeffs {
            avg[i] /= count
        }

        return avg
    }

    /// Cosine similarity between two vectors
    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Double = 0
        var normA: Double = 0
        var normB: Double = 0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    // MARK: - Helpers

    private func capSegments(_ segments: [SpeakerSegment]) -> [SpeakerSegment] {
        var capped: [SpeakerSegment] = []
        var totalDuration: Double = 0

        for segment in segments.prefix(Self.maxSegmentsPerSpeaker) {
            if totalDuration + segment.duration > Self.maxTotalDuration {
                let remaining = Self.maxTotalDuration - totalDuration
                if remaining > 0.5 {
                    capped.append(SpeakerSegment(startTime: segment.startTime, endTime: segment.startTime + remaining))
                }
                break
            }
            capped.append(segment)
            totalDuration += segment.duration
        }

        return capped
    }
}

enum VoiceprintError: LocalizedError {
    case audioFormatError
    case invalidSegment
    case bufferError
    case noAudioData

    var errorDescription: String? {
        switch self {
        case .audioFormatError: return String(localized: "音频格式不支持")
        case .invalidSegment: return String(localized: "无效的音频片段")
        case .bufferError: return String(localized: "音频处理缓冲区错误")
        case .noAudioData: return String(localized: "没有可用的音频数据")
        }
    }
}
