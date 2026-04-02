import SwiftUI

struct IntegrationSettingsView: View {
    private var notion = NotionService.shared
    private var google = GoogleDocsService.shared

    var body: some View {
        ZStack {
            RadialBackgroundView()

            ScrollView {
                VStack(spacing: 14) {
                    // Notion
                    notionCard

                    // Google Docs
                    googleDocsCard
                }
                .padding(.top, 8)
            }
        }
        .navigationTitle("第三方集成")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Notion

    private var notionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundStyle(GlassTheme.accent)
                Text("Notion")
                    .font(.headline)
                    .foregroundStyle(GlassTheme.textPrimary)
                Spacer()
                if notion.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if notion.isConnected {
                if let workspace = notion.workspaceName {
                    HStack {
                        Text("工作区")
                            .foregroundStyle(GlassTheme.textTertiary)
                        Spacer()
                        Text(workspace)
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .font(.subheadline)
                }

                if !notion.databases.isEmpty {
                    Divider().overlay(GlassTheme.borderSubtle)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("目标数据库")
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.textTertiary)

                        ForEach(notion.databases) { db in
                            Button {
                                notion.selectedDatabaseId = db.id
                            } label: {
                                HStack {
                                    Text(db.title)
                                        .foregroundStyle(GlassTheme.textPrimary)
                                    Spacer()
                                    if notion.selectedDatabaseId == db.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(GlassTheme.accent)
                                    }
                                }
                                .font(.subheadline)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Divider().overlay(GlassTheme.borderSubtle)

                HStack {
                    Button {
                        Task { await notion.fetchDatabases() }
                    } label: {
                        Text("刷新数据库")
                            .font(.subheadline)
                            .foregroundStyle(GlassTheme.accent)
                    }

                    Spacer()

                    Button {
                        notion.disconnect()
                    } label: {
                        Text("断开连接")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            } else {
                Button {
                    guard let window = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .flatMap(\.windows)
                        .first(where: \.isKeyWindow) else { return }
                    notion.authorize(from: window)
                } label: {
                    HStack {
                        if notion.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("连接 Notion")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .glassButton(prominent: true)
                .disabled(notion.isLoading)
            }
        }
        .padding(24)
        .glassCard()
        .padding(.horizontal)
    }

    // MARK: - Google Docs

    private var googleDocsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.richtext.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Google Docs")
                    .font(.headline)
                    .foregroundStyle(GlassTheme.textPrimary)
                Spacer()
                if google.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if google.isConnected {
                if let email = google.userEmail {
                    HStack {
                        Text("账号")
                            .foregroundStyle(GlassTheme.textTertiary)
                        Spacer()
                        Text(email)
                            .foregroundStyle(GlassTheme.textSecondary)
                    }
                    .font(.subheadline)
                }

                Divider().overlay(GlassTheme.borderSubtle)

                Button {
                    google.disconnect()
                } label: {
                    Text("断开连接")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Button {
                    guard let window = UIApplication.shared.connectedScenes
                        .compactMap({ $0 as? UIWindowScene })
                        .flatMap(\.windows)
                        .first(where: \.isKeyWindow) else { return }
                    google.authorize(from: window)
                } label: {
                    HStack {
                        if google.isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("连接 Google")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .glassButton(prominent: true)
                .disabled(google.isLoading)
            }
        }
        .padding(24)
        .glassCard()
        .padding(.horizontal)
    }
}
