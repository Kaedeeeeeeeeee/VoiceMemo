import Foundation
import AuthenticationServices
import Observation

@Observable
final class GoogleDocsService: NSObject {
    static let shared = GoogleDocsService()

    private(set) var isConnected = false
    private(set) var userEmail: String?
    private(set) var isLoading = false

    private static let accessTokenKey = "google_access_token"
    private static let refreshTokenKey = "google_refresh_token"
    private static let emailKey = "google_user_email"

    private override init() {
        super.init()
        if let token = KeychainHelper.loadString(forKey: Self.refreshTokenKey), !token.isEmpty {
            isConnected = true
            userEmail = UserDefaults.standard.string(forKey: Self.emailKey)
        }
    }

    // MARK: - OAuth

    func authorize(from anchor: ASPresentationAnchor) {
        let clientId = APIConfig.googleClientId
        let redirectURI = "\(APIConfig.proxyBaseURL)/google-callback"
        let scope = "https://www.googleapis.com/auth/documents https://www.googleapis.com/auth/drive.file https://www.googleapis.com/auth/userinfo.email"

        guard var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else { return }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
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

        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "code": code,
            "client_id": APIConfig.googleClientId,
            "client_secret": APIConfig.googleClientSecret,
            "redirect_uri": "\(APIConfig.proxyBaseURL)/google-callback",
            "grant_type": "authorization_code",
        ]
        request.httpBody = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&").data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else { return }

        KeychainHelper.save(accessToken, forKey: Self.accessTokenKey)

        if let refreshToken = json["refresh_token"] as? String {
            KeychainHelper.save(refreshToken, forKey: Self.refreshTokenKey)
        }

        isConnected = true
        await fetchUserEmail()
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async -> String? {
        guard let refreshToken = KeychainHelper.loadString(forKey: Self.refreshTokenKey) else { return nil }

        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "refresh_token": refreshToken,
            "client_id": APIConfig.googleClientId,
            "client_secret": APIConfig.googleClientSecret,
            "grant_type": "refresh_token",
        ]
        request.httpBody = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newToken = json["access_token"] as? String else { return nil }

        KeychainHelper.save(newToken, forKey: Self.accessTokenKey)
        return newToken
    }

    private func getValidToken() async -> String? {
        if let token = KeychainHelper.loadString(forKey: Self.accessTokenKey) {
            // Try existing token first; if API call fails with 401, caller should refresh
            return token
        }
        return await refreshAccessToken()
    }

    // MARK: - Disconnect

    func disconnect() {
        KeychainHelper.delete(forKey: Self.accessTokenKey)
        KeychainHelper.delete(forKey: Self.refreshTokenKey)
        UserDefaults.standard.removeObject(forKey: Self.emailKey)
        isConnected = false
        userEmail = nil
    }

    // MARK: - User Info

    private func fetchUserEmail() async {
        guard let token = await getValidToken() else { return }

        let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let email = json["email"] as? String else { return }

        userEmail = email
        UserDefaults.standard.set(email, forKey: Self.emailKey)
    }

    // MARK: - Create Document

    func createDocument(title: String, content: String) async -> Bool {
        guard var token = await getValidToken() else { return false }

        // Step 1: Create empty document
        let createURL = URL(string: "https://docs.googleapis.com/v1/documents")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createRequest.httpBody = try? JSONSerialization.data(withJSONObject: ["title": title])

        var createData: Data
        var createResponse: URLResponse

        do {
            (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        } catch {
            return false
        }

        // If 401, refresh token and retry
        if let httpResponse = createResponse as? HTTPURLResponse, httpResponse.statusCode == 401 {
            guard let newToken = await refreshAccessToken() else { return false }
            token = newToken
            createRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            do {
                (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
            } catch {
                return false
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: createData) as? [String: Any],
              let documentId = json["documentId"] as? String else { return false }

        // Step 2: Insert content via batchUpdate
        let updateURL = URL(string: "https://docs.googleapis.com/v1/documents/\(documentId):batchUpdate")!
        var updateRequest = URLRequest(url: updateURL)
        updateRequest.httpMethod = "POST"
        updateRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let updateBody: [String: Any] = [
            "requests": [
                [
                    "insertText": [
                        "location": ["index": 1],
                        "text": content,
                    ]
                ]
            ]
        ]
        updateRequest.httpBody = try? JSONSerialization.data(withJSONObject: updateBody)

        guard let (_, updateResponse) = try? await URLSession.shared.data(for: updateRequest),
              let updateHttp = updateResponse as? HTTPURLResponse,
              updateHttp.statusCode == 200 else { return false }

        return true
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleDocsService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
