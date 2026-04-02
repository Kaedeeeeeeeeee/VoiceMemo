import SwiftUI

struct MacSummaryView: View {
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
                            .tint(MacGlassTheme.accent)
                            .scaleEffect(1.2)
                        Text("正在生成摘要...")
                            .font(.subheadline)
                            .foregroundStyle(MacGlassTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .macGlassCard()
                    .padding()
                } else if let summary = recording.summary {
                    // Template selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SummaryTemplate.allCases) { template in
                                MacGlassChip(
                                    title: template.displayName,
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
                                    .foregroundStyle(MacGlassTheme.textPrimary)
                            } else if line.hasPrefix("# ") {
                                Text(.init(line.replacingOccurrences(of: "# ", with: "")))
                                    .font(.title2.bold())
                                    .foregroundStyle(MacGlassTheme.textPrimary)
                            } else if line.hasPrefix("### ") {
                                Text(.init(line.replacingOccurrences(of: "### ", with: "")))
                                    .font(.headline)
                                    .foregroundStyle(MacGlassTheme.textPrimary)
                            } else if line.hasPrefix("  - ") || line.hasPrefix("  * ") {
                                Text(.init("    • " + String(line.dropFirst(4))))
                                    .font(.body)
                                    .foregroundStyle(MacGlassTheme.textSecondary)
                            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                                Text(.init("• " + String(line.dropFirst(2))))
                                    .font(.body)
                                    .foregroundStyle(MacGlassTheme.textSecondary)
                            } else {
                                Text(.init(line))
                                    .font(.body)
                                    .foregroundStyle(MacGlassTheme.textSecondary)
                            }
                        }
                    }
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .macGlassCard()
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
                        .foregroundStyle(MacGlassTheme.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .macGlassButton()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                } else if let error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(MacGlassTheme.accent)
                        Text("生成失败")
                            .font(.headline)
                            .foregroundStyle(MacGlassTheme.textPrimary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(MacGlassTheme.textTertiary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            self.error = nil
                            generateSummary()
                        }
                        .macGlassButton()
                        .foregroundStyle(MacGlassTheme.accent)
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
            MacPaywallPlaceholder()
        }
    }

    private var noTranscriptState: some View {
        VStack(spacing: 16) {
            if recording.transcription == nil {
                Image(systemName: "text.badge.xmark")
                    .font(.system(size: 40))
                    .foregroundStyle(MacGlassTheme.textMuted)
                Text("请先完成语音转写")
                    .font(.headline)
                    .foregroundStyle(MacGlassTheme.textSecondary)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(MacGlassTheme.textMuted)

                Text("选择摘要模板")
                    .font(.headline)
                    .foregroundStyle(MacGlassTheme.textSecondary)

                VStack(spacing: 10) {
                    ForEach(SummaryTemplate.allCases) { template in
                        Button {
                            selectedTemplate = template
                            generateSummary()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: template.icon)
                                    .foregroundStyle(MacGlassTheme.accent)
                                Text(template.displayName)
                                    .foregroundStyle(MacGlassTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(MacGlassTheme.textMuted)
                            }
                            .padding()
                        }
                        .macGlassButton()
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
