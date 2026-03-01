import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { self.rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .system:
            return "跟随系统"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }
}
class LanguageManager: ObservableObject {
    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "app_language")
        }
    }

    init() {
        self.selectedLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app_language") ?? "system") ?? .system
    }

    var locale: Locale? {
        if selectedLanguage == .system {
            return nil // Let SwiftUI use system locale
        } else {
            return Locale(identifier: selectedLanguage.rawValue)
        }
    }
}
