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

    /// Hard instruction appended to every system prompt so GPT replies in
    /// the user's selected app language even when prompt templates have not
    /// yet been translated (e.g. Japanese falls through to Chinese templates
    /// but must still produce Japanese output).
    private var outputLanguageDirective: String {
        let lang = LanguageManager.shared.aiOutputLanguage
        return "\n\nIMPORTANT: You MUST respond entirely in \(lang), regardless of the language of the user's input or any instructions above."
    }

    func generateSummary(transcription: String, template: SummaryTemplate) async throws -> String {
        try await generateSummary(transcription: transcription, systemPrompt: template.systemPrompt)
    }

    func generateSummary(transcription: String, systemPrompt: String) async throws -> String {
        let fullPrompt = systemPrompt + outputLanguageDirective
        let userPrefix: String
        switch LanguageManager.shared.resolvedAppLanguage {
        case .english: userPrefix = "Recording transcription:"
        case .japanese: userPrefix = "録音の文字起こし："
        default: userPrefix = "录音转写内容："
        }
        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": fullPrompt
            ],
            [
                "role": "user",
                "content": "\(userPrefix)\n\(transcription)"
            ]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func polishTranscription(_ rawText: String) async throws -> String {
        var systemPrompt: String

        if isOtherLanguage {
            let langName = transcriptionLanguage.englishName
            systemPrompt = """
            You are a professional transcription polishing assistant. The following text is in \(langName). Please polish it:
            1. Add correct punctuation
            2. Fix obvious speech recognition errors, especially proper nouns
            3. Remove filler words and verbal tics that add no meaning
            4. Adjust word order and sentence structure for clarity without altering the speaker's intent
            5. Remove redundant phrases, false starts, and unnecessary repetitions
            6. Add paragraph breaks within each speaker's speech to improve readability
            7. Preserve each speaker's key points and intent, but express them in clear, concise language
            8. You must preserve all 【Speaker X】, 【说话人X】 or 【話者X】 markers — do not modify, delete, or merge them
            9. If the text contains mixed languages, preserve each language as-is and fix recognition errors in all languages
            10. Output only the polished text, no explanations
            """
        } else {
            let speakerTag = "【" + LanguageManager.shared.speakerLabel("X") + "】"
            systemPrompt = isEnglish ? """
            You are a professional transcription polishing assistant. The user will provide raw speech-to-text output. Please polish it:
            1. Add correct punctuation (commas, periods, question marks, exclamation marks, etc.)
            2. Fix obvious speech recognition errors, especially proper nouns (names, places, game titles, technical terms, etc.)
            3. Remove filler words and verbal tics (um, uh, like, you know, so, etc.) that add no meaning
            4. Adjust word order and sentence structure for clarity — make the text read naturally without altering the speaker's intent
            5. Remove redundant phrases, false starts, and unnecessary repetitions, keeping only the meaningful content
            6. Add paragraph breaks within each speaker's speech to improve readability
            7. Preserve each speaker's key points and intent, but express them in clear, concise language
            8. You must preserve all \(speakerTag) markers — do not modify, delete, or merge them
            9. If the text contains mixed languages (e.g., Chinese and English), preserve each language as-is and fix recognition errors in both languages
            10. Output only the polished text, no explanations
            """ : """
            你是一个专业的语音转写润色助手。用户会提供一段语音识别的原始文本，请你对其进行深度润色处理：
            1. 添加正确的标点符号（逗号、句号、问号、感叹号等）
            2. 修正明显的语音识别错误，特别是专有名词（游戏名、角色名、人名、地名、术语等）
            3. 删除语气词和口头禅（"呃"、"嗯"、"啊"、"那个"、"就是说"、"然后呢"等），只保留有意义的内容
            4. 调整语序，优化句子结构，使表达更通顺流畅，但不改变说话人的原意
            5. 去掉重复、冗余的表达和无意义的信息，保留核心内容
            6. 在每个说话人的发言内适当分段，提升可读性
            7. 保留每位说话人的核心观点和意图，用简洁清晰的语言重新表达
            8. 必须保留所有【说话人X】标记，不要修改、删除或合并这些标记
            9. 如果文本中包含中英混合内容，请保留各语言原文并分别修正识别错误，不要将英文翻译成中文或将中文翻译成英文
            10. 只输出润色后的文本，不要输出任何解释
            """
        }

        systemPrompt += outputLanguageDirective

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": rawText]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func generateTitle(transcription: String) async throws -> String {
        var systemPrompt: String

        if isOtherLanguage {
            let langName = transcriptionLanguage.englishName
            systemPrompt = "Generate a short title (under 8 words) in \(langName) for this recording based on its content. Output only the title itself."
        } else {
            switch LanguageManager.shared.resolvedAppLanguage {
            case .english:
                systemPrompt = "Generate a short title (under 8 words) for this recording based on its content. Output only the title itself."
            case .japanese:
                systemPrompt = "録音の内容に基づいて、短いタイトル（15文字以内）を日本語で生成してください。タイトル本文のみを出力してください。"
            default:
                systemPrompt = "根据录音内容生成一个简短的中文标题（10字以内），只输出标题本身"
            }
        }

        systemPrompt += outputLanguageDirective

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": transcription]
        ]

        return try await callOpenAIAPI(messages: messages)
    }

    func knowledgeBaseChat(context: String, messages: [ConversationMessage]) async throws -> String {
        let base: String
        switch LanguageManager.shared.resolvedAppLanguage {
        case .english:
            base = """
            You are an intelligent recording knowledge base assistant. The user will ask questions and you should answer based on the following context assembled from their recordings. When citing information, mention the recording title so the user knows the source.

            If the context does not contain enough information to answer the question, say so honestly.

            Recording context:
            \(context)
            """
        case .japanese:
            base = """
            あなたは優秀な録音ナレッジベースアシスタントです。ユーザーの録音から整理された以下のコンテキストに基づいて質問に答えてください。情報を引用する際は録音タイトルにも触れ、出典を明示してください。

            コンテキストに十分な情報がない場合は、その旨を正直に伝えてください。

            録音コンテキスト：
            \(context)
            """
        default:
            base = """
            你是一个智能录音知识库助手。用户会向你提问，请根据以下从他们的录音中整理的上下文来回答。引用信息时请提及录音标题，让用户知道来源。

            如果上下文中没有足够的信息来回答问题，请诚实地说明。

            录音上下文：
            \(context)
            """
        }
        let systemContext = base + outputLanguageDirective

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
        let base: String
        switch LanguageManager.shared.resolvedAppLanguage {
        case .english:
            base = """
            You are an intelligent recording assistant. The user will ask you questions based on the following recording transcription. Please answer accurately based on the transcription.

            Recording transcription:
            \(transcription)
            """
        case .japanese:
            base = """
            あなたは優秀な録音アシスタントです。ユーザーは以下の録音文字起こしに基づいて質問します。文字起こしの内容に基づいて正確に答えてください。

            録音文字起こし：
            \(transcription)
            """
        default:
            base = """
            你是一个智能录音助手。用户会基于以下录音转写内容向你提问。请根据转写内容准确回答。

            录音转写内容：
            \(transcription)
            """
        }
        let systemContext = base + outputLanguageDirective

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
        let systemPrompt: String
        switch LanguageManager.shared.resolvedAppLanguage {
        case .english:
            systemPrompt = """
            You are a recording classifier. Based on the transcription, return 1-3 tags from this list: Meeting, Lecture, Interview, Quick Thought, Phone Call, Podcast, Brainstorm, Memo, Other.
            Return ONLY a JSON array of strings, e.g. ["Meeting","Brainstorm"]. No explanation.
            """
        case .japanese:
            systemPrompt = """
            あなたは録音分類器です。文字起こしの内容に基づいて、以下のタグから1〜3個選んでください：会議、講義、インタビュー、ひらめき、通話、ポッドキャスト、ブレインストーミング、メモ、その他。
            JSON配列のみを返してください。例：["会議","ひらめき"]。説明は一切不要です。
            """
        default:
            systemPrompt = """
            你是一个录音分类器。根据转写内容，从以下标签中选择1-3个：会议、课程、访谈、闪念、通话、播客、头脑风暴、备忘、其他。
            只返回JSON数组，例如 ["会议","闪念"]。不要输出任何解释。
            """
        }

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
        guard let url = URL(string: "\(proxyBaseURL)/openai/v1/chat/completions") else {
            throw AIServiceError.invalidResponse
        }
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
