import Foundation
import AuthenticationServices
import Observation

@Observable
final class NotionService: NSObject {
    static let shared = NotionService()

    private(set) var isConnected = false
    private(set) var workspaceName: String?
    private(set) var databases: [NotionDatabase] = []
    private(set) var isLoading = false

    var selectedDatabaseId: String? {
        get { UserDefaults.standard.string(forKey: "notionSelectedDatabaseId") }
        set { UserDefaults.standard.set(newValue, forKey: "notionSelectedDatabaseId") }
    }

    private static let tokenKey = "notion_access_token"
    private static let workspaceKey = "notion_workspace_name"

    private override init() {
        super.init()
        if let token = KeychainHelper.loadString(forKey: Self.tokenKey), !token.isEmpty {
            isConnected = true
            workspaceName = UserDefaults.standard.string(forKey: Self.workspaceKey)
        }
    }

    // MARK: - OAuth

    func authorize(from anchor: ASPresentationAnchor) {
        let clientId = APIConfig.notionClientId
        let redirectURI = "\(APIConfig.proxyBaseURL)/notion-callback"

        guard var components = URLComponents(string: "https://api.notion.com/v1/oauth/authorize") else { return }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "owner", value: "user"),
        ]
        guard let url = components.url else { return }

        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "podnote") { [weak self] callbackURL, error in
            guard let self, let callbackURL, error == nil else { return }
            guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value else { return }

            Task { @MainActor in
                await self.exchangeCode(code)
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    private func exchangeCode(_ code: String) async {
        isLoading = true
        defer { isLoading = false }

        let url = URL(string: "https://api.notion.com/v1/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let credentials = "\(APIConfig.notionClientId):\(APIConfig.notionClientSecret)"
        let encoded = Data(credentials.utf8).base64EncodedString()
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": "\(APIConfig.proxyBaseURL)/notion-callback",
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["access_token"] as? String else { return }

        KeychainHelper.save(token, forKey: Self.tokenKey)

        let workspace = (json["workspace_name"] as? String) ?? "Notion"
        UserDefaults.standard.set(workspace, forKey: Self.workspaceKey)

        isConnected = true
        workspaceName = workspace

        await fetchDatabases()
    }

    // MARK: - Disconnect

    func disconnect() {
        KeychainHelper.delete(forKey: Self.tokenKey)
        UserDefaults.standard.removeObject(forKey: Self.workspaceKey)
        UserDefaults.standard.removeObject(forKey: "notionSelectedDatabaseId")
        isConnected = false
        workspaceName = nil
        databases = []
    }

    // MARK: - API

    func fetchDatabases() async {
        guard let token = KeychainHelper.loadString(forKey: Self.tokenKey) else { return }

        let url = URL(string: "https://api.notion.com/v1/search")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "filter": ["value": "database", "property": "object"]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]] else { return }

        databases = results.compactMap { item in
            guard let id = item["id"] as? String,
                  let titleArray = (item["title"] as? [[String: Any]]),
                  let title = titleArray.first?["plain_text"] as? String else { return nil }
            return NotionDatabase(id: id, title: title)
        }
    }

    func createPage(title: String, content: String) async -> Bool {
        guard let token = KeychainHelper.loadString(forKey: Self.tokenKey) else { return false }

        let url = URL(string: "https://api.notion.com/v1/pages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-06-28", forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build content blocks (split into 2000-char chunks for Notion's limit)
        let chunks = stride(from: 0, to: content.count, by: 2000).map { start in
            let startIndex = content.index(content.startIndex, offsetBy: start)
            let endIndex = content.index(startIndex, offsetBy: min(2000, content.count - start))
            return String(content[startIndex..<endIndex])
        }

        let children: [[String: Any]] = chunks.map { chunk in
            [
                "object": "block",
                "type": "paragraph",
                "paragraph": [
                    "rich_text": [
                        ["type": "text", "text": ["content": chunk]]
                    ]
                ]
            ]
        }

        var parent: [String: String]
        if let dbId = selectedDatabaseId {
            parent = ["database_id": dbId]
        } else {
            parent = ["page_id": ""]
            // Fallback: create as a standalone page if no database selected
            // This won't work without a parent, so require database selection
            return false
        }

        let body: [String: Any] = [
            "parent": parent,
            "properties": [
                "title": [
                    "title": [
                        ["text": ["content": title]]
                    ]
                ]
            ],
            "children": children,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else { return false }

        return true
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension NotionService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

// MARK: - Models

struct NotionDatabase: Identifiable, Hashable {
    let id: String
    let title: String
}
