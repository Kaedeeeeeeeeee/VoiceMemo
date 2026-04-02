import AppIntents
import SwiftData

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "开始录音"
    static var description: IntentDescription = "打开 PodNote 并开始录音"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct GetRecentRecordingsIntent: AppIntent {
    static var title: LocalizedStringResource = "获取最近的录音"
    static var description: IntentDescription = "查询最近的录音列表"

    @Parameter(title: "数量", default: 5)
    var count: Int

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let container = try ModelContainer(for: Recording.self)
        let context = ModelContext(container)

        var descriptor = FetchDescriptor<Recording>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = count

        let recordings = try context.fetch(descriptor)

        if recordings.isEmpty {
            return .result(value: "暂无录音")
        }

        let list = recordings.enumerated().map { index, recording in
            "\(index + 1). \(recording.title) (\(recording.formattedDuration))"
        }.joined(separator: "\n")

        return .result(value: list)
    }
}

struct GetTranscriptionIntent: AppIntent {
    static var title: LocalizedStringResource = "获取转写文本"
    static var description: IntentDescription = "获取指定录音的转写文本"

    @Parameter(title: "录音标题")
    var recordingTitle: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let container = try ModelContainer(for: Recording.self)
        let context = ModelContext(container)

        let title = recordingTitle
        let predicate = #Predicate<Recording> { recording in
            recording.title.contains(title)
        }

        var descriptor = FetchDescriptor<Recording>(predicate: predicate)
        descriptor.fetchLimit = 1

        let recordings = try context.fetch(descriptor)

        guard let recording = recordings.first else {
            return .result(value: "未找到标题包含「\(recordingTitle)」的录音")
        }

        guard let transcription = recording.transcription else {
            return .result(value: "该录音尚未转写")
        }

        return .result(value: recording.applyingSpeakerNames(to: transcription))
    }
}
