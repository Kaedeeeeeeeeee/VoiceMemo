import Foundation
import Observation

enum TranscriptionPhase {
    case idle, uploading, transcribing, polling
}

@Observable
final class TranscriptionService {
    private let apiKey = APIConfig.assemblyAIKey
    private let baseURL = "https://api.assemblyai.com/v2"
    var currentPhase: TranscriptionPhase = .idle

    func transcribe(audioURL: URL) async throws -> String {
        guard !apiKey.isEmpty, apiKey != "YOUR_ASSEMBLYAI_API_KEY" else {
            throw TranscriptionError.missingAPIKey
        }

        currentPhase = .uploading
        let uploadURL = try await uploadAudio(fileURL: audioURL)

        currentPhase = .transcribing
        let transcriptID = try await requestTranscription(uploadURL: uploadURL)

        currentPhase = .polling
        let utterances = try await pollForResult(id: transcriptID)

        currentPhase = .idle
        return formatUtterances(utterances)
    }

    // MARK: - Upload audio file

    private func uploadAudio(fileURL: URL) async throws -> String {
        let url = URL(string: "\(baseURL)/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

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

    // MARK: - Request transcription with speaker diarization

    private func requestTranscription(uploadURL: String) async throws -> String {
        let url = URL(string: "\(baseURL)/transcript")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "audio_url": uploadURL,
            "speaker_labels": true,
            "language_code": "zh",
            "speech_models": ["universal-2"]
        ]
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
        let url = URL(string: "\(baseURL)/transcript/\(id)")!

        while true {
            var request = URLRequest(url: url)
            request.setValue(apiKey, forHTTPHeaderField: "authorization")

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
                let label = String(UnicodeScalar("A".unicodeScalars.first!.value + UInt32(nextLabel))!)
                speakerMap[speaker] = label
                nextLabel += 1
            }

            let displayLabel = speakerMap[speaker]!
            return "【说话人\(displayLabel)】\(text)"
        }.joined(separator: "\n\n")
    }
}

enum TranscriptionError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case transcriptionFailed(message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未设置 AssemblyAI API Key。请在 APIConfig 中配置。"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .apiError(let statusCode, let message):
            return "API 错误 (\(statusCode)): \(message)"
        case .transcriptionFailed(let message):
            return "转写失败: \(message)"
        }
    }
}
