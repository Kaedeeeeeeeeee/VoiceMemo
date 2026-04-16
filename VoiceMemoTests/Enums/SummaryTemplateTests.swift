import Testing
@testable import VoiceMemo_iOS

@Suite("SummaryTemplate Tests")
struct SummaryTemplateTests {

    @Test func allCasesCount() {
        #expect(SummaryTemplate.allCases.count == 8)
    }

    @Test(arguments: SummaryTemplate.allCases)
    func displayNameIsNotEmpty(template: SummaryTemplate) {
        #expect(!template.displayName.isEmpty)
    }

    @Test(arguments: SummaryTemplate.allCases)
    func iconIsNotEmpty(template: SummaryTemplate) {
        #expect(!template.icon.isEmpty)
    }

    @Test(arguments: SummaryTemplate.allCases)
    func systemPromptIsNotEmpty(template: SummaryTemplate) {
        #expect(!template.systemPrompt.isEmpty)
    }

    @Test(arguments: SummaryTemplate.allCases)
    func systemPromptContainsMarkdown(template: SummaryTemplate) {
        let prompt = template.systemPrompt.lowercased()
        #expect(prompt.contains("markdown"))
    }

    @Test func idMatchesRawValue() {
        for template in SummaryTemplate.allCases {
            #expect(template.id == template.rawValue)
        }
    }
}

@Suite(.serialized)
struct SummaryTemplateLanguageTests {

    @Test func systemPrompt_changesWithLanguage() {
        let original = LanguageManager.shared.selectedLanguage
        defer { LanguageManager.shared.selectedLanguage = original }

        LanguageManager.shared.selectedLanguage = .english
        let englishPrompt = SummaryTemplate.meetingNotes.systemPrompt

        LanguageManager.shared.selectedLanguage = .simplifiedChinese
        let chinesePrompt = SummaryTemplate.meetingNotes.systemPrompt

        #expect(englishPrompt != chinesePrompt)
    }

    @Test func englishPrompt_containsEnglishText() {
        let original = LanguageManager.shared.selectedLanguage
        defer { LanguageManager.shared.selectedLanguage = original }

        LanguageManager.shared.selectedLanguage = .english
        let prompt = SummaryTemplate.general.systemPrompt
        #expect(prompt.contains("summary") || prompt.contains("Summary") || prompt.contains("Markdown"))
    }
}
