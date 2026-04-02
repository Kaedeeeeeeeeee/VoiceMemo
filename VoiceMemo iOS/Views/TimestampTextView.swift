import SwiftUI

struct TimestampTextView: View {
    let text: String

    var body: some View {
        let segments = parseSegments(text)
        segments.reduce(Text("")) { result, segment in
            switch segment {
            case .text(let str):
                return result + Text(str)
                    .foregroundColor(Color(GlassTheme.textSecondary))
            case .timestamp(let label, let totalSeconds):
                return result + Text(" \(label) ")
                    .font(.caption.monospaced())
                    .foregroundColor(GlassTheme.accent)
            }
        }
        .font(.body)
    }

    private enum Segment {
        case text(String)
        case timestamp(String, Int) // label, total seconds
    }

    private func parseSegments(_ input: String) -> [Segment] {
        var segments: [Segment] = []
        let pattern = #"\[(\d{2}):(\d{2})\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [.text(input)]
        }

        let nsString = input as NSString
        var lastEnd = 0

        let matches = regex.matches(in: input, range: NSRange(location: 0, length: nsString.length))
        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastEnd {
                let textRange = NSRange(location: lastEnd, length: matchRange.location - lastEnd)
                segments.append(.text(nsString.substring(with: textRange)))
            }

            let minutesStr = nsString.substring(with: match.range(at: 1))
            let secondsStr = nsString.substring(with: match.range(at: 2))
            let minutes = Int(minutesStr) ?? 0
            let seconds = Int(secondsStr) ?? 0
            let totalSeconds = minutes * 60 + seconds
            let label = nsString.substring(with: matchRange)
            segments.append(.timestamp(label, totalSeconds))

            lastEnd = matchRange.location + matchRange.length
        }

        if lastEnd < nsString.length {
            segments.append(.text(nsString.substring(from: lastEnd)))
        }

        return segments
    }
}

/// A version of TimestampTextView that supports tap-to-seek
struct TappableTimestampTextView: View {
    let text: String

    var body: some View {
        let lines = text.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    Spacer().frame(height: 4)
                } else {
                    TimestampLineView(line: line)
                }
            }
        }
    }
}

private struct TimestampLineView: View {
    let line: String

    var body: some View {
        let pattern = #"\[(\d{2}):(\d{2})\]"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let nsLine = line as NSString
            let minutesStr = nsLine.substring(with: match.range(at: 1))
            let secondsStr = nsLine.substring(with: match.range(at: 2))
            let minutes = Int(minutesStr) ?? 0
            let seconds = Int(secondsStr) ?? 0
            let totalSeconds = minutes * 60 + seconds
            let timestampLabel = nsLine.substring(with: match.range)
            let rest = nsLine.substring(from: match.range.location + match.range.length)

            HStack(alignment: .top, spacing: 4) {
                Button {
                    NotificationCenter.default.post(
                        name: .seekToTime,
                        object: nil,
                        userInfo: ["seconds": TimeInterval(totalSeconds)]
                    )
                } label: {
                    Text(timestampLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(GlassTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(GlassTheme.accent.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Text(.init(rest))
                    .font(.body)
                    .foregroundStyle(GlassTheme.textSecondary)
            }
        } else {
            Text(.init(line))
                .font(.body)
                .foregroundStyle(GlassTheme.textSecondary)
        }
    }
}

