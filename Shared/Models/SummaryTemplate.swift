import Foundation

enum SummaryTemplate: String, CaseIterable, Identifiable {
    case meetingNotes = "meetingNotes"
    case keyPoints = "keyPoints"
    case actionItems = "actionItems"
    case general = "general"
    case chapterSummary = "chapterSummary"
    case classroomNotes = "classroomNotes"
    case podcastInterview = "podcastInterview"
    case brainstorming = "brainstorming"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meetingNotes: return String(localized: "会议纪要")
        case .keyPoints: return String(localized: "关键要点")
        case .actionItems: return String(localized: "行动项清单")
        case .general: return String(localized: "通用摘要")
        case .chapterSummary: return String(localized: "章节摘要")
        case .classroomNotes: return String(localized: "课堂笔记")
        case .podcastInterview: return String(localized: "播客访谈")
        case .brainstorming: return String(localized: "头脑风暴")
        }
    }

    private var isEnglish: Bool { LanguageManager.shared.isEnglish }

    var systemPrompt: String {
        switch self {
        case .meetingNotes:
            return isEnglish ? """
            Please organize the following meeting recording transcription into structured meeting minutes, including:
            1. Meeting topic
            2. Attendees (if identifiable)
            3. Discussion points
            4. Decisions made
            5. Action items
            Use concise language. Output in Markdown format.
            """ : """
            请将以下会议录音转写内容整理为结构化的会议纪要，包含：
            1. 会议主题
            2. 参会人员（如能识别）
            3. 讨论要点
            4. 决议事项
            5. 待办事项
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .keyPoints:
            return isEnglish ? """
            Please extract the key points from the following recording transcription and list them as clear items.
            Summarize each point in one sentence, highlighting the core information.
            Use concise language. Output in Markdown format.
            """ : """
            请提取以下录音转写内容的关键要点，以清晰的条目形式列出。
            每个要点用一句话概括，重点突出核心信息。
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .actionItems:
            return isEnglish ? """
            Please extract all action items and to-dos from the following recording transcription.
            List them in checklist format, including:
            - Specific task
            - Responsible person (if identifiable)
            - Deadline (if mentioned)
            Use concise language. Output in Markdown format.
            """ : """
            请从以下录音转写内容中提取所有行动项和待办事项。
            以清单形式列出，包含：
            - 具体任务
            - 负责人（如能识别）
            - 截止时间（如有提及）
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .general:
            return isEnglish ? """
            Please generate a concise summary of the following recording transcription.
            Summarize the main content, core viewpoints, and important conclusions.
            Use concise language. Output in Markdown format.
            """ : """
            请对以下录音转写内容生成简明扼要的摘要。
            概括主要内容、核心观点和重要结论。
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .chapterSummary:
            return isEnglish ? """
            Please divide the following recording transcription into logical chapters/sections based on topic changes.
            For each chapter, provide:
            1. A chapter title
            2. Time range (if timestamps like [MM:SS] are present in the text)
            3. A concise summary of the chapter content
            Use concise language. Output in Markdown format with ## headings for each chapter.
            """ : """
            请将以下录音转写内容按话题变化划分为逻辑章节。
            每个章节包含：
            1. 章节标题
            2. 时间范围（如果文本中包含 [MM:SS] 格式的时间戳）
            3. 该章节内容的简要摘要
            使用简洁的中文输出。请使用 Markdown 格式，用 ## 标题标记每个章节。
            """
        case .classroomNotes:
            return isEnglish ? """
            Please organize the following recording transcription into structured lecture notes, including:
            1. Main topic / course title
            2. Key knowledge points (numbered list)
            3. Important concepts and definitions
            4. Key takeaways and highlights
            5. Homework / after-class tasks (if mentioned)
            Use concise language. Output in Markdown format.
            """ : """
            请将以下录音转写内容整理为结构化的课堂笔记，包含：
            1. 主题/课程标题
            2. 关键知识点（编号列表）
            3. 重要概念和定义
            4. 重点和要点
            5. 课后任务/作业（如有提及）
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .podcastInterview:
            return isEnglish ? """
            Please analyze the following podcast/interview recording transcription and extract:
            1. Guest introduction and background
            2. Key viewpoints and opinions from each speaker
            3. Notable quotes / golden lines
            4. Topic index with brief descriptions
            5. Key takeaways
            Use concise language. Output in Markdown format.
            """ : """
            请分析以下播客/访谈录音转写内容，提取：
            1. 嘉宾介绍和背景
            2. 每位发言人的核心观点
            3. 金句摘录
            4. 话题索引及简要描述
            5. 关键收获
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .brainstorming:
            return isEnglish ? """
            Please organize the following brainstorming session recording transcription:
            1. Group all ideas by theme/category
            2. For each idea, briefly assess feasibility (high/medium/low)
            3. Highlight the most promising ideas
            4. Suggest action priorities (what to pursue first)
            5. List any unresolved questions or concerns
            Use concise language. Output in Markdown format.
            """ : """
            请整理以下头脑风暴会议录音转写内容：
            1. 按主题/类别对所有想法进行分组
            2. 对每个想法简要评估可行性（高/中/低）
            3. 标注最有前景的想法
            4. 建议行动优先级（优先推进哪些）
            5. 列出未解决的问题或疑虑
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        }
    }

    var icon: String {
        switch self {
        case .meetingNotes: return "doc.text"
        case .keyPoints: return "list.bullet.rectangle"
        case .actionItems: return "checklist"
        case .general: return "text.quote"
        case .chapterSummary: return "book.pages"
        case .classroomNotes: return "book.fill"
        case .podcastInterview: return "mic.badge.plus"
        case .brainstorming: return "lightbulb.fill"
        }
    }
}
