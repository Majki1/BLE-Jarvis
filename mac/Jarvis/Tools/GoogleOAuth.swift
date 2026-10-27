import AppKit
import Foundation
import Network

// Desktop OAuth with loopback redirect: browser consent → local listener
// catches the code → token exchange → refresh token persisted. Pure helpers
// (authorizationURL, authCode) are unit-tested; the network dance is thin.
@MainActor
final class GoogleOAuth {
    struct NotConfigured: Error {}
    struct FlowFailed: Error { let reason: String }

    nonisolated static let scope = "https://www.googleapis.com/auth/calendar.events"
    private static let refreshTokenKey = "googleRefreshToken"

    static var clientCredentials: (id: String, secret: String)? {
        let env = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        guard let id = env["GOOGLE_OAUTH_CLIENT_ID"]
                ?? defaults.string(forKey: "googleClientID"),
              let secret = env["GOOGLE_OAUTH_CLIENT_SECRET"]
                ?? defaults.string(forKey: "googleClientSecret") else { return nil }
        return (id, secret)
    }

    static var isConnected: Bool {
        UserDefaults.standard.string(forKey: refreshTokenKey) != nil
    }

    nonisolated static func authorizationURL(clientID: String, redirectURI: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: scope),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
        ]
        return components.url!
    }

    nonisolated static func authCode(fromRequestLine line: String) -> String? {
        guard let target = line.split(separator: " ").dropFirst().first,
              let components = URLComponents(string: String(target)),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return nil }
        return code
    }

    // Opens the browser and resolves once the consent round-trip finishes.
    func connect() async throws {
        guard let client = Self.clientCredentials else { throw NotConfigured() }
        let listener = try NWListener(using: .tcp, on: .any)
        final class Flag: @unchecked Sendable { var resumed = false }
        let flag = Flag() // only touched on the .main listener queue
        let code = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            listener.newConnectionHandler = { connection in
                connection.start(queue: .main)
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    let line = request.components(separatedBy: "\r\n").first ?? ""
                    let body = "Jarvis is connected. You can close this tab."
                    let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
                    connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                    guard !flag.resumed, let code = Self.authCode(fromRequestLine: line) else { return }
                    flag.resumed = true
                    continuation.resume(returning: code)
                }
            }
            listener.stateUpdateHandler = { state in
                guard case .ready = state, let port = listener.port, !flag.resumed else { return }
                let redirect = "http://127.0.0.1:\(port.rawValue)"
                UserDefaults.standard.set(redirect, forKey: "googleRedirectURI")
                NSWorkspace.shared.open(
                    Self.authorizationURL(clientID: client.id, redirectURI: redirect))
            }
            listener.start(queue: .main)
        }
        listener.cancel()
        try await exchange(code: code, client: client)
    }

    private func exchange(code: String, client: (id: String, secret: String)) async throws {
        let redirect = UserDefaults.standard.string(forKey: "googleRedirectURI") ?? ""
        let token = try await Self.tokenRequest(form: [
            "code": code,
            "client_id": client.id,
            "client_secret": client.secret,
            "redirect_uri": redirect,
            "grant_type": "authorization_code",
        ])
        guard let refresh = token.refresh_token else {
            throw FlowFailed(reason: "no refresh token in response")
        }
        UserDefaults.standard.set(refresh, forKey: Self.refreshTokenKey)
    }

    // Short-lived access token from the stored refresh token.
    static func accessToken() async throws -> String {
        guard let client = clientCredentials,
              let refresh = UserDefaults.standard.string(forKey: refreshTokenKey) else {
            throw NotConfigured()
        }
        let token = try await tokenRequest(form: [
            "client_id": client.id,
            "client_secret": client.secret,
            "refresh_token": refresh,
            "grant_type": "refresh_token",
        ])
        return token.access_token
    }

    private struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
    }

    private static func tokenRequest(form: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = form
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw FlowFailed(reason: String(data: data, encoding: .utf8).map {
                String($0.prefix(300)) } ?? "token request failed")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }
}
