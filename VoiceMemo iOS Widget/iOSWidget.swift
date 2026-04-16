import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct iOSWidgetEntry: TimelineEntry {
    let date: Date
    let lastRecordingTitle: String?
    let lastRecordingDate: Date?
    let recentRecordings: [(title: String, date: Date)]
}

// MARK: - Timeline Provider

struct iOSWidgetProvider: TimelineProvider {
    private static let suiteName = "group.com.zhangshifeng.VoiceMemo"
    private static let titleKey = "lastRecordingTitle"
    private static let dateKey = "lastRecordingDate"
    private static let recentKey = "recentRecordingsJSON"

    func placeholder(in context: Context) -> iOSWidgetEntry {
        iOSWidgetEntry(date: .now, lastRecordingTitle: "PodNote", lastRecordingDate: nil, recentRecordings: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (iOSWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<iOSWidgetEntry>) -> Void) {
        let entry = makeEntry()
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
        completion(timeline)
    }

    private func makeEntry() -> iOSWidgetEntry {
        let defaults = UserDefaults(suiteName: Self.suiteName)
        let title = defaults?.string(forKey: Self.titleKey)
        let dateInterval = defaults?.double(forKey: Self.dateKey)
        let date = (dateInterval ?? 0) > 0 ? Date(timeIntervalSince1970: dateInterval!) : nil

        var recent: [(String, Date)] = []
        if let jsonString = defaults?.string(forKey: Self.recentKey),
           let data = jsonString.data(using: .utf8),
           let array = try? JSONDecoder().decode([[String: String]].self, from: data) {
            for item in array.prefix(3) {
                if let t = item["title"], let ds = item["date"], let di = Double(ds) {
                    recent.append((t, Date(timeIntervalSince1970: di)))
                }
            }
        }

        return iOSWidgetEntry(date: .now, lastRecordingTitle: title, lastRecordingDate: date, recentRecordings: recent)
    }
}

// MARK: - Quick Record Widget (Small)

struct QuickRecordWidgetView: View {
    var entry: iOSWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 36))
                .foregroundStyle(.red)

            Text("开始录音")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "voicememo://record"))
    }
}

struct QuickRecordWidget: Widget {
    let kind = "QuickRecordWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iOSWidgetProvider()) { entry in
            QuickRecordWidgetView(entry: entry)
        }
        .configurationDisplayName("快速录音")
        .description("点击即可开始录音")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Recent Recordings Widget (Medium)

struct RecentRecordingsWidgetView: View {
    var entry: iOSWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                Text("PodNote")
                    .font(.headline)
                Spacer()
                Link(destination: URL(string: "voicememo://record")!) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
            }

            if entry.recentRecordings.isEmpty {
                HStack {
                    Spacer()
                    Text("暂无录音")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            } else {
                ForEach(entry.recentRecordings.prefix(3), id: \.title) { item in
                    HStack {
                        Image(systemName: "waveform")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(item.date, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(4)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct RecentRecordingsWidget: Widget {
    let kind = "RecentRecordingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: iOSWidgetProvider()) { entry in
            RecentRecordingsWidgetView(entry: entry)
        }
        .configurationDisplayName("最近录音")
        .description("查看最近的录音记录")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Recording Live Activity

struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: context.state.source == .watch ? "applewatch" : "mic.fill")
                        .foregroundStyle(context.state.isPaused ? .orange : .red)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.recordingTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(context.state.isPaused ? "已暂停" : "正在录音")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if context.state.isPaused {
                        Text(Duration.seconds(context.state.frozenElapsed), format: .time(pattern: .hourMinuteSecond))
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.primary)
                    } else {
                        Text(timerInterval: context.state.timerStartDate...(.distantFuture), countsDown: false)
                            .font(.title3.monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }

                HStack(spacing: 10) {
                    liveActivityButton(
                        title: "拍照",
                        systemImage: "camera.fill",
                        intent: TakePhotoLiveActivityIntent(
                            recordingId: context.attributes.recordingId,
                            timestamp: currentElapsed(for: context.state)
                        )
                    )
                    liveActivityButton(
                        title: "添加标记",
                        systemImage: "bookmark.fill",
                        intent: AddMarkerLiveActivityIntent(
                            recordingId: context.attributes.recordingId,
                            timestamp: currentElapsed(for: context.state)
                        )
                    )
                }
            }
            .padding()
            .activityBackgroundTint(.black.opacity(0.75))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isPaused ? "pause.circle.fill" : (context.state.source == .watch ? "applewatch" : "mic.fill"))
                            .foregroundStyle(context.state.isPaused ? .orange : .red)
                        Text(context.state.isPaused ? "已暂停" : "正在录音")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text(Duration.seconds(context.state.frozenElapsed), format: .time(pattern: .hourMinuteSecond))
                            .font(.subheadline.monospacedDigit())
                    } else {
                        Text(timerInterval: context.state.timerStartDate...(.distantFuture), countsDown: false)
                            .font(.subheadline.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        liveActivityButton(
                            title: "拍照",
                            systemImage: "camera.fill",
                            intent: TakePhotoLiveActivityIntent(
                                recordingId: context.attributes.recordingId,
                                timestamp: currentElapsed(for: context.state)
                            )
                        )
                        liveActivityButton(
                            title: "添加标记",
                            systemImage: "bookmark.fill",
                            intent: AddMarkerLiveActivityIntent(
                                recordingId: context.attributes.recordingId,
                                timestamp: currentElapsed(for: context.state)
                            )
                        )
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.source == .watch ? "applewatch" : "mic.fill")
                    .foregroundStyle(context.state.isPaused ? .orange : .red)
            } compactTrailing: {
                if context.state.isPaused {
                    Text(Duration.seconds(context.state.frozenElapsed), format: .time(pattern: .hourMinuteSecond))
                        .font(.caption.monospacedDigit())
                } else {
                    Text(timerInterval: context.state.timerStartDate...(.distantFuture), countsDown: false)
                        .font(.caption.monospacedDigit())
                }
            } minimal: {
                Image(systemName: context.state.source == .watch ? "applewatch" : "mic.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    /// Current timestamp used by Live Activity buttons to snapshot where the
    /// user is in the recording at tap time. When paused the timestamp is
    /// frozen; otherwise it's the time since `timerStartDate`.
    private func currentElapsed(for state: RecordingActivityAttributes.ContentState) -> Double {
        if state.isPaused {
            return state.frozenElapsed
        }
        return max(0, Date.now.timeIntervalSince(state.timerStartDate))
    }

    private func liveActivityButton<Intent: AppIntent>(
        title: String,
        systemImage: String,
        intent: Intent
    ) -> some View {
        Button(intent: intent) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.callout)
                Text(title)
                    .font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .tint(.white.opacity(0.18))
        .foregroundStyle(.white)
    }
}

// MARK: - Widget Bundle

@main
struct iOSWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickRecordWidget()
        RecentRecordingsWidget()
        RecordingLiveActivity()
    }
}
