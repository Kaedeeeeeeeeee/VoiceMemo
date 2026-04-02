import SwiftUI
import SwiftData

struct SummaryView: View {
    @Bindable var recording: Recording
    @State private var aiService = AIService()
    @State private var selectedTemplate: SummaryTemplate = .general
    @State private var selectedCustomTemplate: CustomSummaryTemplate?
    @State private var error: String?
    @State private var showPaywall = false
    @State private var showTemplateEditor = false
    @State private var editingTemplate: CustomSummaryTemplate?
    @Query(sort: \CustomSummaryTemplate.sortOrder) private var customTemplates: [CustomSummaryTemplate]

    /// Whether a custom template is currently selected
    private var isCustomSelected: Bool { selectedCustomTemplate != nil }

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
                            // Built-in templates
                            ForEach(SummaryTemplate.allCases) { template in
                                GlassChip(
                                    title: template.displayName,
                                    isActive: selectedTemplate == template && !isCustomSelected
                                ) {
                                    selectedCustomTemplate = nil
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

                            // Custom templates
                            ForEach(customTemplates) { custom in
                                GlassChip(
                                    title: custom.name,
                                    isActive: selectedCustomTemplate?.id == custom.id
                                ) {
                                    selectedCustomTemplate = custom
                                    let cacheKey = "custom_\(custom.id.uuidString)"
                                    if let cached = recording.summaryCache[cacheKey] {
                                        recording.summary = cached
                                    } else {
                                        guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
                                            showPaywall = true
                                            return
                                        }
                                        regenerateCustomSummary(custom)
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        editingTemplate = custom
                                    } label: {
                                        Label("编辑模板", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        let context = custom.modelContext
                                        context?.delete(custom)
                                        if selectedCustomTemplate?.id == custom.id {
                                            selectedCustomTemplate = nil
                                        }
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }

                            // Add custom template button
                            Button {
                                showTemplateEditor = true
                            } label: {
                                Image(systemName: "plus")
                                    .font(.subheadline)
                                    .foregroundStyle(GlassTheme.textMuted)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .glassButton()
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 8)

                    // Chapter index for chapter summary
                    let cleanSummary = cleanMarkdownFences(summary)
                    let chapters = parseChapters(from: cleanSummary)
                    if !chapters.isEmpty {
                        ChapterIndexView(chapters: chapters)
                            .padding(.horizontal)
                    }

                    // Summary content with timestamp support
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(cleanSummary.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                                Spacer().frame(height: 4)
                            } else if line.hasPrefix("## ") {
                                renderLineWithTimestamps(line.replacingOccurrences(of: "## ", with: ""), font: .title3.bold(), color: GlassTheme.textPrimary)
                            } else if line.hasPrefix("# ") {
                                renderLineWithTimestamps(line.replacingOccurrences(of: "# ", with: ""), font: .title2.bold(), color: GlassTheme.textPrimary)
                            } else if line.hasPrefix("### ") {
                                renderLineWithTimestamps(line.replacingOccurrences(of: "### ", with: ""), font: .headline, color: GlassTheme.textPrimary)
                            } else if line.hasPrefix("  - ") || line.hasPrefix("  * ") {
                                renderLineWithTimestamps("    • " + String(line.dropFirst(4)), font: .body, color: GlassTheme.textSecondary)
                            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                                renderLineWithTimestamps("• " + String(line.dropFirst(2)), font: .body, color: GlassTheme.textSecondary)
                            } else {
                                renderLineWithTimestamps(line, font: .body, color: GlassTheme.textSecondary)
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
                        if let custom = selectedCustomTemplate {
                            regenerateCustomSummary(custom)
                        } else {
                            regenerateSummary()
                        }
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
        .sheet(isPresented: $showTemplateEditor) {
            CustomTemplateEditorView()
        }
        .sheet(item: $editingTemplate) { template in
            CustomTemplateEditorView(templateToEdit: template)
        }
    }

    @ViewBuilder
    private func renderLineWithTimestamps(_ line: String, font: Font, color: Color) -> some View {
        let pattern = #"\[(\d{2}):(\d{2})\]"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil {
            TimestampLineInSummary(line: line, font: font, defaultColor: color)
        } else {
            Text(.init(line))
                .font(font)
                .foregroundStyle(color)
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
                            selectedCustomTemplate = nil
                            generateSummary()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: template.icon)
                                    .foregroundStyle(GlassTheme.accent)
                                Text(template.displayName)
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

                    // Custom templates in initial selection
                    ForEach(customTemplates) { custom in
                        Button {
                            selectedCustomTemplate = custom
                            generateCustomSummary(custom)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: custom.icon)
                                    .foregroundStyle(GlassTheme.accent)
                                Text(custom.name)
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

                    // Add template button
                    Button {
                        showTemplateEditor = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle")
                                .foregroundStyle(GlassTheme.accent)
                            Text("自定义模板")
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

    private func generateCustomSummary(_ template: CustomSummaryTemplate) {
        guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
            showPaywall = true
            return
        }
        guard let transcription = recording.transcription else { return }
        recording.isSummarizing = true
        let cacheKey = "custom_\(template.id.uuidString)"

        Task {
            do {
                let summary = try await aiService.generateSummary(
                    transcription: transcription,
                    systemPrompt: template.systemPrompt
                )
                recording.summary = summary
                recording.summaryCache[cacheKey] = summary
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

    private func regenerateCustomSummary(_ template: CustomSummaryTemplate) {
        recording.summary = nil
        generateCustomSummary(template)
    }

    struct ChapterEntry: Identifiable {
        let id = UUID()
        let title: String
        let seconds: Int? // nil if no timestamp
    }

    private func parseChapters(from text: String) -> [ChapterEntry] {
        let lines = text.components(separatedBy: "\n")
        let timestampPattern = #"\[(\d{2}):(\d{2})\]"#
        let regex = try? NSRegularExpression(pattern: timestampPattern)

        return lines.compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") else { return nil }

            let title = trimmed
                .replacingOccurrences(of: "### ", with: "")
                .replacingOccurrences(of: "## ", with: "")
                .trimmingCharacters(in: .whitespaces)

            guard !title.isEmpty else { return nil }

            var seconds: Int? = nil
            if let regex, let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
                let nsTitle = title as NSString
                let mins = Int(nsTitle.substring(with: match.range(at: 1))) ?? 0
                let secs = Int(nsTitle.substring(with: match.range(at: 2))) ?? 0
                seconds = mins * 60 + secs
            }

            return ChapterEntry(title: title, seconds: seconds)
        }
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

// MARK: - Chapter Index View

private struct ChapterIndexView: View {
    let chapters: [SummaryView.ChapterEntry]
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(GlassTheme.accent)
                    Text("章节目录")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(GlassTheme.textPrimary)
                    Text("\(chapters.count)")
                        .font(.caption)
                        .foregroundStyle(GlassTheme.textTertiary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(GlassTheme.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                        Button {
                            if let seconds = chapter.seconds {
                                NotificationCenter.default.post(
                                    name: .seekToTime,
                                    object: nil,
                                    userInfo: ["seconds": TimeInterval(seconds)]
                                )
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(GlassTheme.textTertiary)
                                    .frame(width: 16)

                                // Clean timestamp from title for display
                                let cleanTitle = chapter.title.replacingOccurrences(
                                    of: #"\s*\[\d{2}:\d{2}\]\s*"#,
                                    with: " ",
                                    options: .regularExpression
                                ).trimmingCharacters(in: .whitespaces)

                                Text(cleanTitle)
                                    .font(.subheadline)
                                    .foregroundStyle(GlassTheme.textSecondary)
                                    .lineLimit(1)

                                Spacer()

                                if let seconds = chapter.seconds {
                                    let mins = seconds / 60
                                    let secs = seconds % 60
                                    Text(String(format: "%02d:%02d", mins, secs))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(GlassTheme.accent)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(chapter.seconds == nil)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .glassCard()
    }
}

// MARK: - Timestamp rendering in summary

private struct TimestampLineInSummary: View {
    let line: String
    let font: Font
    let defaultColor: Color

    var body: some View {
        let parts = splitTimestamps(line)
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                switch part {
                case .text(let str):
                    Text(.init(str))
                        .font(font)
                        .foregroundStyle(defaultColor)
                case .timestamp(let label, let seconds):
                    Button {
                        NotificationCenter.default.post(
                            name: .seekToTime,
                            object: nil,
                            userInfo: ["seconds": TimeInterval(seconds)]
                        )
                    } label: {
                        Text(label)
                            .font(.caption.monospaced())
                            .foregroundStyle(GlassTheme.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(GlassTheme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private enum Part {
        case text(String)
        case timestamp(String, Int)
    }

    private func splitTimestamps(_ input: String) -> [Part] {
        let pattern = #"\[(\d{2}):(\d{2})\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(input)]
        }
        let nsString = input as NSString
        var parts: [Part] = []
        var lastEnd = 0

        for match in regex.matches(in: input, range: NSRange(location: 0, length: nsString.length)) {
            if match.range.location > lastEnd {
                parts.append(.text(nsString.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))))
            }
            let mins = Int(nsString.substring(with: match.range(at: 1))) ?? 0
            let secs = Int(nsString.substring(with: match.range(at: 2))) ?? 0
            parts.append(.timestamp(nsString.substring(with: match.range), mins * 60 + secs))
            lastEnd = match.range.location + match.range.length
        }
        if lastEnd < nsString.length {
            parts.append(.text(nsString.substring(from: lastEnd)))
        }
        return parts
    }
}
