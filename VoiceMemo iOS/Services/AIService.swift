import Foundation
import Observation

@Observable
final class AIService {
    private let proxyBaseURL = APIConfig.proxyBaseURL
    private let proxyAuthToken = APIConfig.proxyAuthToken

    struct ConversationMessage {
        let role: String
        let content: String
    }

    private var isEnglish: Bool { LanguageManager.shared.isEnglish }

    private var transcriptionLanguage: TranscriptionLanguage {
        LanguageManager.shared.transcriptionLanguage
    }

    /// Whether the transcription language is neither Chinese nor English
    private var isOtherLanguage: Bool {
        let lang = transcriptionLanguage
        return lang != .autoDetect && lang != .chinese && lang != .english
    }

    func generateSummary(transcription: String, template: SummaryTemplate) async throws -> String {
        try await generateSummary(transcription: transcription, systemPrompt: template.systemPrompt)
    }

    func generateSummary(transcription: String, systemPrompt: String) async throws -> String {
        let userPrefix = isEnglish ? "Recording transcription:" : "录音转写内容："
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": systemPrompt
            ],
            [
                "role": "user",
                "content": "\(userPrefix)\n\(transcription)"
            ]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func polishTranscription(_ rawText: String) async throws -> String {
        let systemPrompt: String

        if isOtherLanguage {
            let langName = transcriptionLanguage.englishName
            systemPrompt = """
            You are a professional transcription polishing assistant. The following text is in \(langName). Please polish it:
            1. Add correct punctuation
            2. Fix obvious speech recognition errors, especially proper nouns
            3. Add paragraph breaks within each speaker's speech to improve readability
            4. Preserve the original conversational tone — do not rewrite into formal prose
            5. Do not add content that wasn't in the original, do not remove original content
            6. You must preserve all 【Speaker X】 or 【说话人X】 markers — do not modify, delete, or merge them
            7. If the text contains mixed languages, preserve each language as-is and fix recognition errors in all languages
            8. Output only the polished text, no explanations
            """
        } else {
            let speakerTag = isEnglish ? "【Speaker X】" : "【说话人X】"
            systemPrompt = isEnglish ? """
            You are a professional transcription polishing assistant. The user will provide raw speech-to-text output. Please polish it:
            1. Add correct punctuation (commas, periods, question marks, exclamation marks, etc.)
            2. Fix obvious speech recognition errors, especially proper nouns (names, places, game titles, technical terms, etc.)
            3. Add paragraph breaks within each speaker's speech to improve readability
            4. Preserve the original conversational tone and each speaker's voice — do not rewrite into formal prose
            5. Do not add content that wasn't in the original, do not remove original content
            6. You must preserve all \(speakerTag) markers — do not modify, delete, or merge them
            7. If the text contains mixed languages (e.g., Chinese and English), preserve each language as-is and fix recognition errors in both languages
            8. Output only the polished text, no explanations
            """ : """
            你是一个专业的语音转写润色助手。用户会提供一段语音识别的原始文本，请你对其进行润色处理：
            1. 添加正确的标点符号（逗号、句号、问号、感叹号等）
            2. 修正明显的语音识别错误，特别是专有名词（游戏名、角色名、人名、地名、术语等）
            3. 在每个说话人的发言内适当分段，提升可读性
            4. 保持原文的口语风格和说话人的语气，不要改写成书面语
            5. 不要添加原文没有的内容，不要删除原文的内容
            6. 必须保留所有【说话人X】标记，不要修改、删除或合并这些标记
            7. 如果文本中包含中英混合内容，请保留各语言原文并分别修正识别错误，不要将英文翻译成中文或将中文翻译成英文
            8. 只输出润色后的文本，不要输出任何解释
            """
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": rawText]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func generateTitle(transcription: String) async throws -> String {
        let systemPrompt: String

        if isOtherLanguage {
            let langName = transcriptionLanguage.englishName
            systemPrompt = "Generate a short title (under 8 words) in \(langName) for this recording based on its content. Output only the title itself."
        } else {
            systemPrompt = isEnglish
                ? "Generate a short title (under 8 words) for this recording based on its content. Output only the title itself."
                : "根据录音内容生成一个简短的中文标题（10字以内），只输出标题本身"
        }

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": transcription]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func knowledgeBaseChat(context: String, messages: [ConversationMessage]) async throws -> String {
        let systemContext = isEnglish ? """
        You are an intelligent recording knowledge base assistant. The user will ask questions and you should answer based on the following context assembled from their recordings. When citing information, mention the recording title so the user knows the source.

        If the context does not contain enough information to answer the question, say so honestly.

        Recording context:
        \(context)
        """ : """
        你是一个智能录音知识库助手。用户会向你提问，请根据以下从他们的录音中整理的上下文来回答。引用信息时请提及录音标题，让用户知道来源。

        如果上下文中没有足够的信息来回答问题，请诚实地说明。

        录音上下文：
        \(context)
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

    func chat(transcription: String, messages: [ConversationMessage]) async throws -> String {
        let systemContext = isEnglish ? """
        You are an intelligent recording assistant. The user will ask you questions based on the following recording transcription. Please answer accurately based on the transcription.

        Recording transcription:
        \(transcription)
        """ : """
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

    func classifyRecording(transcription: String) async throws -> [String] {
        let systemPrompt = isEnglish
            ? """
            You are a recording classifier. Based on the transcription, return 1-3 tags from this list: Meeting, Lecture, Interview, Quick Thought, Phone Call, Podcast, Brainstorm, Memo, Other.
            Return ONLY a JSON array of strings, e.g. ["Meeting","Brainstorm"]. No explanation.
            """
            : """
            你是一个录音分类器。根据转写内容，从以下标签中选择1-3个：会议、课程、访谈、闪念、通话、播客、头脑风暴、备忘、其他。
            只返回JSON数组，例如 ["会议","闪念"]。不要输出任何解释。
            """

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": String(transcription.prefix(2000))]
        ]

        let result = try await callOpenAIAPI(messages: messages)
        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = cleaned.data(using: .utf8),
           let tags = try? JSONDecoder().decode([String].self, from: data) {
            return Array(tags.prefix(3))
        }
        return []
    }

    private func callOpenAIAPI(messages: [[String: String]]) async throws -> String {
        let url = URL(string: "\(proxyBaseURL)/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(proxyAuthToken, forHTTPHeaderField: "X-App-Token")
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
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: "服务器返回了无效的响应")
        case .apiError(let statusCode, let message):
            return String(localized: "API 错误 (\(statusCode)): \(message)")
        }
    }
}
