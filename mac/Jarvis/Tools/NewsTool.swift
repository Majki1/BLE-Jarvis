import Foundation

// Live headlines from public RSS — no key, no cost. Feeds configurable via
// UserDefaults "newsFeeds" (string array of URLs).
@MainActor
final class NewsTool: AgentTool {
    let spec = ToolSpec(
        name: "get_news",
        description: "Fetch today's top news headlines.",
        parametersJSON: #"{"type":"object","properties":{},"required":[]}"#)

    private let defaultFeeds = [
        "https://feeds.bbci.co.uk/news/world/rss.xml",
        "https://hnrss.org/frontpage",
    ]

    func invoke(argumentsJSON: String) async -> Result<String, Error> {
        let feeds = (UserDefaults.standard.stringArray(forKey: "newsFeeds") ?? defaultFeeds)
            .compactMap(URL.init(string:))
        var headlines: [String] = []
        for feed in feeds {
            var request = URLRequest(url: feed)
            request.timeoutInterval = 5
            if let (data, _) = try? await URLSession.shared.data(for: request) {
                headlines += RSSParser.headlines(fromXML: data, limit: 3)
            }
        }
        guard !headlines.isEmpty else {
            return .success("No headlines reachable right now.")
        }
        return .success(headlines.map { "- \($0)" }.joined(separator: "\n"))
    }
}
