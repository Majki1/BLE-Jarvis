import Foundation

// Shared Google Calendar REST access for the change source and the
// block-it writer (CalendarTool keeps its own read path for the agent).
@MainActor
enum GoogleCalendarAPI {
    static func todaysEvents() async -> [CalEvent] {
        guard let token = try? await GoogleOAuth.accessToken() else { return [] }
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
            .init(name: "maxResults", value: "30"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 8
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return parse(eventsResponse: data)
    }

    static func insertEvent(title: String, start: Date, end: Date) async -> Bool {
        guard let token = try? await GoogleOAuth.accessToken() else { return false }
        var request = URLRequest(
            url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let iso = ISO8601DateFormatter()
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "summary": title,
            "description": "Blocked by Jarvis — your time, defended.",
            "start": ["dateTime": iso.string(from: start)],
            "end": ["dateTime": iso.string(from: end)],
        ])
        guard let (_, response) = try? await URLSession.shared.data(for: request) else {
            return false
        }
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    nonisolated static func parse(eventsResponse data: Data) -> [CalEvent] {
        struct Response: Decodable {
            let items: [Item]
            struct Item: Decodable {
                let id: String
                let summary: String?
                let start: Stamp
                let end: Stamp
                struct Stamp: Decodable { let dateTime: String? }
            }
        }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            return []
        }
        let iso = ISO8601DateFormatter()
        return decoded.items.compactMap { item in
            guard let startString = item.start.dateTime, let start = iso.date(from: startString),
                  let endString = item.end.dateTime, let end = iso.date(from: endString) else {
                return nil   // all-day events aren't freeable "slots"
            }
            return CalEvent(id: item.id, summary: item.summary ?? "Untitled",
                            start: start, end: end)
        }
    }
}

// AwayChangeSource adapter: snapshots the calendar on the first poll after
// departure, then reports freed slots as away items.
@MainActor
final class CalendarChangeSource: AwayChangeSource {
    private var snapshot: [CalEvent]?
    private var snapshotSince: Date?

    func changes(since: Date) async -> [AwayItem] {
        if snapshotSince != since {
            snapshot = nil
            snapshotSince = since
        }
        let current = await GoogleCalendarAPI.todaysEvents()
        guard let snapshot else {
            self.snapshot = current
            return []
        }
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        return CalendarDiff.freedSlots(snapshot: snapshot, current: current, now: Date())
            .map { slot in
                AwayItem(id: "freed-\(slot.id)", kind: .calendar,
                         title: "Freed: \(slot.summary)",
                         detail: "\(clock.string(from: slot.start))–\(clock.string(from: slot.end)) opened up",
                         at: Date())
            }
    }

    // The latest snapshot lets the suggestion composer see freed slot times.
    func freedSlotEvents() async -> [CalEvent] {
        guard let snapshot else { return [] }
        let current = await GoogleCalendarAPI.todaysEvents()
        return CalendarDiff.freedSlots(snapshot: snapshot, current: current, now: Date())
    }
}
