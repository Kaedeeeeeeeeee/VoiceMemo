import SwiftUI
import SwiftData

enum MacSidebarItem: String, CaseIterable, Identifiable {
    case recording = "录音"
    case history = "录音列表"
    case settings = "设置"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .recording: return "mic.fill"
        case .history: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct MacMainView: View {
    @State private var selectedSidebar: MacSidebarItem? = .recording
    @State private var selectedRecording: Recording?

    var body: some View {
        NavigationSplitView {
            List(MacSidebarItem.allCases, selection: $selectedSidebar) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .foregroundStyle(MacGlassTheme.textSecondary)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 200)
        } content: {
            Group {
                switch selectedSidebar {
                case .recording:
                    MacRecordingView()
                case .history:
                    MacRecordingListView(selectedRecording: $selectedRecording)
                case .settings:
                    MacSettingsView()
                case .none:
                    MacRecordingView()
                }
            }
            .navigationSplitViewColumnWidth(min: 300, ideal: 400)
        } detail: {
            if let recording = selectedRecording {
                MacRecordingDetailView(recording: recording)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundStyle(MacGlassTheme.textMuted)
                    Text("选择一条录音查看详情")
                        .font(.title3)
                        .foregroundStyle(MacGlassTheme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MacGlassTheme.background)
            }
        }
        .background(MacGlassTheme.background)
    }
}
