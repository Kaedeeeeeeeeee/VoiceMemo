import Foundation
import AVFoundation
import Observation

enum TranscriptionPhase {
    case idle, uploading, transcribing, polling
}

@Observable
final class TranscriptionService {
    private let proxyBaseURL = APIConfig.proxyBaseURL
    private let proxyAuthToken = APIConfig.proxyAuthToken
    var currentPhase: TranscriptionPhase = .idle
    var pollingElapsedSeconds: Int = 0
    var phaseProgress: Double?
    var currentChunk: Int = 0
    var totalChunks: Int = 0

    private static let maxFileSize: Int64 = 25 * 1024 * 1024 // 25MB
    private static let chunkDurationSeconds: Double = 600 // 10 minutes

    func transcribe(audioURL: URL) async throws -> String {
        let result = try await transcribeWithUtterances(audioURL: audioURL)
        return result.formattedText
    }

    func transcribeWithUtterances(audioURL: URL) async throws -> TranscriptionResult {
        currentPhase = .idle
        phaseProgress = nil
        pollingElapsedSeconds = 0
        currentChunk = 0
        totalChunks = 0

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64) ?? 0

        if fileSize > Self.maxFileSize {
            return try await transcribeChunkedWithUtterances(audioURL: audioURL)
        }

        return try await transcribeSingleWithUtterances(audioURL: audioURL)
    }

    // MARK: - Single file transcription

    private func transcribeSingleWithUtterances(audioURL: URL) async throws -> TranscriptionResult {
        currentPhase = .uploading
        phaseProgress = 0
        let uploadURL = try await uploadAudio(fileURL: audioURL)

        currentPhase = .transcribing
        phaseProgress = nil
        let transcriptID = try await requestTranscription(uploadURL: uploadURL)

        currentPhase = .polling
        pollingElapsedSeconds = 0
        let rawUtterances = try await pollForResult(id: transcriptID)

        currentPhase = .idle
        phaseProgress = nil
        pollingElapsedSeconds = 0

        let formattedText = formatUtterances(rawUtterances)
        let speakerUtterances = parseSpeakerUtterances(rawUtterances)
        return TranscriptionResult(formattedText: formattedText, utterances: speakerUtterances)
    }

    // MARK: - Chunked transcription for large files

    private func transcribeChunkedWithUtterances(audioURL: URL) async throws -> TranscriptionResult {
        let chunks = try await splitAudio(url: audioURL, chunkDuration: Self.chunkDurationSeconds)
        totalChunks = chunks.count
        var allUtterances: [[String: Any]] = []
        var timeOffset: Int = 0 // milliseconds offset for each chunk

        for (index, chunkURL) in chunks.enumerated() {
            currentChunk = index + 1

            currentPhase = .uploading
            phaseProgress = 0
            let uploadURL = try await uploadAudio(fileURL: chunkURL)

            currentPhase = .transcribing
            phaseProgress = nil
            let transcriptID = try await requestTranscription(uploadURL: uploadURL)

            currentPhase = .polling
            pollingElapsedSeconds = 0
            let utterances = try await pollForResult(id: transcriptID)

            // Offset timestamps by accumulated chunk duration
            let offsetUtterances = utterances.map { utterance -> [String: Any] in
                var u = utterance
                if let start = u["start"] as? Int {
                    u["start"] = start + timeOffset
                }
                if let end = u["end"] as? Int {
                    u["end"] = end + timeOffset
                }
                return u
            }
            allUtterances.append(contentsOf: offsetUtterances)

            // Calculate actual chunk duration from the last utterance's end time, or use fixed duration
            if let lastEnd = utterances.compactMap({ $0["end"] as? Int }).max() {
                timeOffset += lastEnd
            } else {
                timeOffset += Int(Self.chunkDurationSeconds * 1000)
            }

            // Clean up chunk file
            try? FileManager.default.removeItem(at: chunkURL)
        }

        currentPhase = .idle
        phaseProgress = nil
        currentChunk = 0
        totalChunks = 0

        let formattedText = formatUtterances(allUtterances)
        let speakerUtterances = parseSpeakerUtterances(allUtterances)
        return TranscriptionResult(formattedText: formattedText, utterances: speakerUtterances)
    }

    // MARK: - Split audio into chunks

    private func splitAudio(url: URL, chunkDuration: Double) async throws -> [URL] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)
        let chunkCount = Int(ceil(totalSeconds / chunkDuration))

        if chunkCount <= 1 {
            return [url]
        }

        var chunkURLs: [URL] = []
        let tempDir = FileManager.default.temporaryDirectory

        for i in 0..<chunkCount {
            let startTime = CMTime(seconds: Double(i) * chunkDuration, preferredTimescale: 600)
            let endSeconds = min(Double(i + 1) * chunkDuration, totalSeconds)
            let endTime = CMTime(seconds: endSeconds, preferredTimescale: 600)
            let timeRange = CMTimeRange(start: startTime, end: endTime)

            let chunkURL = tempDir.appendingPathComponent("chunk_\(i)_\(UUID().uuidString).m4a")

            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw TranscriptionError.chunkingFailed
            }

            exportSession.outputURL = chunkURL
            exportSession.outputFileType = .m4a
            exportSession.timeRange = timeRange

            await exportSession.export()

            guard exportSession.status == .completed else {
                throw TranscriptionError.chunkingFailed
            }

            chunkURLs.append(chunkURL)
        }

        return chunkURLs
    }

    // MARK: - Upload audio file with progress

    private func uploadAudio(fileURL: URL) async throws -> String {
        guard let url = URL(string: "\(proxyBaseURL)/assemblyai/upload") else {
            throw TranscriptionError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(proxyAuthToken, forHTTPHeaderField: "X-App-Token")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)

        let (data, response) = try await uploadWithProgress(request: request, data: audioData)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw TranscriptionError.apiError(statusCode: statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uploadURL = json["upload_url"] as? String else {
            throw TranscriptionError.invalidResponse
        }

        return uploadURL
    }

    private func uploadWithProgress(request: URLRequest, data: Data) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = UploadProgressDelegate { [weak self] progress in
                Task { @MainActor in
                    self?.phaseProgress = progress
                }
            }

            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            let task = session.uploadTask(with: request, from: data) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, let response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: TranscriptionError.invalidResponse)
                }
            }
            task.resume()
        }
    }

    // MARK: - Request transcription with speaker diarization

    private func requestTranscription(uploadURL: String) async throws -> String {
        guard let url = URL(string: "\(proxyBaseURL)/assemblyai/transcript") else {
            throw TranscriptionError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(proxyAuthToken, forHTTPHeaderField: "X-App-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "audio_url": uploadURL,
            "speaker_labels": true,
            "speech_models": ["universal-2"]
        ]

        let selectedLanguage = LanguageManager.shared.transcriptionLanguage
        if let code = selectedLanguage.languageCode {
            body["language_code"] = code
        } else {
            body["language_detection"] = true
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw TranscriptionError.apiError(statusCode: statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? String else {
            throw TranscriptionError.invalidResponse
        }

        return id
    }

    // MARK: - Poll for result

    private func pollForResult(id: String) async throws -> [[String: Any]] {
        guard let url = URL(string: "\(proxyBaseURL)/assemblyai/transcript/\(id)") else {
            throw TranscriptionError.invalidResponse
        }
        pollingElapsedSeconds = 0

        while true {
            var request = URLRequest(url: url)
            request.setValue(proxyAuthToken, forHTTPHeaderField: "X-App-Token")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw TranscriptionError.apiError(statusCode: statusCode, message: errorBody)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else {
                throw TranscriptionError.invalidResponse
            }

            if status == "completed" {
                phaseProgress = 1.0
                if let utterances = json["utterances"] as? [[String: Any]] {
                    return utterances
                }
                // No utterances — fall back to full text
                if let text = json["text"] as? String, !text.isEmpty {
                    return [["speaker": "A", "text": text]]
                }
                return []
            } else if status == "error" {
                let errorMessage = json["error"] as? String ?? "转写失败"
                throw TranscriptionError.transcriptionFailed(message: errorMessage)
            }

            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            pollingElapsedSeconds += 3
            // Asymptotic progress curve: approaches 1.0 but never reaches it
            phaseProgress = 1.0 - exp(-Double(pollingElapsedSeconds) / 120.0)
        }
    }

    // MARK: - Format utterances

    private func formatUtterances(_ utterances: [[String: Any]]) -> String {
        if utterances.isEmpty { return "" }

        // Map speaker IDs (A, B, C...) to display labels
        var speakerMap: [String: String] = [:]
        var nextLabel = 0

        return utterances.compactMap { utterance -> String? in
            guard let speaker = utterance["speaker"] as? String,
                  let text = utterance["text"] as? String else { return nil }

            if speakerMap[speaker] == nil {
                let scalar = UnicodeScalar(UInt32(UnicodeScalar("A").value) + UInt32(nextLabel))
                let label = scalar.map { String($0) } ?? String(nextLabel)
                speakerMap[speaker] = label
                nextLabel += 1
            }

            let displayLabel = speakerMap[speaker, default: "?"]
            let prefix = "【" + LanguageManager.shared.speakerLabel(displayLabel) + "】"

            // Format timestamp from utterance start time (milliseconds)
            var timestamp = ""
            if let startMs = utterance["start"] as? Int {
                let totalSeconds = startMs / 1000
                let minutes = totalSeconds / 60
                let seconds = totalSeconds % 60
                timestamp = String(format: "[%02d:%02d] ", minutes, seconds)
            }

            return "\(timestamp)\(prefix)\(text)"
        }.joined(separator: "\n\n")
    }

    /// Parse raw utterance dicts into typed SpeakerUtterance array
    private func parseSpeakerUtterances(_ utterances: [[String: Any]]) -> [SpeakerUtterance] {
        // Build the same speaker map as formatUtterances for consistent labels
        var speakerMap: [String: String] = [:]
        var nextLabel = 0

        return utterances.compactMap { utterance -> SpeakerUtterance? in
            guard let speaker = utterance["speaker"] as? String,
                  let text = utterance["text"] as? String else { return nil }

            if speakerMap[speaker] == nil {
                let scalar = UnicodeScalar(UInt32(UnicodeScalar("A").value) + UInt32(nextLabel))
                let label = scalar.map { String($0) } ?? String(nextLabel)
                speakerMap[speaker] = label
                nextLabel += 1
            }

            let displayLabel = speakerMap[speaker, default: "?"]
            let startMs = utterance["start"] as? Int ?? 0
            let endMs = utterance["end"] as? Int ?? startMs

            return SpeakerUtterance(speaker: displayLabel, text: text, startMs: startMs, endMs: endMs)
        }
    }
}

// MARK: - Upload Progress Delegate

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        onProgress(progress)
    }
}

enum TranscriptionError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case transcriptionFailed(message: String)
    case chunkingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "服务器返回了无效的响应")
        case .apiError(let statusCode, let message):
            return String(localized: "API 错误 (\(statusCode)): \(message)")
        case .transcriptionFailed(let message):
            return String(localized: "转写失败: \(message)")
        case .chunkingFailed:
            return String(localized: "音频分片失败")
        }
    }
}
