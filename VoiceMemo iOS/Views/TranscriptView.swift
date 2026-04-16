import SwiftUI
import SwiftData

// MARK: - Note Block Model

private enum NoteBlock: Identifiable {
    case transcript(index: Int, timestamp: TimeInterval?, text: String)
    case marker(RecordingMarker)

    var id: String {
        switch self {
        case .transcript(let i, _, _): return "t_\(i)"
        case .marker(let m): return "m_\(m.id.uuidString)"
        }
    }

    var sortTime: TimeInterval {
        switch self {
        case .transcript(_, let ts, _): return ts ?? 0
        case .marker(let m): return m.timestamp
        }
    }
}

// MARK: - TranscriptView

struct TranscriptView: View {
    @Bindable var recording: Recording
    @Environment(\.modelContext) private var modelContext
    @State private var transcriptionService = TranscriptionService()
    @State private var aiService = AIService()
    @State private var voiceprintService = VoiceprintService()
    @State private var error: String?
    @State private var segments: [String] = []
    @State private var segmentAnchors: [String?] = []
    @State private var originalSegments: [String] = []
    @State private var transcriptionPhase = ""
    @State private var showSpeakerSheet = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            if recording.isTranscribing {
                transcribingView
            } else if recording.transcription != nil {
                noteView
            } else if let error {
                errorView(error)
            } else {
                emptyView
            }
        }
        .background(Color.clear)
        .sheet(isPresented: $showSpeakerSheet) {
            SpeakerRenameSheet(recording: recording)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Unified Note View

    private var noteView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !speakers.isEmpty {
                    speakerBanner
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Single container
                VStack(alignment: .leading, spacing: 12) {
                    let noteBlocks = buildNoteBlocks()
                    ForEach(Array(noteBlocks.enumerated()), id: \.element.id) { _, block in
                        switch block {
                        case .transcript(let index, _, _):
                            if index >= 0 && index < segments.count {
                                InlineEditableBlock(
                                    text: $segments[index],
                                    speakerColorMap: speakerColorMap,
                                    onSave: { saveSegmentsToRecording() }
                                )
                            }

                        case .marker(let marker):
                            InlineMarkerView(marker: marker) {
                                deleteMarker(marker)
                            }
                        }
                    }
                }
                .padding(16)
                .glassCard()
                .padding(.horizontal)
            }
            .padding(.top, 4)
            .padding(.bottom, 80)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            saveSegmentsToRecording()
        }
        .onAppear { rebuildSegments() }
        .onChange(of: recording.transcription) { rebuildSegments() }
        .onChange(of: recording.speakerNames) { rebuildSegments() }
    }

    private func rebuildSegments() {
        let blocks = buildNoteBlocks()
        var display: [String] = []
        var anchors: [String?] = []
        var originals: [String] = []
        for block in blocks {
            if case .transcript(_, _, let text) = block {
                originals.append(text)
                anchors.append(extractLeadingTimestamp(text))
                display.append(stripTimestamps(text))
            }
        }
        segments = display
        segmentAnchors = anchors
        originalSegments = originals
    }

    private func stripTimestamps(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[\d{2}:\d{2}\]\s*"#) else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    /// Returns the leading `[MM:SS] ` prefix of a transcript block, if present.
    /// Used to re-attach the anchor when writing edited segments back to the model.
    private func extractLeadingTimestamp(_ text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"^\[\d{2}:\d{2}\]\s*"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    private func saveSegmentsToRecording() {
        // Rebuild the stored transcription while preserving [mm:ss] anchors.
        // Untouched segments are written back verbatim (keeping all in-block
        // anchors); edited segments get their leading anchor re-attached —
        // mid-block anchors in an edited segment are lost, which is the
        // minimum unavoidable loss.
        guard segments.count == originalSegments.count,
              segments.count == segmentAnchors.count else { return }

        var rebuilt: [String] = []
        var didChange = false
        for i in segments.indices {
            let displayed = segments[i]
            let strippedOriginal = stripTimestamps(originalSegments[i])
            if displayed == strippedOriginal {
                rebuilt.append(originalSegments[i])
            } else {
                didChange = true
                if let anchor = segmentAnchors[i] {
                    rebuilt.append(anchor + displayed)
                } else {
                    rebuilt.append(displayed)
                }
            }
        }

        // Background taps / onChange-triggered re-saves with no real edit
        // must not mutate the stored transcription — this is what was
        // silently destroying timestamp anchors before.
        guard didChange else { return }

        let joined = rebuilt.joined(separator: "\n\n")
        recording.transcription = recording.reversingSpeakerNames(in: joined)

        // Regenerate embeddings in background
        if let container = recording.modelContext?.container {
            let rid = recording.id
            Task.detached(priority: .utility) {
                let ctx = ModelContext(container)
                let desc = FetchDescriptor<Recording>(predicate: #Predicate { $0.id == rid })
                guard let rec = try? ctx.fetch(desc).first else { return }
                try? await EmbeddingService.shared.generateEmbeddings(for: rec, context: ctx)
            }
        }
    }

    // MARK: - Build Note Blocks

    private func buildNoteBlocks() -> [NoteBlock] {
        let polishedText = recording.applyingSpeakerNames(to: recording.transcription ?? "")
        let markers = recording.sortedMarkers

        guard !markers.isEmpty else {
            // No markers — single text block
            return [.transcript(index: 0, timestamp: 0, text: polishedText)]
        }

        // Use utterance timing to calculate total duration for proportional splitting
        let totalDuration: TimeInterval
        if let utterances = recording.speakerUtterances, !utterances.isEmpty {
            totalDuration = TimeInterval(utterances.map(\.endMs).max() ?? 0) / 1000.0
        } else {
            totalDuration = recording.duration
        }

        guard totalDuration > 0 else {
            // Can't calculate positions — put markers at end
            var blocks: [NoteBlock] = [.transcript(index: 0, timestamp: 0, text: polishedText)]
            for m in markers { blocks.append(.marker(m)) }
            return blocks
        }

        // Split polished text at marker positions using time-proportional character offsets
        let textLength = polishedText.count
        var blocks: [NoteBlock] = []
        var lastCutIndex = polishedText.startIndex
        var transcriptIdx = 0

        for marker in markers {
            let proportion = marker.timestamp / totalDuration
            let charOffset = min(Int(Double(textLength) * proportion), textLength)
            var cutPoint = polishedText.index(polishedText.startIndex, offsetBy: charOffset)

            // Snap to nearest paragraph break or sentence end to avoid cutting mid-word
            cutPoint = findNearestBreak(in: polishedText, near: cutPoint)

            if cutPoint > lastCutIndex {
                let segment = String(polishedText[lastCutIndex..<cutPoint]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !segment.isEmpty {
                    blocks.append(.transcript(index: transcriptIdx, timestamp: 0, text: segment))
                    transcriptIdx += 1
                }
            }

            blocks.append(.marker(marker))
            lastCutIndex = cutPoint
        }

        // Remaining text after last marker
        if lastCutIndex < polishedText.endIndex {
            let remaining = String(polishedText[lastCutIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty {
                blocks.append(.transcript(index: transcriptIdx, timestamp: 0, text: remaining))
            }
        }

        return blocks
    }

    /// Find the nearest paragraph break (\n\n) or newline near the target index, to avoid cutting mid-sentence
    private func findNearestBreak(in text: String, near target: String.Index) -> String.Index {
        let searchRadius = 100 // characters to search in each direction

        let lowerBound = text.index(target, offsetBy: -searchRadius, limitedBy: text.startIndex) ?? text.startIndex
        let upperBound = text.index(target, offsetBy: searchRadius, limitedBy: text.endIndex) ?? text.endIndex

        // Prefer paragraph break (\n\n)
        let searchRange = lowerBound..<upperBound
        let searchStr = String(text[searchRange])

        // Look for \n\n closest to target
        var bestBreak = target
        var bestDistance = Int.max

        var searchIndex = searchStr.startIndex
        while let range = searchStr.range(of: "\n\n", range: searchIndex..<searchStr.endIndex) {
            let breakInOriginal = text.index(lowerBound, offsetBy: searchStr.distance(from: searchStr.startIndex, to: range.lowerBound))
            let distance = abs(text.distance(from: target, to: breakInOriginal))
            if distance < bestDistance {
                bestDistance = distance
                bestBreak = text.index(breakInOriginal, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex // after \n\n
            }
            searchIndex = range.upperBound
        }

        if bestDistance < searchRadius {
            return bestBreak
        }

        // Fallback: look for single \n
        searchIndex = searchStr.startIndex
        while let range = searchStr.range(of: "\n", range: searchIndex..<searchStr.endIndex) {
            let breakInOriginal = text.index(lowerBound, offsetBy: searchStr.distance(from: searchStr.startIndex, to: range.lowerBound))
            let distance = abs(text.distance(from: target, to: breakInOriginal))
            if distance < bestDistance {
                bestDistance = distance
                bestBreak = text.index(breakInOriginal, offsetBy: 1, limitedBy: text.endIndex) ?? text.endIndex
            }
            searchIndex = range.upperBound
        }

        if bestDistance < searchRadius {
            return bestBreak
        }

        // Last resort: use target directly
        return target
    }

    private func deleteMarker(_ marker: RecordingMarker) {
        if let photoFileName = marker.photoFileName {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let photoURL = documentsDir.appendingPathComponent(photoFileName)
            try? FileManager.default.removeItem(at: photoURL)
        }
        modelContext.delete(marker)
    }

    // MARK: - Transcribing View

    private var transcribingView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let progress = transcriptionService.phaseProgress, progress > 0 {
                    ProgressView(value: progress)
                        .tint(GlassTheme.accent)
                        .padding(.horizontal, 40)

                    if transcriptionService.currentPhase == .polling {
                        Text("已等待 \(transcriptionService.pollingElapsedSeconds) 秒...")
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textSecondary)
                    } else if transcriptionService.currentPhase == .uploading {
                        Text(String(localized: "正在上传 \(Int(progress * 100))%"))
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                } else {
                    ProgressView()
                        .tint(GlassTheme.accent)
                        .scaleEffect(1.2)
                    Text(phaseText.isEmpty ? String(localized: "正在转写...") : phaseText)
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textSecondary)
                }

                if transcriptionService.totalChunks > 1 {
                    Text(String(localized: "分片 \(transcriptionService.currentChunk)/\(transcriptionService.totalChunks)"))
                        .font(.caption)
                        .foregroundStyle(GlassTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .glassCard()
            .padding()
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                if error.contains("no spoken audio") {
                    Image(systemName: "waveform.slash")
                        .font(.largeTitle)
                        .foregroundStyle(GlassTheme.textMuted)
                    Text("未检测到语音内容")
                        .font(.headline)
                        .foregroundStyle(GlassTheme.textPrimary)
                    Text("录音中没有可识别的语音，请确认录音内容后重试。")
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textTertiary)
                        .multilineTextAlignment(.center)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(GlassTheme.accent)
                    Text("转写失败")
                        .font(.headline)
                        .foregroundStyle(GlassTheme.textPrimary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(GlassTheme.textTertiary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        self.error = nil
                        startTranscription()
                    }
                    .glassButton()
                    .foregroundStyle(GlassTheme.accent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal)
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 40))
                    .foregroundStyle(GlassTheme.textMuted)

                Text("将录音转换为文字")
                    .font(.headline)
                    .foregroundStyle(GlassTheme.textSecondary)

                Button {
                    startTranscription()
                } label: {
                    Text("开始转写")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
                .glassButton(prominent: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }

    // MARK: - Helpers

    private var speakers: [String] {
        Recording.extractSpeakers(from: recording.transcription ?? "")
    }

    private var speakerColorMap: [String: UIColor] {
        let palette: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .cyan, .systemMint, .systemIndigo]
        let originalSpeakers = Recording.extractSpeakers(from: recording.transcription ?? "")
        var map: [String: UIColor] = [:]
        for (i, speaker) in originalSpeakers.enumerated() {
            let color = palette[i % palette.count]
            map[speaker] = color
            if let renamed = recording.speakerNames[speaker], !renamed.isEmpty {
                map[renamed] = color
            }
        }
        return map
    }

    private var speakerBanner: some View {
        Button {
            showSpeakerSheet = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.caption)
                    .foregroundStyle(GlassTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("说话人重命名")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(GlassTheme.textPrimary)
                    let named = recording.speakerNames.values.filter { !$0.isEmpty }.count
                    if named > 0 {
                        Text("已命名 \(named) 位说话人")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                    } else {
                        Text("检测到 \(speakers.count) 位说话人，点击设置名称")
                            .font(.caption)
                            .foregroundStyle(GlassTheme.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(GlassTheme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private var phaseText: String {
        switch transcriptionService.currentPhase {
        case .uploading:    return String(localized: "正在上传音频...")
        case .transcribing: return String(localized: "正在语音识别...")
        case .polling:      return String(localized: "正在等待转写结果...")
        case .idle:         return transcriptionPhase
        }
    }

    private func startTranscription() {
        guard TrialManager.shared.claimTrialIfNeeded(for: recording) else {
            showPaywall = true
            return
        }

        recording.isTranscribing = true

        Task {
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let url = documentsDir.appendingPathComponent(recording.fileURL)

            do {
                let result = try await transcriptionService.transcribeWithUtterances(audioURL: url)
                recording.setSpeakerUtterances(result.utterances)

                transcriptionPhase = String(localized: "正在智能润色...")
                let polishedText = try await aiService.polishTranscription(result.formattedText)
                recording.transcription = polishedText

                autoMatchSpeakers(audioURL: url, utterances: result.utterances)

                // Generate embeddings in background safely
                if let container = recording.modelContext?.container {
                    let rid = recording.id
                    Task.detached(priority: .utility) {
                        let ctx = ModelContext(container)
                        let desc = FetchDescriptor<Recording>(predicate: #Predicate { $0.id == rid })
                        guard let rec = try? ctx.fetch(desc).first else { return }
                        try? await EmbeddingService.shared.generateEmbeddings(for: rec, context: ctx)
                    }
                }

                if recording.title.hasPrefix("录音 ") || recording.title.hasPrefix("Recording ") || recording.title.hasPrefix("Voice Memo ") {
                    Task {
                        if let title = try? await aiService.generateTitle(transcription: polishedText) {
                            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                recording.title = trimmed
                            }
                        }
                    }
                }

                if recording.tags.isEmpty {
                    Task {
                        if let tags = try? await aiService.classifyRecording(transcription: polishedText), !tags.isEmpty {
                            recording.tags = tags
                        }
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }
            recording.isTranscribing = false
        }
    }

    private func autoMatchSpeakers(audioURL: URL, utterances: [SpeakerUtterance]) {
        let descriptor = FetchDescriptor<SpeakerProfile>()
        guard let profiles = try? modelContext.fetch(descriptor), !profiles.isEmpty else { return }

        Task {
            let matches = voiceprintService.matchSpeakers(audioURL: audioURL, utterances: utterances, profiles: profiles)
            for (speaker, match) in matches {
                let speakerLabel = LanguageManager.shared.speakerLabel(speaker)
                recording.speakerNames[speakerLabel] = match.profileName
            }
        }
    }
}

// MARK: - Inline Editable Block

private struct InlineEditableBlock: View {
    @Binding var text: String
    let speakerColorMap: [String: UIColor]
    let onSave: () -> Void

    var body: some View {
        RichSegmentTextView(text: $text, speakerColorMap: speakerColorMap, onEndEditing: onSave)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Rich Segment Text View (UIViewRepresentable)

private struct RichSegmentTextView: UIViewRepresentable {
    @Binding var text: String
    let speakerColorMap: [String: UIColor]
    var onEndEditing: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isEditable = true
        textView.isSelectable = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.attributedText = Self.buildAttributedString(from: text, colorMap: speakerColorMap)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update text if it changed externally (not from user typing)
        if textView.text != text {
            let savedRange = textView.selectedRange
            textView.attributedText = Self.buildAttributedString(from: text, colorMap: speakerColorMap)
            // Restore cursor if within bounds
            if savedRange.location + savedRange.length <= textView.text.count {
                textView.selectedRange = savedRange
            }
        }
    }

    // Custom attribute key to mark speaker label ranges as non-editable
    private static let speakerLabelKey = NSAttributedString.Key("speakerLabel")

    // Shared font helpers
    private static var bodyFont: UIFont { UIFont.preferredFont(forTextStyle: .body) }
    private static var captionFont: UIFont {
        let desc = UIFont.preferredFont(forTextStyle: .caption1).fontDescriptor
        let semiboldDesc = desc.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])
        return UIFont(descriptor: semiboldDesc, size: 0)
    }
    private static var bracketFont: UIFont { UIFont.systemFont(ofSize: 1) }
    private static var textColor: UIColor { UIColor(white: 1.0, alpha: 0.7) }

    // MARK: - Attributed String Builder

    static func buildAttributedString(from text: String, colorMap: [String: UIColor]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: bodyFont,
            .foregroundColor: textColor
        ])

        // Find 【Speaker】 patterns and style them
        let pattern = #"【([^】]+)】"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        for match in regex.matches(in: text, range: fullRange) {
            guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
            let speakerName = String(text[nameRange])
            let color = colorMap[speakerName] ?? .systemBlue

            // Mark entire 【Speaker】 as non-editable
            result.addAttribute(speakerLabelKey, value: true, range: match.range)

            // Style the 【 bracket — nearly invisible
            let openBracketRange = NSRange(location: match.range.location, length: 1)
            result.addAttributes([
                .font: bracketFont,
                .foregroundColor: UIColor.clear
            ], range: openBracketRange)

            // Style the speaker name — colored caption
            result.addAttributes([
                .font: captionFont,
                .foregroundColor: color
            ], range: match.range(at: 1))

            // Style the 】 bracket — nearly invisible
            let closeBracketRange = NSRange(location: match.range.location + match.range.length - 1, length: 1)
            result.addAttributes([
                .font: bracketFont,
                .foregroundColor: UIColor.clear
            ], range: closeBracketRange)
        }

        return result
    }

    // MARK: - Re-apply formatting in place

    static func applyFormatting(to textView: UITextView, colorMap: [String: UIColor]) {
        let text = textView.text ?? ""
        let storage = textView.textStorage
        let fullRange = NSRange(location: 0, length: storage.length)

        storage.beginEditing()

        // Default: body font, textSecondary color, remove old speaker marks
        storage.setAttributes([
            .font: bodyFont,
            .foregroundColor: textColor
        ], range: fullRange)

        // Find 【Speaker】 patterns and style them
        let pattern = #"【([^】]+)】"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            for match in regex.matches(in: text, range: fullRange) {
                guard let nameRange = Range(match.range(at: 1), in: text) else { continue }
                let speakerName = String(text[nameRange])
                let color = colorMap[speakerName] ?? .systemBlue

                // Mark as non-editable
                storage.addAttribute(speakerLabelKey, value: true, range: match.range)

                // 【 bracket — hidden
                let openBracketRange = NSRange(location: match.range.location, length: 1)
                storage.addAttributes([
                    .font: bracketFont,
                    .foregroundColor: UIColor.clear
                ], range: openBracketRange)

                // Speaker name — colored caption
                storage.addAttributes([
                    .font: captionFont,
                    .foregroundColor: color
                ], range: match.range(at: 1))

                // 】 bracket — hidden
                let closeBracketRange = NSRange(location: match.range.location + match.range.length - 1, length: 1)
                storage.addAttributes([
                    .font: bracketFont,
                    .foregroundColor: UIColor.clear
                ], range: closeBracketRange)
            }
        }

        storage.endEditing()

        // Set typing attributes to body style so new text uses default style
        textView.typingAttributes = [
            .font: bodyFont,
            .foregroundColor: textColor
        ]
    }

    // MARK: - Speaker label range detection

    static func rangeOverlapsSpeakerLabel(in textView: UITextView, range: NSRange) -> Bool {
        var overlaps = false
        textView.textStorage.enumerateAttribute(speakerLabelKey, in: range, options: []) { value, _, stop in
            if value != nil {
                overlaps = true
                stop.pointee = true
            }
        }
        return overlaps
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichSegmentTextView

        init(_ parent: RichSegmentTextView) {
            self.parent = parent
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Block edits that overlap with speaker label ranges
            let checkRange = NSRange(location: range.location, length: max(range.length, 1))
            let safeRange = NSIntersectionRange(checkRange, NSRange(location: 0, length: textView.textStorage.length))
            if safeRange.length > 0 && RichSegmentTextView.rangeOverlapsSpeakerLabel(in: textView, range: safeRange) {
                return false
            }
            return true
        }

        func textViewDidChange(_ textView: UITextView) {
            // Skip formatting during CJK composition
            guard textView.markedTextRange == nil else { return }

            parent.text = textView.text

            // Re-apply formatting in place (preserves cursor)
            let savedRange = textView.selectedRange
            RichSegmentTextView.applyFormatting(to: textView, colorMap: parent.speakerColorMap)
            if savedRange.location <= (textView.text?.count ?? 0) {
                textView.selectedRange = savedRange
            }

            textView.invalidateIntrinsicContentSize()
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.onEndEditing?()
        }
    }
}

// MARK: - Inline Marker View

private struct InlineMarkerView: View {
    let marker: RecordingMarker
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thin divider
            Rectangle()
                .fill(GlassTheme.textMuted.opacity(0.3))
                .frame(height: 1)

            // Bookmark header
            HStack(spacing: 8) {
                Button {
                    NotificationCenter.default.post(
                        name: .seekToTime,
                        object: nil,
                        userInfo: ["seconds": marker.timestamp]
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                        Text(marker.formattedTimestamp)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .foregroundStyle(GlassTheme.textMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(GlassTheme.textMuted.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)

                if marker.text != "标记" {
                    Text(marker.text)
                        .font(.subheadline)
                        .foregroundStyle(GlassTheme.textPrimary)
                }
            }

            // Photo
            if let photoFileName = marker.photoFileName {
                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let photoURL = documentsDir.appendingPathComponent(photoFileName)
                if let data = try? Data(contentsOf: photoURL),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Rectangle()
                .fill(GlassTheme.textMuted.opacity(0.3))
                .frame(height: 1)
        }
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除标记", systemImage: "trash")
            }
        }
    }
}
