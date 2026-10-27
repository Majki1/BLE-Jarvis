import Foundation

// Today's events from the user's primary Google Calendar.
@MainActor
final class CalendarTool: AgentTool {
    let spec = ToolSpec(
        name: "get_calendar",
        description: "Get today's calendar events for the user.",
        parametersJSON: #"{"type":"object","properties":{},"required":[]}"#)

    func invoke(argumentsJSON: String) async -> Result<String, Error> {
        do {
            let token = try await GoogleOAuth.accessToken()
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let iso = ISO8601DateFormatter()
            var components = URLComponents(
                string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!
            components.queryItems = [
                .init(name: "timeMin", value: iso.string(from: start)),
                .init(name: "timeMax", value: iso.string(from: end)),
                .init(name: "singleEvents", value: "true"),
                .init(name: "orderBy", value: "startTime"),
                .init(name: "maxResults", value: "12"),
            ]
            var request = URLRequest(url: components.url!)
            request.timeoutInterval = 8
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            return .success(try Self.format(eventsResponse: data, timeZone: .current))
        } catch {
            return .failure(error)
        }
    }

    nonisolated static func format(eventsResponse data: Data,
                                   timeZone: TimeZone) throws -> String {
        let decoded = try JSONDecoder().decode(EventsResponse.self, from: data)
        guard !decoded.items.isEmpty else { return "Nothing on the calendar today." }

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        clock.timeZone = timeZone

        return decoded.items.map { event in
            if let dateTime = event.start.dateTime, let date = parser.date(from: dateTime) {
                return "\(clock.string(from: date)) \(event.summary)"
            }
            return "All day: \(event.summary)"
        }.joined(separator: "\n")
    }

    private struct EventsResponse: Decodable {
        let items: [Event]
        struct Event: Decodable {
            let summary: String
            let start: Start
            struct Start: Decodable {
                let dateTime: String?
                let date: String?
            }
        }
    }
}
