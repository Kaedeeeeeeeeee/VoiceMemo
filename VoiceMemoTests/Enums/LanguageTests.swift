import Testing
import Foundation
@testable import VoiceMemo_iOS

@Suite("AppLanguage Tests")
struct AppLanguageTests {

    @Test func rawValues() {
        #expect(AppLanguage.system.rawValue == "system")
        #expect(AppLanguage.english.rawValue == "en")
        #expect(AppLanguage.simplifiedChinese.rawValue == "zh-Hans")
        #expect(AppLanguage.japanese.rawValue == "ja")
    }

    @Test func allCasesCount() {
        #expect(AppLanguage.allCases.count == 4)
    }
}

@Suite("TranscriptionLanguage Tests")
struct TranscriptionLanguageTests {

    @Test func allCasesCount() {
        #expect(TranscriptionLanguage.allCases.count == 8)
    }

    @Test func languageCode_autoDetectIsNil() {
        #expect(TranscriptionLanguage.autoDetect.languageCode == nil)
    }

    @Test func languageCode_knownValues() {
        #expect(TranscriptionLanguage.chinese.languageCode == "zh")
        #expect(TranscriptionLanguage.english.languageCode == "en")
        #expect(TranscriptionLanguage.japanese.languageCode == "ja")
        #expect(TranscriptionLanguage.korean.languageCode == "ko")
        #expect(TranscriptionLanguage.spanish.languageCode == "es")
        #expect(TranscriptionLanguage.french.languageCode == "fr")
        #expect(TranscriptionLanguage.german.languageCode == "de")
    }

    @Test func languageCode_nonAutoAreNotNil() {
        for lang in TranscriptionLanguage.allCases where lang != .autoDetect {
            #expect(lang.languageCode != nil)
        }
    }

    @Test(arguments: TranscriptionLanguage.allCases)
    func englishName_isNotEmpty(lang: TranscriptionLanguage) {
        #expect(!lang.englishName.isEmpty)
    }

    @Test(arguments: TranscriptionLanguage.allCases)
    func displayName_isNotEmpty(lang: TranscriptionLanguage) {
        #expect(!lang.displayName.isEmpty)
    }

    @Test func englishName_specificValues() {
        #expect(TranscriptionLanguage.autoDetect.englishName == "auto-detected")
        #expect(TranscriptionLanguage.chinese.englishName == "Chinese")
        #expect(TranscriptionLanguage.english.englishName == "English")
    }
}

@Suite(.serialized)
struct LanguageManagerTests {

    @Test func locale_systemReturnsNil() {
        let original = LanguageManager.shared.selectedLanguage
        defer { LanguageManager.shared.selectedLanguage = original }

        LanguageManager.shared.selectedLanguage = .system
        #expect(LanguageManager.shared.locale == nil)
    }

    @Test func locale_englishContainsEn() {
        let original = LanguageManager.shared.selectedLanguage
        defer { LanguageManager.shared.selectedLanguage = original }

        LanguageManager.shared.selectedLanguage = .english
        #expect(LanguageManager.shared.locale?.identifier.contains("en") == true)
    }

    @Test func locale_chineseContainsZh() {
        let original = LanguageManager.shared.selectedLanguage
        defer { LanguageManager.shared.selectedLanguage = original }

        LanguageManager.shared.selectedLanguage = .simplifiedChinese
        let id = LanguageManager.shared.locale?.identifier ?? ""
        #expect(id.contains("zh"))
    }

    @Test func isEnglish_chinese() {
        let original = LanguageManager.shared.selectedLanguage
        defer { LanguageManager.shared.selectedLanguage = original }

        LanguageManager.shared.selectedLanguage = .simplifiedChinese
        #expect(LanguageManager.shared.isEnglish == false)
    }

    @Test func isEnglish_english() {
        let original = LanguageManager.shared.selectedLanguage
        defer { LanguageManager.shared.selectedLanguage = original }

        LanguageManager.shared.selectedLanguage = .english
        #expect(LanguageManager.shared.isEnglish == true)
    }

    @Test func isEnglish_japanese() {
        let original = LanguageManager.shared.selectedLanguage
        defer { LanguageManager.shared.selectedLanguage = original }

        LanguageManager.shared.selectedLanguage = .japanese
        #expect(LanguageManager.shared.isEnglish == false)
    }
}
