import Foundation

// Live Jira: the user's open tickets, newest activity first. Credentials via
// env (ATLASSIAN_*) or UserDefaults jiraSite / jiraEmail / jiraAPIToken.
@MainActor
final class JiraTool: AgentTool {
    struct NotConfigured: Error {}

    let spec = ToolSpec(
        name: "get_jira",
        description: "Get the user's open Jira tickets, most recently updated first.",
        parametersJSON: #"{"type":"object","properties":{},"required":[]}"#)

    static var credentials: (site: URL, email: String, token: String)? {
        let env = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        guard let site = (env["ATLASSIAN_SITE"] ?? defaults.string(forKey: "jiraSite"))
                .flatMap(URL.init(string:)),
              let email = env["ATLASSIAN_EMAIL"] ?? defaults.string(forKey: "jiraEmail"),
              let token = env["ATLASSIAN_API_TOKEN"] ?? defaults.string(forKey: "jiraAPIToken")
        else { return nil }
        return (site, email, token)
    }

    func invoke(argumentsJSON: String) async -> Result<String, Error> {
        guard let creds = Self.credentials else { return .failure(NotConfigured()) }
        var components = URLComponents(
            url: creds.site.appending(path: "rest/api/3/search/jql"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "jql",
                  value: "assignee = currentUser() AND statusCategory != Done ORDER BY updated DESC"),
            .init(name: "maxResults", value: "8"),
            .init(name: "fields", value: "summary,status"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 8
        let basic = Data("\(creds.email):\(creds.token)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            return .success(try Self.format(searchResponse: data))
        } catch {
            return .failure(error)
        }
    }

    nonisolated static func format(searchResponse data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        guard !decoded.issues.isEmpty else { return "No open tickets assigned to you." }
        return decoded.issues
            .map { "\($0.key) (\($0.fields.status.name)): \($0.fields.summary)" }
            .joined(separator: "\n")
    }

    private struct SearchResponse: Decodable {
        let issues: [Issue]
        struct Issue: Decodable {
            let key: String
            let fields: Fields
            struct Fields: Decodable {
                let summary: String
                let status: Status
                struct Status: Decodable { let name: String }
            }
        }
    }
}
