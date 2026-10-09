import EventKit
import Foundation

@MainActor
protocol CalendarProviding {
    var isAuthorized: Bool { get }
    func requestAccess() async throws -> Bool
    func calendars() -> [CalendarDescriptor]
    func matchingEvent(start: Date, title: String, calendarIDs: [String], appName: String) -> CalendarMeetingMetadata?
}

/// Permission is requested only by a user action in Settings, never by recording or a pipeline job.
@MainActor
final class EventKitCalendarProvider: CalendarProviding {
    private let store = EKEventStore()

    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func calendars() -> [CalendarDescriptor] {
        guard isAuthorized else { return [] }
        return store.calendars(for: .event).map { CalendarDescriptor(id: $0.calendarIdentifier, title: $0.title) }
            .sorted { $0.title < $1.title }
    }

    func matchingEvent(start: Date, title: String, calendarIDs: [String], appName: String) -> CalendarMeetingMetadata? {
        guard isAuthorized, !calendarIDs.isEmpty else { return nil }
        let selected = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !selected.isEmpty else { return nil }
        let predicate = store.predicateForEvents(
            withStart: start.addingTimeInterval(-300), end: start.addingTimeInterval(300), calendars: selected,
        )
        let events = store.events(matching: predicate).compactMap { event -> CalendarMeetingMetadata? in
            guard !event.isAllDay, let start = event.startDate, let end = event.endDate else { return nil }
            return CalendarMeetingMetadata(
                title: event.title, start: start, end: end,
                attendees: (event.attendees ?? []).compactMap { person in
                    person.name.map { CalendarAttendee(name: $0) }
                },
                meetingURL: event.url, sourceCalendarName: event.calendar?.title,
            )
        }
        return CalendarMatchScorer.match(events: events, start: start, detectedTitle: title, appName: appName)
    }
}
