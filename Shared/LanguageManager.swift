import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"

    var id: String { self.rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .system:
            return "跟随系统"
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        case .japanese:
            return "日本語"
        }
    }
}

enum TranscriptionLanguage: String, CaseIterable, Identifiable {
    case autoDetect = "auto"
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .autoDetect: return String(localized: "自动检测")
        case .chinese: return "中文"
        case .english: return "English"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        }
    }

    /// AssemblyAI language code. Returns nil for autoDetect (uses language_detection instead).
    var languageCode: String? {
        switch self {
        case .autoDetect: return nil
        case .chinese: return "zh"
        case .english: return "en"
        case .japanese: return "ja"
        case .korean: return "ko"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        }
    }

    /// Language name in English for use in AI prompts
    var englishName: String {
        switch self {
        case .autoDetect: return "auto-detected"
        case .chinese: return "Chinese"
        case .english: return "English"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "app_language")
        }
    }

    @Published var transcriptionLanguage: TranscriptionLanguage {
        didSet {
            UserDefaults.standard.set(transcriptionLanguage.rawValue, forKey: "transcription_language")
        }
    }

    init() {
        self.selectedLanguage = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "app_language") ?? "system") ?? .system
        self.transcriptionLanguage = TranscriptionLanguage(rawValue: UserDefaults.standard.string(forKey: "transcription_language") ?? "auto") ?? .autoDetect
    }

    var locale: Locale? {
        if selectedLanguage == .system {
            return nil // Let SwiftUI use system locale
        } else {
            return Locale(identifier: selectedLanguage.rawValue)
        }
    }

    /// Whether AI prompts should use English. Returns true unless the user explicitly chose Chinese.
    var isEnglish: Bool {
        switch selectedLanguage {
        case .simplifiedChinese:
            return false
        case .english, .japanese:
            return true
        case .system:
            let isChinese = Locale.current.language.languageCode?.identifier.hasPrefix("zh") ?? false
            return !isChinese
        }
    }
}
