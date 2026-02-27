import SwiftUI

enum SummaryTemplate: String, CaseIterable, Identifiable {
    case meetingNotes = "会议纪要"
    case keyPoints = "关键要点"
    case actionItems = "行动项清单"
    case general = "通用摘要"

    var id: String { rawValue }

    var systemPrompt: String {
        switch self {
        case .meetingNotes:
            return """
            请将以下会议录音转写内容整理为结构化的会议纪要，包含：
            1. 会议主题
            2. 参会人员（如能识别）
            3. 讨论要点
            4. 决议事项
            5. 待办事项
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .keyPoints:
            return """
            请提取以下录音转写内容的关键要点，以清晰的条目形式列出。
            每个要点用一句话概括，重点突出核心信息。
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .actionItems:
            return """
            请从以下录音转写内容中提取所有行动项和待办事项。
            以清单形式列出，包含：
            - 具体任务
            - 负责人（如能识别）
            - 截止时间（如有提及）
            使用简洁的中文输出。请使用 Markdown 格式输出。
            """
        case .general:
            return """
            请对以下录音转写内容生成简明扼要的摘要。
            概括主要内容、核心观点和重要结论。
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
        }
    }
}

struct SummaryView: View {
    @Bindable var recording: Recording
    @State private var aiService = AIService()
    @State private var selectedTemplate: SummaryTemplate = .general
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if recording.isSummarizing {
                    ProgressView("正在生成摘要...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let summary = recording.summary {
                    // Template selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(SummaryTemplate.allCases) { template in
                                Button {
                                    selectedTemplate = template
                                    regenerateSummary()
                                } label: {
                                    Label(template.rawValue, systemImage: template.icon)
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(selectedTemplate == template ? .blue : .secondary)
                            }
                        }
                        .padding(.horizontal)
                    }

                    if let attributed = try? AttributedString(markdown: summary) {
                        Text(attributed)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                    } else {
                        Text(summary)
                            .font(.body)
                            .textSelection(.enabled)
                            .padding()
                    }
                } else if let error {
                    ContentUnavailableView {
                        Label("生成失败", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("重试") {
                            self.error = nil
                            generateSummary()
                        }
                    }
                } else {
                    noTranscriptState
                }
            }
        }
    }

    private var noTranscriptState: some View {
        VStack(spacing: 16) {
            if recording.transcription == nil {
                Image(systemName: "text.badge.xmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("请先完成语音转写")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                Text("选择摘要模板")
                    .font(.headline)

                ForEach(SummaryTemplate.allCases) { template in
                    Button {
                        selectedTemplate = template
                        generateSummary()
                    } label: {
                        Label(template.rawValue, systemImage: template.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal)
    }

    private func generateSummary() {
        guard let transcription = recording.transcription else { return }
        recording.isSummarizing = true

        Task {
            do {
                let summary = try await aiService.generateSummary(
                    transcription: transcription,
                    template: selectedTemplate
                )
                recording.summary = summary
            } catch {
                self.error = error.localizedDescription
            }
            recording.isSummarizing = false
        }
    }

    private func regenerateSummary() {
        recording.summary = nil
        generateSummary()
    }
}
