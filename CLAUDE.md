# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build iOS app
xcodebuild -project VoiceMemo.xcodeproj -scheme "VoiceMemo iOS" -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build Watch app
xcodebuild -project VoiceMemo.xcodeproj -scheme "VoiceMemo Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build

# Run Watch tests
xcodebuild -project VoiceMemo.xcodeproj -scheme "VoiceMemo Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' test
```

No SPM dependencies. Pure Xcode project.

## Architecture

Multi-target app: iOS + watchOS + Watch Widget. All UI is SwiftUI, persistence is SwiftData, services use `@Observable`.

### Shared Code (`Shared/`)
- **Recording** (`@Model`) — the single data model, persisted via SwiftData. Stores title, date, duration, fileURL (relative path in Documents), transcription/summary (optional), and processing flags (`isTranscribing`, `isSummarizing`).
- **AudioService** — protocols (`AudioRecorderProtocol`, `AudioPlayerProtocol`) implemented separately per platform.
- **APIConfig** — OpenAI API key, referenced by iOS services.
- **DateFormatter+Ext** — `Date.recordingTitle` generates default title format `"录音 yyyy-MM-dd HH:mm"`.

### iOS App (`VoiceMemo iOS/`)
**Services:**
- **AIService** — GPT-4o wrapper. Methods: `generateSummary`, `polishTranscription` (post-Whisper cleanup), `generateTitle`, `chat` (multi-turn conversation). All go through a single `callOpenAIAPI` method.
- **TranscriptionService** — Whisper API. Auto-chunks files >25MB into 10-min segments via `AVAssetExportSession`.
- **iOSAudioRecorder** — AVAudioRecorder wrapper. MPEG4 AAC, 44.1kHz mono.
- **PhoneConnectivityService** — receives recordings from Watch via WCSession.

**Views:**
- **RecordingListView** — main list + floating record button + recording sheet.
- **RecordingDetailView** — player + tabbed content (转写/摘要/对话).
- **TranscriptView** — transcription flow: Whisper → AI polish → auto-title. Has inline edit mode.
- **SummaryView** — template-based summarization (4 templates). Renders Markdown via `AttributedString`.
- **AIConversationView** — multi-turn chat grounded on transcription text.

### Watch App (`VoiceMemo Watch App/`)
Records audio with extended runtime sessions, syncs files to iPhone via WatchConnectivity.

### Transcription Pipeline
The transcription flow is two-step: Whisper (speech-to-text) → GPT-4o polish (add punctuation, fix proper nouns, paragraph breaks). After polish, auto-generates a short title if the recording still has the default date-based name (checked via `title.hasPrefix("录音 ")`).

## Conventions

- All UI text is in Simplified Chinese.
- Recordings are stored as .m4a files in the app's Documents directory. `Recording.fileURL` stores only the filename, not the full path.
- Services are instantiated as `@State` within views (not injected via environment).
- Summary templates embed their system prompts directly and request Markdown output.
