import Foundation

extension Date {
    var recordingTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        let language = UserDefaults.standard.string(forKey: "app_language") ?? "system"
        let locale: Locale
        if language == "system" {
            locale = .current
        } else {
            locale = Locale(identifier: language)
        }
        
        let prefix = String(localized: "录音 ", locale: locale)
        return "\(prefix)\(formatter.string(from: self))"
    }

    var shortDisplay: String {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
