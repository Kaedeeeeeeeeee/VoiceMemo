import AppIntents

struct VoiceMemoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "用\(.applicationName)录音",
                "开始\(.applicationName)录音",
            ],
            shortTitle: "开始录音",
            systemImageName: "mic.fill"
        )

        AppShortcut(
            intent: GetRecentRecordingsIntent(),
            phrases: [
                "获取最近的\(.applicationName)录音",
                "查看\(.applicationName)录音",
            ],
            shortTitle: "最近录音",
            systemImageName: "list.bullet"
        )
    }
}
