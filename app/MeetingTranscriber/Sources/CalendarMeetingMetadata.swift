import Foundation

struct CalendarDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
}

struct CalendarAttendee: Codable, Equatable, Sendable {
    let name: String
}

/// Minimal enrichment only. No event body, location, identifiers or speaker embeddings.
struct CalendarMeetingMetadata: Codable, Equatable, Sendable {
    var title: String?
    var start: Date
    var end: Date
    var attendees: [CalendarAttendee]
    var meetingURL: URL?
    var sourceCalendarName: String?
}

enum CalendarMatchScorer {
    /// Match only overlapping events. A tie or small margin is ambiguous and attaches nothing.
    static func match(
        events: [CalendarMeetingMetadata], start: Date, detectedTitle: String, appName: String? = nil,
    ) -> CalendarMeetingMetadata? {
        let scored = events.compactMap { event -> (CalendarMeetingMetadata, Int)? in
            guard event.start <= start.addingTimeInterval(300), event.end > start else { return nil }
            let detectedProvider = appName.flatMap { providerHint($0.lowercased()) }
            let eventProvider = event.meetingURL?.host.flatMap { providerForHost($0.lowercased()) }
            if let detectedProvider, let eventProvider, detectedProvider != eventProvider { return nil }
            var score = event.start <= start ? 20 : 10
            if eventProvider != nil { score += 5 }
            if abs(event.start.timeIntervalSince(start)) <= 300 { score += 5 }
            let title = detectedTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if title.count >= 5, let candidate = event.title?.lowercased(), candidate.count >= 5,
               candidate == title || candidate.contains(title) || title.contains(candidate), !candidate.isEmpty {
                score += 10
            }
            return (event, score)
        }.sorted { $0.1 > $1.1 }
        guard let first = scored.first else { return nil }
        if scored.count > 1, first.1 - scored[1].1 < 5 { return nil }
        return first.0
    }

    private static func providerHint(_ app: String) -> String? {
        for provider in ["teams", "zoom", "webex"] where app.contains(provider) {
            return provider
        }
        return nil
    }

    private static func providerForHost(_ host: String) -> String? {
        for (domain, provider) in [
            ("teams.microsoft.com", "teams"),
            ("teams.live.com", "teams"),
            ("zoom.us", "zoom"),
            ("webex.com", "webex"),
            ("meet.google.com", "meet"),
        ] {
            if host == domain || host.hasSuffix("." + domain) { return provider }
        }
        return nil
    }
}
