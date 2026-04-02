import SwiftUI
import SwiftData

struct CustomTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var templateToEdit: CustomSummaryTemplate?

    @State private var name: String = ""
    @State private var systemPrompt: String = ""
    @State private var selectedIcon: String = "doc.text.fill"

    private let availableIcons = [
        "doc.text.fill",
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "flag.fill",
        "bookmark.fill",
        "tag.fill",
        "pencil.circle.fill",
        "brain.head.profile",
        "chart.bar.fill"
    ]

    var isEditing: Bool { templateToEdit != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                RadialBackgroundView()

                ScrollView {
                    VStack(spacing: 16) {
                        // Icon selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("图标")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textTertiary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(availableIcons, id: \.self) { icon in
                                        Button {
                                            selectedIcon = icon
                                        } label: {
                                            Image(systemName: icon)
                                                .font(.title3)
                                                .foregroundStyle(selectedIcon == icon ? .white : GlassTheme.textMuted)
                                                .frame(width: 44, height: 44)
                                                .background(selectedIcon == icon ? GlassTheme.accent.opacity(0.3) : Color.white.opacity(0.05))
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(selectedIcon == icon ? GlassTheme.accent : Color.clear, lineWidth: 1.5)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal)

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("模板名称")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textTertiary)

                            TextField("模板名称", text: $name)
                                .textFieldStyle(.plain)
                                .foregroundStyle(GlassTheme.textPrimary)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal)

                        // Prompt field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("提示词")
                                .font(.subheadline)
                                .foregroundStyle(GlassTheme.textTertiary)

                            TextEditor(text: $systemPrompt)
                                .foregroundStyle(GlassTheme.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding(20)
                        .glassCard()
                        .padding(.horizontal)

                        // Delete button (edit mode only)
                        if isEditing {
                            Button(role: .destructive) {
                                if let template = templateToEdit {
                                    modelContext.delete(template)
                                }
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("删除模板")
                                }
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .glassButton()
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(isEditing ? "编辑模板" : "添加模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(GlassTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .foregroundStyle(GlassTheme.accent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let template = templateToEdit {
                    name = template.name
                    systemPrompt = template.systemPrompt
                    selectedIcon = template.icon
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPrompt = systemPrompt.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedPrompt.isEmpty else { return }

        if let template = templateToEdit {
            template.name = trimmedName
            template.systemPrompt = trimmedPrompt
            template.icon = selectedIcon
        } else {
            let template = CustomSummaryTemplate(
                name: trimmedName,
                systemPrompt: trimmedPrompt,
                icon: selectedIcon
            )
            modelContext.insert(template)
        }
    }
}
