import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("录音", systemImage: "mic.fill", value: .home) {
                NavigationStack {
                    RecordingHomeView(switchToTab: { selectedTab = $0 })
                }
            }

            Tab("历史", systemImage: "clock.fill", value: .history) {
                NavigationStack {
                    RecordingHistoryView(switchToTab: { selectedTab = $0 })
                }
            }

            Tab("设置", systemImage: "gearshape.fill", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .tint(GlassTheme.accent)
    }
}
