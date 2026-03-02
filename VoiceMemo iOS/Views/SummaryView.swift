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
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if recording.isSummarizing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(GlassTheme.accent)
                            .scaleEffect(1.2)
                        Text("正在生成摘要...")
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .glassCard()
                    .padding()
                } else if let summary = recording.summary {
                    // Template selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SummaryTemplate.allCases) { template in
                                GlassChip(
                                    title: template.rawValue,
                                    isActive: selectedTemplate == template
                                ) {
                                    selectedTemplate = template
                                    if let cached = recording.summaryCache[template.rawValue] {
                                        recording.summary = cached
                                    } else {
                                        guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                            showPaywall = true
                                            return
                                        }
                                        regenerateSummary()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // Summary content
                    let cleanSummary = cleanMarkdownFences(summary)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(cleanSummary.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                                Spacer().frame(height: 4)
                            } else if line.hasPrefix("## ") {
                                Text(.init(line.replacingOccurrences(of: "## ", with: "")))
                                    .font(.title3.bold())
                                    .foregroundStyle(GlassTheme.textPrimary)
                            } else if line.hasPrefix("# ") {
                                Text(.init(line.replacingOccurrences(of: "# ", with: "")))
                                    .font(.title2.bold())
                                    .foregroundStyle(GlassTheme.textPrimary)
                            } else if line.hasPrefix("### ") {
                                Text(.init(line.replacingOccurrences(of: "### ", with: "")))
                                    .font(.headline)
                                    .foregroundStyle(GlassTheme.textPrimary)
                            } else if line.hasPrefix("  - ") || line.hasPrefix("  * ") {
                                Text(.init("    • " + String(line.dropFirst(4))))
                                    .font(.body)
                                    .foregroundStyle(GlassTheme.textSecondary)
                            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                                Text(.init("• " + String(line.dropFirst(2))))
                                    .font(.body)
                                    .foregroundStyle(GlassTheme.textSecondary)
                            } else {
                                Text(.init(line))
                                    .font(.body)
                                    .foregroundStyle(GlassTheme.textSecondary)
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
                    .padding(.horizontal)

                    // Regenerate button
                    Button {
                        regenerateSummary()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                                .font(.caption)
                            Text("重新生成")
                                .font(.subheadline)
                        }
                        .foregroundStyle(GlassTheme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .glassButton()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                } else if let error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(GlassTheme.accent)
                        Text("生成失败")
                            .font(.headline)
                            .foregroundStyle(GlassTheme.textPrimary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            self.error = nil
                            generateSummary()
                        }
                        .glassButton()
                        .foregroundStyle(GlassTheme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .padding(.horizontal)
                } else {
                    noTranscriptState
                }
            }
        }
        .background(Color.clear)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var noTranscriptState: some View {
        VStack(spacing: 16) {
            if recording.transcription == nil {
                Image(systemName: "text.badge.xmark")
                    .font(.system(size: 40))
                    .foregroundStyle(GlassTheme.textMuted)
                Text("请先完成语音转写")
                    .font(.headline)
                    .foregroundStyle(GlassTheme.textSecondary)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(GlassTheme.textMuted)

                Text("选择摘要模板")
                    .font(.headline)
                    .foregroundStyle(GlassTheme.textSecondary)

                VStack(spacing: 10) {
                    ForEach(SummaryTemplate.allCases) { template in
                        Button {
                            selectedTemplate = template
                            generateSummary()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: template.icon)
                                    .foregroundStyle(GlassTheme.accent)
                                Text(template.rawValue)
                                    .foregroundStyle(GlassTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(GlassTheme.textMuted)
                            }
                            .padding()
                        }
                        .glassButton()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.horizontal)
    }

    private func generateSummary() {
        guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
            showPaywall = true
            return
        }
        guard let transcription = recording.transcription else { return }
        recording.isSummarizing = true

        Task {
            do {
                let summary = try await aiService.generateSummary(
                    transcription: transcription,
                    template: selectedTemplate
                )
                recording.summary = summary
                recording.summaryCache[selectedTemplate.rawValue] = summary
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

    private func cleanMarkdownFences(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        if let first = lines.first?.trimmingCharacters(in: .whitespaces),
           first.hasPrefix("```") {
            lines.removeFirst()
        }
        if let last = lines.last?.trimmingCharacters(in: .whitespaces),
           last == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

}
