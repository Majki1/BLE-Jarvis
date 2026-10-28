import Foundation

// Issues of yours that changed while you were away — free REST polling.
@MainActor
final class JiraChangeSource: AwayChangeSource {
    func changes(since: Date) async -> [AwayItem] {
        guard let creds = JiraTool.credentials else { return [] }
        let minutes = max(1, Int(Date().timeIntervalSince(since) / 60) + 1)
        var components = URLComponents(
            url: creds.site.appending(path: "rest/api/3/search/jql"),
            resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "jql",
                  value: "assignee = currentUser() AND updated >= \"-\(minutes)m\" ORDER BY updated DESC"),
            .init(name: "maxResults", value: "10"),
            .init(name: "fields", value: "summary,status,updated"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 8
        let basic = Data("\(creds.email):\(creds.token)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return Self.items(from: data)
    }

    nonisolated static func items(from data: Data) -> [AwayItem] {
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            return []
        }
        return decoded.issues.map { issue in
            AwayItem(id: "\(issue.key)@\(issue.fields.updated ?? "")",
                     kind: .jira,
                     title: "\(issue.key) · \(issue.fields.summary)",
                     detail: "Status: \(issue.fields.status.name)",
                     at: Date())
        }
    }

    private struct Response: Decodable {
        let issues: [Issue]
        struct Issue: Decodable {
            let key: String
            let fields: Fields
            struct Fields: Decodable {
                let summary: String
                let updated: String?
                let status: Status
                struct Status: Decodable { let name: String }
            }
        }
    }
}
