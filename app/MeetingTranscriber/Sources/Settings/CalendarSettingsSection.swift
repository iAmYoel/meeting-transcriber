import SwiftUI

struct CalendarSettingsSection: View {
    @Bindable var settings: AppSettings
    @State private var provider = EventKitCalendarProvider()
    @State private var calendars: [CalendarDescriptor] = []
    @State private var status = ""

    var body: some View {
        Section("Calendar enrichment") {
            Toggle("Use selected calendars", isOn: $settings.calendarEnrichmentEnabled)
            Text("Optional context only. Calendar events never trigger recording or identify a speaker. Notes and location are not read.")
                .font(.caption).foregroundStyle(.secondary)
            if settings.calendarEnrichmentEnabled {
                Button("Allow calendar access / Refresh") {
                    Task {
                        do {
                            if !provider.isAuthorized, try await !(provider.requestAccess()) {
                                status = "Calendar access denied. Recording and transcription remain available."
                                return
                            }
                            calendars = provider.calendars()
                            status = calendars.isEmpty ? "No calendars available. Check macOS Calendar account sync." : ""
                        } catch {
                            status = "Calendar access could not be requested. Check System Settings."
                        }
                    }
                }
                ForEach(calendars) { calendar in
                    Toggle(calendar.title, isOn: Binding(
                        get: { settings.selectedCalendarIDs.contains(calendar.id) },
                        set: { selected in
                            settings.selectedCalendarIDs.removeAll { $0 == calendar.id }
                            if selected { settings.selectedCalendarIDs.append(calendar.id) }
                        },
                    ))
                }
                if !status.isEmpty { Text(status).font(.caption) }
            }
        }
        .onAppear { calendars = provider.calendars() }
    }
}
