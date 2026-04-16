import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @Environment(PendingActionRouter.self) private var pendingActionRouter
    @Binding var triggerRecord: Bool

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("录音", systemImage: "mic.fill", value: .home) {
                NavigationStack {
                    RecordingHomeView(switchToTab: { selectedTab = $0 }, triggerRecord: $triggerRecord)
                }
            }

            Tab("历史", systemImage: "clock.fill", value: .history) {
                NavigationStack {
                    RecordingHistoryView(switchToTab: { selectedTab = $0 })
                }
            }

            Tab("知识库", systemImage: "book.closed.fill", value: .knowledgeBase) {
                NavigationStack {
                    KnowledgeBaseView()
                }
            }

            Tab("设置", systemImage: "gearshape.fill", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(GlassTheme.accent)
        .onChange(of: triggerRecord) {
            if triggerRecord {
                selectedTab = .home
            }
        }
        .onChange(of: pendingActionRouter.pendingMarker) { _, new in
            if new != nil { selectedTab = .home }
        }
        .onChange(of: pendingActionRouter.pendingPhoto) { _, new in
            if new != nil { selectedTab = .home }
        }
    }
}
