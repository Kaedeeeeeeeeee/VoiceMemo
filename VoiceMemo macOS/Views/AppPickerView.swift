import SwiftUI
import ScreenCaptureKit

struct AppPickerView: View {
    @Binding var selectedApp: SCRunningApplication?
    let availableApps: [SCRunningApplication]
    @State private var searchText = ""

    private var filteredApps: [SCRunningApplication] {
        if searchText.isEmpty {
            return availableApps
        }
        return availableApps.filter {
            $0.applicationName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 12) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(MacGlassTheme.textMuted)
                TextField("搜索应用", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(MacGlassTheme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .macGlassCard(radius: 10)

            if filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.title2)
                        .foregroundStyle(MacGlassTheme.textMuted)
                    Text("未找到应用")
                        .font(.caption)
                        .foregroundStyle(MacGlassTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(filteredApps, id: \.bundleIdentifier) { app in
                            AppGridItem(
                                app: app,
                                isSelected: selectedApp?.bundleIdentifier == app.bundleIdentifier
                            ) {
                                selectedApp = app
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

struct AppGridItem: View {
    let app: SCRunningApplication
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // App icon from NSWorkspace
                Group {
                    if let nsApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == app.bundleIdentifier }),
                       let icon = nsApp.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app.fill")
                            .font(.title)
                            .foregroundStyle(MacGlassTheme.textMuted)
                    }
                }
                .frame(width: 40, height: 40)

                Text(app.applicationName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? MacGlassTheme.textPrimary : MacGlassTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 72, height: 72)
            .padding(6)
            .macGlassCard(
                radius: 12,
                fill: isSelected ? MacGlassTheme.accent.opacity(0.3) : MacGlassTheme.surfaceLight,
                border: isSelected ? MacGlassTheme.accent : MacGlassTheme.borderSubtle
            )
        }
        .buttonStyle(.plain)
    }
}
