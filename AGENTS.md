# Repository Guidelines

## Project Structure & Module Organization
`VoiceMemo.xcodeproj` contains three active schemes: `VoiceMemo iOS`, `VoiceMemo Watch App`, and `VoiceMemo Watch WidgetExtension`. Put shared models, utilities, and cross-platform service protocols in `Shared/` (`Models/`, `Services/`, `Utilities/`). Keep iPhone-specific UI and integrations in `VoiceMemo iOS/`, watch app code in `VoiceMemo Watch App/`, and widget code in `VoiceMemo Watch Widget/`. Tests currently live under `VoiceMemo Watch AppTests/` and `VoiceMemo Watch AppUITests/`. `UI design/` stores reference mockups only; do not treat it as runtime code.

## Build, Test, and Development Commands
Open the project in Xcode with `open VoiceMemo.xcodeproj` for day-to-day work.

Use CLI builds to verify target-specific changes:
```bash
xcodebuild -project VoiceMemo.xcodeproj -scheme "VoiceMemo iOS" -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -project VoiceMemo.xcodeproj -scheme "VoiceMemo Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' build
xcodebuild -project VoiceMemo.xcodeproj -scheme "VoiceMemo Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' test
```
There are no Swift Package Manager dependencies; generated artifacts under `build/` should stay out of manual edits.

## Coding Style & Naming Conventions
Follow existing Swift conventions: 4-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties/functions. Name SwiftUI screens with a `View` suffix (`RecordingDetailView`) and service types with a `Service` suffix (`TranscriptionService`). Keep UI copy in Simplified Chinese to match the app. When working with recordings, store only the relative filename in `Recording.fileURL`; audio files are `.m4a`.

## Testing Guidelines
Use the `Testing` framework for focused unit tests and `XCTest` for UI flows. Add new tests beside the affected target, and keep names descriptive: `@Test func syncsWatchRecording()` or `func testLaunchPerformance()`. For behavioral changes, cover the main success path and one failure or edge case where practical.

## Commit & Pull Request Guidelines
Current history uses short, imperative subjects with context, for example: `Initial commit: VoiceMemo iOS + watchOS app`. Follow that pattern. PRs should include a brief summary, affected targets (`iOS`, `watchOS`, `widget`), test/build results, linked issues, and screenshots for UI changes on phone or watch.

## Security & Configuration Tips
Create `Shared/Services/APIConfig.swift` from `Shared/Services/APIConfig.template.swift` and keep real API keys out of git. Call out any changes that affect OpenAI usage, recording permissions, or WatchConnectivity behavior in the PR description.
