import Foundation
import SwiftData

@Model
final class CustomSummaryTemplate {
    var id: UUID
    var name: String
    var systemPrompt: String
    var icon: String
    var createdAt: Date
    var sortOrder: Int

    init(
        name: String,
        systemPrompt: String,
        icon: String = "doc.text.fill",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.systemPrompt = systemPrompt
        self.icon = icon
        self.createdAt = .now
        self.sortOrder = sortOrder
    }
}
