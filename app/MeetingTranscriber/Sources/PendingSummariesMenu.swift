import AppKit
import SwiftUI

struct PendingSummariesMenu: View {
    let controller: MeetingSummaryController

    private func chooseDate(_ record: PendingMeetingSummary) {
        let picker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 280, height: 32))
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.dateValue = record.meetingStart
        let alert = NSAlert()
        alert.messageText = "Meeting start date and time"
        alert.informativeText = "Choose the actual local meeting start. The summary date is kept independent of when you run the model."
        alert.accessoryView = picker
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            controller.updatePending(id: record.id, meetingStart: picker.dateValue)
        }
    }

    var body: some View {
        Group {
            Divider()
            Menu("Pending summaries (\(controller.pending.count))") {
                Button("Import / reprocess transcript…") { Task { await controller.importTranscript() } }
                Button("Refresh") { controller.refresh() }
                ForEach(controller.pending) { record in
                    Menu(record.hasRecordedStart ? "\(record.meetingDate) — \(record.sourceTitle)" : "Date needed — \(record.sourceTitle)") {
                        Button("Summarize / Retry") { controller.requestSummary(id: record.id) }
                            .disabled(!record.hasRecordedStart)
                        Button("Set meeting date/time…") { chooseDate(record) }
                            .disabled(record.preparedNote != nil)
                        Toggle("Keep raw transcript indefinitely", isOn: Binding(
                            get: { record.retainTranscript },
                            set: { controller.updatePending(id: record.id, retainTranscript: $0) },
                        ))
                        .disabled(record.preparedNote != nil)
                    }
                    .disabled(controller.activeID == record.id)
                }
                if controller.activeID != nil { Text("Summarizing… other requests wait in order.") }
                if let error = controller.errorMessage { Text(error) }
            }
        }
        if let note = controller.lastNote {
            Button("Open latest Obsidian note") { controller.openNote(note) }
        }
    }
}
