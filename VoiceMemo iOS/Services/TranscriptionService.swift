import Foundation
import AVFoundation
import Observation

@Observable
final class TranscriptionService {
    private let apiKey = APIConfig.openAIKey
    private let maxFileSize: Int64 = 25 * 1024 * 1024 // 25MB
    private let chunkDuration: TimeInterval = 10 * 60 // 10 minutes

    func transcribe(audioURL: URL) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TranscriptionError.missingAPIKey
        }

        let fileSize = try FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int64 ?? 0

        if fileSize <= maxFileSize {
            return try await transcribeSingleFile(audioURL: audioURL)
        } else {
            return try await transcribeInChunks(audioURL: audioURL)
        }
    }

    private func transcribeInChunks(audioURL: URL) async throws -> String {
        let asset = AVURLAsset(url: audioURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        var results: [String] = []
        var startTime: TimeInterval = 0
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        var chunkIndex = 0
        while startTime < totalSeconds {
            let endTime = min(startTime + chunkDuration, totalSeconds)
            let chunkURL = tempDir.appendingPathComponent("chunk_\(chunkIndex).m4a")

            try await exportChunk(from: audioURL, to: chunkURL, startTime: startTime, endTime: endTime)

            let text = try await transcribeSingleFile(audioURL: chunkURL)
            if !text.isEmpty {
                results.append(text)
            }

            startTime = endTime
            chunkIndex += 1
        }

        return results.joined(separator: "")
    }

    private func exportChunk(from sourceURL: URL, to outputURL: URL, startTime: TimeInterval, endTime: TimeInterval) async throws {
        let asset = AVURLAsset(url: sourceURL)

        let startCMTime = CMTime(seconds: startTime, preferredTimescale: 600)
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: startCMTime, end: endCMTime)

        let composition = AVMutableComposition()
        guard let track = try await asset.loadTracks(withMediaType: .audio).first,
              let compositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw TranscriptionError.exportFailed
        }
        try compositionTrack.insertTimeRange(timeRange, of: track, at: .zero)

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.exportFailed
        }
        try await session.export(to: outputURL, as: .m4a)
    }

    private func transcribeSingleFile(audioURL: URL) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: audioURL)
        var body = Data()

        // model field
        body.appendMultipartField(name: "model", value: "whisper-1", boundary: boundary)

        // language field (optional, helps with accuracy)
        body.appendMultipartField(name: "language", value: "zh", boundary: boundary)

        // response_format
        body.appendMultipartField(name: "response_format", value: "text", boundary: boundary)

        // audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw TranscriptionError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum TranscriptionError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未设置 OpenAI API Key。请在设置中配置。"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .apiError(let statusCode, let message):
            return "API 错误 (\(statusCode)): \(message)"
        case .exportFailed:
            return "音频分片导出失败"
        }
    }
}

extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
