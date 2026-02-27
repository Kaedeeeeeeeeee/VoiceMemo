import Foundation
import Observation

@Observable
final class AIService {
    private let apiKey = APIConfig.openAIKey

    struct ConversationMessage {
        let role: String
        let content: String
    }

    func generateSummary(transcription: String, template: SummaryTemplate) async throws -> String {
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": template.systemPrompt
            ],
            [
                "role": "user",
                "content": "录音转写内容：\n\(transcription)"
            ]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func polishTranscription(_ rawText: String) async throws -> String {
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": """
                你是一个专业的语音转写润色助手。用户会提供一段语音识别的原始文本，请你对其进行润色处理：
                1. 添加正确的标点符号（逗号、句号、问号、感叹号等）
                2. 修正明显的语音识别错误，特别是专有名词（游戏名、角色名、人名、地名、术语等）
                3. 适当分段，提升可读性
                4. 保持原文的口语风格和说话人的语气，不要改写成书面语
                5. 不要添加原文没有的内容，不要删除原文的内容
                6. 只输出润色后的文本，不要输出任何解释
                """
            ],
            [
                "role": "user",
                "content": rawText
            ]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func generateTitle(transcription: String) async throws -> String {
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": "根据录音内容生成一个简短的中文标题（10字以内），只输出标题本身"
            ],
            [
                "role": "user",
                "content": transcription
            ]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func chat(transcription: String, messages: [ConversationMessage]) async throws -> String {
        let systemContext = """
        你是一个智能录音助手。用户会基于以下录音转写内容向你提问。请根据转写内容准确回答。

        录音转写内容：
        \(transcription)
        """

        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemContext]
        ]

        for message in messages {
            apiMessages.append([
                "role": message.role,
                "content": message.content
            ])
        }

        return try await callOpenAIAPI(messages: apiMessages)
    }

    private func callOpenAIAPI(messages: [[String: String]]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o",
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return content
    }


}

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "未设置 OpenAI API Key。请在设置中配置。"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .apiError(let statusCode, let message):
            return "API 错误 (\(statusCode)): \(message)"
        }
    }
}
