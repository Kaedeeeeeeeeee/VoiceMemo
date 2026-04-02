import UIKit
import EventKit

enum IntegrationApp: String, CaseIterable {
    case bear
    case obsidian
    case things
    case omniFocus

    var displayName: String {
        switch self {
        case .bear: return "Bear"
        case .obsidian: return "Obsidian"
        case .things: return "Things"
        case .omniFocus: return "OmniFocus"
        }
    }

    var iconName: String {
        switch self {
        case .bear: return "bear"
        case .obsidian: return "diamond"
        case .things: return "checkmark.circle"
        case .omniFocus: return "target"
        }
    }

    fileprivate var scheme: String {
        switch self {
        case .bear: return "bear"
        case .obsidian: return "obsidian"
        case .things: return "things"
        case .omniFocus: return "omnifocus"
        }
    }
}

enum IntegrationService {

    // MARK: - URL Scheme Integrations

    static func openInBear(title: String, text: String) {
        var components = URLComponents(string: "bear://x-callback-url/create")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "tags", value: "PodNote"),
        ]
        openURL(components.url)
    }

    static func openInObsidian(title: String, text: String) {
        var components = URLComponents(string: "obsidian://new")!
        components.queryItems = [
            URLQueryItem(name: "name", value: title),
            URLQueryItem(name: "content", value: text),
        ]
        openURL(components.url)
    }

    static func openInThings(title: String, notes: String) {
        var components = URLComponents(string: "things:///add")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "notes", value: notes),
        ]
        openURL(components.url)
    }

    static func openInOmniFocus(title: String, notes: String) {
        var components = URLComponents(string: "omnifocus:///add")!
        components.queryItems = [
            URLQueryItem(name: "name", value: title),
            URLQueryItem(name: "note", value: notes),
        ]
        openURL(components.url)
    }

    // MARK: - Reminders

    static func createReminder(title: String, notes: String, completion: @escaping (Bool, Error?) -> Void) {
        let store = EKEventStore()
        store.requestFullAccessToReminders { granted, error in
            guard granted, error == nil else {
                DispatchQueue.main.async { completion(false, error) }
                return
            }

            let reminder = EKReminder(eventStore: store)
            reminder.title = title
            reminder.notes = notes
            reminder.calendar = store.defaultCalendarForNewReminders()

            do {
                try store.save(reminder, commit: true)
                DispatchQueue.main.async { completion(true, nil) }
            } catch {
                DispatchQueue.main.async { completion(false, error) }
            }
        }
    }

    // MARK: - Availability

    static func isAvailable(_ app: IntegrationApp) -> Bool {
        guard let url = URL(string: "\(app.scheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    // MARK: - Private

    private static func openURL(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }
}
