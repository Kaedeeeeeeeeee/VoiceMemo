import WidgetKit
import SwiftUI

struct VoiceMemoWidgetEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let recordingDuration: TimeInterval?
}

struct VoiceMemoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> VoiceMemoWidgetEntry {
        VoiceMemoWidgetEntry(date: .now, isRecording: false, recordingDuration: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (VoiceMemoWidgetEntry) -> Void) {
        let entry = VoiceMemoWidgetEntry(date: .now, isRecording: false, recordingDuration: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VoiceMemoWidgetEntry>) -> Void) {
        let entry = VoiceMemoWidgetEntry(date: .now, isRecording: false, recordingDuration: nil)
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(300)))
        completion(timeline)
    }
}

struct VoiceMemoWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: VoiceMemoWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: entry.isRecording ? "mic.fill" : "mic")
                .font(.title2)
                .foregroundStyle(entry.isRecording ? .red : .primary)
        }
    }

    private var rectangularView: some View {
        HStack {
            Image(systemName: entry.isRecording ? "mic.fill" : "mic")
                .font(.title3)
                .foregroundStyle(entry.isRecording ? .red : .primary)

            VStack(alignment: .leading) {
                Text("PodNote")
                    .font(.headline)
                if entry.isRecording, let duration = entry.recordingDuration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("点击开始录音")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var cornerView: some View {
        Image(systemName: entry.isRecording ? "mic.fill" : "mic")
            .font(.title3)
            .foregroundStyle(entry.isRecording ? .red : .primary)
    }

    private var inlineView: some View {
        HStack {
            Image(systemName: "mic")
            if entry.isRecording {
                Text("录音中...")
            } else {
                Text("PodNote")
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

@main
struct VoiceMemoWidget: Widget {
    let kind: String = "VoiceMemoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VoiceMemoWidgetProvider()) { entry in
            VoiceMemoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "voicememo://record"))
        }
        .configurationDisplayName("PodNote")
        .description("快速开始录音")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

#Preview(as: .accessoryCircular) {
    VoiceMemoWidget()
} timeline: {
    VoiceMemoWidgetEntry(date: .now, isRecording: false, recordingDuration: nil)
    VoiceMemoWidgetEntry(date: .now, isRecording: true, recordingDuration: 65)
}
