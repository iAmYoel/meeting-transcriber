import Foundation
import XCTest
#if canImport(MeetingTranscriber)
    @testable import MeetingTranscriber
#else
    @testable import CustomMeetingCore
#endif

final class CustomMeetingCoreTests: XCTestCase {
    private func vault() throws -> ObsidianVaultService {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MeetingCoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return ObsidianVaultService(root: url)
    }

    private func record(date: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> PendingMeetingSummary {
        let id = UUID()
        return PendingMeetingSummary(
            schemaVersion: 1, id: id, meetingStart: date, meetingDate: "2023-11-14", hasRecordedStart: true,
            sourceTitle: "Teams", appName: "Teams", mode: .manual, calendar: nil,
            transcriptRelativePath: "AI/Transcriptions/Pending/\(id.uuidString).txt", processed: false,
            archivedAt: nil, summaryNote: nil, archiveTranscript: nil, preparedNote: nil, retainTranscript: false,
        )
    }

    private func note(title: String = "Design") throws -> MeetingNoteRenderer.Note {
        try MeetingNoteRenderer.render(
            response: "TITLE: \(title)\nTAGS: azure, invented\n\n# Ignored title\n\n## Beslut\n- Kostnad: 120 SEK.",
            allowedTags: ["azure"], meetingDate: "2023-11-14", fallback: "Meeting 12-00",
        )
    }

    func testRecordingPolicyAndBrowserSafety() {
        XCTAssertTrue(RecordingStartPolicy.ask.requiresConsent(forBrowser: false))
        XCTAssertFalse(RecordingStartPolicy.automatic.requiresConsent(forBrowser: false))
        XCTAssertTrue(RecordingStartPolicy.automatic.requiresConsent(forBrowser: true))
    }

    func testRendererRejectsHallucinatedTagsAndBuildsExactProperties() throws {
        let note = try note()
        XCTAssertEqual(note.tags, ["azure"])
        XCTAssertTrue(note.markdown.hasPrefix("---\nnoteType: Meeting\ndate: 2023-11-14\ncustomer: \"\"\nmembers: \"\"\ntags:\n  - \"azure\"\n---"))
        XCTAssertTrue(note.markdown.contains("# Design"))
        XCTAssertTrue(note.markdown.contains("120 SEK"))
        XCTAssertFalse(note.markdown.contains("invented"))
    }

    func testRendererRejectsMalformedAndEmptyResponses() {
        for response in ["", "# Summary", "TITLE: Test\nTAGS:\n", "TITLE: Test\nTAGS:\n# Test", "TITLE: Test\nTAGS:\n---\na: b"] {
            XCTAssertThrowsError(try MeetingNoteRenderer.render(response: response, allowedTags: [], meetingDate: "2023-11-14", fallback: "Meeting"))
        }
    }

    func testUnsafeAndMissingTitleUseSafeFilename() throws {
        let result = try note(title: "../../a:b/*?\"<>| c")
        XCTAssertFalse(result.title.contains(".."))
        XCTAssertNil(result.title.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\:*?\"<>|")))
        let fallback = try note(title: "")
        XCTAssertEqual(fallback.title, "Meeting 12-00")
    }

    func testDateUsesMeetingLocalTimeRatherThanSummaryDate() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(try MeetingNoteRenderer.dateString(date, timeZone: XCTUnwrap(TimeZone(secondsFromGMT: 7200))), "2023-11-15")
    }

    func testTagScannerHandlesYamlInlineHierarchyAndCodeFences() {
        let tags = VaultTagScanner.tags(in: """
        ---
        tags:
          - azure
          - 'Cloud/Network'
        ---
        # Heading
        Words #architecture #azure `#inlineCode`
        ```swift
        #notATag
        ```
        ~~~
        #alsoCode
        ~~~
        """)
        XCTAssertEqual(tags, ["Cloud/Network", "architecture", "azure"])
        XCTAssertEqual(VaultTagScanner.tags(in: "---\ntags: [azure, 'infra']\n---\n"), ["azure", "infra"])
    }

    func testVaultTagDiscoveryExcludesSystemAndAppData() throws {
        let service = try vault()
        for (path, text) in [
            ("a.md", "#Azure"),
            ("b.md", "#azure #work"),
            ("AI/System/prompt.md", "#notAllowed"),
            (".obsidian/x.md", "#hidden"),
            (".git/x.md", "#git"),
            ("AI/Transcriptions/Pending/x.md", "#transcript"),
        ] {
            let url = service.root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        XCTAssertEqual(try service.discoverExistingTags(), ["Azure", "work"])
    }

    func testPendingPersistsAndPreservesRawBytes() throws {
        let service = try vault()
        let first = record()
        let second = record(date: first.meetingStart.addingTimeInterval(60))
        let raw = "[00:01] Person: Åäö, pris 120 SEK.\n"
        try service.writePendingTranscript(raw, record: first)
        try service.writePendingTranscript("Second", record: second)
        let restored = ObsidianVaultService(root: service.root)
        XCTAssertEqual(try restored.pendingMeetings().count, 2)
        XCTAssertEqual(try restored.transcript(for: first), raw)
        let attributes = try FileManager.default.attributesOfItem(atPath: service.checkedURL(first.transcriptRelativePath).path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testDuplicateAdmissionRefusesCorruptMetadataAndKeepsRawTranscript() throws {
        let service = try vault()
        let pending = record()
        try service.writePendingTranscript("Keep", record: pending)
        let sidecar = try service.checkedURL("AI/Transcriptions/Pending/\(pending.id.uuidString).json")
        try Data("{bad}".utf8).write(to: sidecar)
        XCTAssertThrowsError(try service.writePendingTranscript("Keep", record: pending))
        XCTAssertEqual(try String(contentsOf: service.checkedURL(pending.transcriptRelativePath), encoding: .utf8), "Keep")
    }

    func testPromptInstallationNeverOverwritesUserPrompt() throws {
        let service = try vault()
        try service.installPromptIfAbsent("User prompt")
        try service.installPromptIfAbsent("Bundled prompt")
        XCTAssertEqual(try service.loadPrompt(), "User prompt")
    }

    func testArchiveFollowsSuccessfulNoteWriteAndKeepsBytes() throws {
        let service = try vault()
        let pending = record()
        let raw = "Exact raw bytes\n"
        try service.writePendingTranscript(raw, record: pending)
        let url = try service.complete(note(), record: pending, now: Date())
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try service.pendingMeetings().count, 0)
        let archived = try service.checkedURL("AI/Transcriptions/Archive/2023/2023-11-14 - transcription - Design.txt")
        XCTAssertEqual(try String(contentsOf: archived, encoding: .utf8), raw)
        XCTAssertFalse(try FileManager.default.fileExists(atPath: service.checkedURL(pending.transcriptRelativePath).path))
    }

    func testFailedNoteWriteLeavesPending() throws {
        let service = try vault()
        let pending = record()
        try service.writePendingTranscript("Keep", record: pending)
        // A regular file blocks directory creation: genuine I/O failure, not a mock.
        let obstacle = try service.checkedURL("AI/Meeting notes")
        try Data("block".utf8).write(to: obstacle)
        XCTAssertThrowsError(try service.complete(note(), record: pending, now: Date()))
        XCTAssertEqual(try service.transcript(for: pending), "Keep")
        XCTAssertEqual(try service.pendingMeetings().count, 1)
    }

    func testRetryResumesPreparedTransactionWithoutAnotherModelResponse() throws {
        let service = try vault()
        let pending = record()
        try service.writePendingTranscript("Keep", record: pending)
        let obstacle = try service.checkedURL("AI/Meeting notes")
        try Data().write(to: obstacle)
        XCTAssertThrowsError(try service.complete(note(), record: pending, now: Date()))
        let restored = try XCTUnwrap(service.pendingMeetings().first)
        XCTAssertNotNil(restored.preparedNote)
        try FileManager.default.removeItem(at: obstacle)
        XCTAssertNotNil(try service.resumeCompletion(restored, now: Date()))
        XCTAssertTrue(try service.pendingMeetings().isEmpty)
    }

    func testDuplicateTitlesDoNotOverwriteExistingNotesOrTranscripts() throws {
        let service = try vault()
        let first = record()
        let second = record()
        try service.writePendingTranscript("First", record: first)
        let url1 = try service.complete(note(), record: first, now: Date())
        try service.writePendingTranscript("Second", record: second)
        let url2 = try service.complete(note(), record: second, now: Date())
        XCTAssertNotEqual(url1, url2)
        XCTAssertEqual(
            try String(contentsOf: service.checkedURL("AI/Transcriptions/Archive/2023/2023-11-14 - transcription - Design.txt"), encoding: .utf8),
            "First",
        )
    }

    func testConflictingPreparedNoteDoesNotArchive() throws {
        let service = try vault()
        let pending = record()
        try service.writePendingTranscript("Keep", record: pending)
        let obstacle = try service.checkedURL("AI/Meeting notes")
        try Data().write(to: obstacle)
        XCTAssertThrowsError(try service.complete(note(), record: pending, now: Date()))
        try FileManager.default.removeItem(at: obstacle)
        let restored = try XCTUnwrap(service.pendingMeetings().first)
        let target = try service.checkedURL(XCTUnwrap(restored.summaryNote))
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("Someone else's file".utf8).write(to: target)
        XCTAssertThrowsError(try service.resumeCompletion(restored, now: Date()))
        XCTAssertEqual(try service.transcript(for: pending), "Keep")
    }

    func testCorruptPendingDoesNotHideOtherMeetings() throws {
        let service = try vault()
        try service.writePendingTranscript("Keep", record: record())
        try Data("{bad}".utf8).write(to: service.checkedURL("AI/Transcriptions/Pending/bad.json"))
        let loaded = try service.loadPending()
        XCTAssertEqual(loaded.records.count, 1)
        XCTAssertEqual(loaded.unreadableCount, 1)
    }

    func testPathsRejectTraversalAbsolutePathsAndSymlinks() throws {
        let service = try vault()
        for path in ["../out", "/etc/passwd", "AI/../../out", "AI//out", "AI/./out"] {
            XCTAssertThrowsError(try service.checkedURL(path))
        }
        try FileManager.default.createSymbolicLink(at: service.root.appendingPathComponent("escape"), withDestinationURL: URL(fileURLWithPath: "/tmp"))
        XCTAssertThrowsError(try service.checkedURL("escape/sensitive.txt"))
    }

    func testRetentionKeeps179DaysDeletes181DaysAndNeverDeletesNote() throws {
        let service = try vault()
        let pending = record()
        let archivedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try service.writePendingTranscript("Keep", record: pending)
        let url = try service.complete(note(), record: pending, now: archivedAt)
        XCTAssertEqual(try service.applyRetention(days: 180, now: archivedAt.addingTimeInterval(179 * 86400)), 0)
        XCTAssertEqual(try service.applyRetention(days: 180, now: archivedAt.addingTimeInterval(181 * 86400)), 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testRetentionKeepsWhenSummaryMissingOrRetainTrue() throws {
        for retain in [false, true] {
            let service = try vault()
            var pending = record()
            pending.retainTranscript = retain
            try service.writePendingTranscript("Keep", record: pending)
            let archivedAt = Date(timeIntervalSince1970: 1_700_000_000)
            let url = try service.complete(note(), record: pending, now: archivedAt)
            if !retain { try FileManager.default.removeItem(at: url) }
            XCTAssertEqual(try service.applyRetention(days: 180, now: archivedAt.addingTimeInterval(181 * 86400)), 0)
        }
    }

    func testCorruptRetentionMetadataDoesNotDeleteTranscript() throws {
        let service = try vault()
        let pending = record()
        try service.writePendingTranscript("Keep", record: pending)
        _ = try service.complete(note(), record: pending, now: Date(timeIntervalSince1970: 0))
        let json = try service.checkedURL("AI/Transcriptions/Archive/2023/2023-11-14 - transcription - Design.json")
        try Data("{bad}".utf8).write(to: json)
        XCTAssertThrowsError(try service.applyRetention(days: 180, now: Date()))
        XCTAssertTrue(try FileManager.default
            .fileExists(atPath: service.checkedURL("AI/Transcriptions/Archive/2023/2023-11-14 - transcription - Design.txt").path))
    }

    func testCalendarStrongMatchAndAmbiguity() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let first = CalendarMeetingMetadata(
            title: "Design",
            start: start,
            end: start.addingTimeInterval(1800),
            attendees: [],
            meetingURL: nil,
            sourceCalendarName: "Work",
        )
        let second = CalendarMeetingMetadata(
            title: "Other",
            start: start,
            end: start.addingTimeInterval(1800),
            attendees: [],
            meetingURL: nil,
            sourceCalendarName: "Work",
        )
        XCTAssertEqual(CalendarMatchScorer.match(events: [first], start: start, detectedTitle: "Design"), first)
        XCTAssertNil(CalendarMatchScorer.match(events: [first, second], start: start, detectedTitle: "Teams"))
        XCTAssertEqual(CalendarMatchScorer.match(events: [first, second], start: start, detectedTitle: "Design"), first)
        XCTAssertNil(CalendarMatchScorer.match(events: [first], start: start.addingTimeInterval(3600), detectedTitle: "Design"))
    }

    func testUnknownInlineTagsCannotExpandVaultTaxonomy() throws {
        let note = try MeetingNoteRenderer.render(
            response: "TITLE: Design\nTAGS: azure\n\n# Design\n#invented #azure `#code`\n```swift\n#macro\n```",
            allowedTags: ["azure"], meetingDate: "2023-11-14", fallback: "Meeting",
        )
        XCTAssertFalse(note.markdown.contains("#invented"))
        XCTAssertTrue(note.markdown.contains("#azure"))
        XCTAssertTrue(note.markdown.contains("`#code`"))
        XCTAssertTrue(note.markdown.contains("#macro"))
    }

    func testPendingMetadataDateAndRetainFlagPersist() throws {
        let service = try vault()
        var pending = record()
        pending.hasRecordedStart = false
        try service.writePendingTranscript("Keep", record: pending)
        let actualStart = Date(timeIntervalSince1970: 1_800_000_000)
        try service.updatePending(id: pending.id, meetingStart: actualStart, retainTranscript: true)
        let restored = try XCTUnwrap(service.pendingMeetings().first)
        XCTAssertTrue(restored.hasRecordedStart)
        XCTAssertEqual(restored.meetingStart, actualStart)
        XCTAssertEqual(restored.meetingDate, MeetingNoteRenderer.dateString(actualStart))
        XCTAssertTrue(restored.retainTranscript)
    }

    func testArchiveConflictPreservesPendingAndBothExistingFiles() throws {
        let service = try vault()
        let pending = record()
        try service.writePendingTranscript("Original", record: pending)
        let obstacle = try service.checkedURL("AI/Meeting notes")
        try Data().write(to: obstacle)
        XCTAssertThrowsError(try service.complete(note(), record: pending, now: Date()))
        let saved = try XCTUnwrap(service.pendingMeetings().first)
        try FileManager.default.removeItem(at: obstacle)
        let archive = try service.checkedURL(XCTUnwrap(saved.archiveTranscript))
        try FileManager.default.createDirectory(at: archive.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("Existing other transcript".utf8).write(to: archive)
        XCTAssertThrowsError(try service.resumeCompletion(saved, now: Date()))
        XCTAssertEqual(try service.transcript(for: saved), "Original")
        XCTAssertEqual(try String(contentsOf: archive, encoding: .utf8), "Existing other transcript")
    }

    func testResumeAfterTranscriptMoveBeforeFinalSidecarWrite() throws {
        let service = try vault()
        let pending = record()
        try service.writePendingTranscript("Original", record: pending)
        let obstacle = try service.checkedURL("AI/Meeting notes")
        try Data().write(to: obstacle)
        XCTAssertThrowsError(try service.complete(note(), record: pending, now: Date()))
        let saved = try XCTUnwrap(service.pendingMeetings().first)
        try FileManager.default.removeItem(at: obstacle)
        let destination = try service.checkedURL(XCTUnwrap(saved.summaryNote))
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(XCTUnwrap(saved.preparedNote).utf8).write(to: destination)
        let archive = try service.checkedURL(XCTUnwrap(saved.archiveTranscript))
        try FileManager.default.createDirectory(at: archive.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: service.checkedURL(saved.transcriptRelativePath), to: archive)
        XCTAssertNotNil(try service.resumeCompletion(saved, now: Date()))
        XCTAssertTrue(try service.pendingMeetings().isEmpty)
        XCTAssertEqual(try String(contentsOf: archive, encoding: .utf8), "Original")
    }

    func testCalendarURLHintDisambiguatesNativeProvider() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let teams = CalendarMeetingMetadata(
            title: "Roadmap",
            start: start,
            end: start.addingTimeInterval(1800),
            attendees: [],
            meetingURL: URL(string: "https://teams.microsoft.com/l/meetup-join/example"),
            sourceCalendarName: "Work",
        )
        let zoom = CalendarMeetingMetadata(
            title: "Roadmap",
            start: start,
            end: start.addingTimeInterval(1800),
            attendees: [],
            meetingURL: URL(string: "https://example.zoom.us/j/123"),
            sourceCalendarName: "Work",
        )
        XCTAssertEqual(CalendarMatchScorer.match(events: [teams, zoom], start: start, detectedTitle: "Meeting", appName: "Microsoft Teams"), teams)
        XCTAssertNil(CalendarMatchScorer.match(events: [zoom], start: start, detectedTitle: "Meeting", appName: "Microsoft Teams"))
    }

    func testOnlyExactLoopbackHostsAreLocal() throws {
        for url in ["http://localhost:11434/v1", "http://127.0.0.1:11434/v1", "http://[::1]:11434/v1"] {
            XCTAssertTrue(try SummaryEndpointPolicy.isLoopback(XCTUnwrap(URL(string: url))))
        }
        for url in ["https://localhost.attacker.example/v1", "https://model.example/v1", "http://192.168.1.2/v1"] {
            XCTAssertFalse(try SummaryEndpointPolicy.isLoopback(XCTUnwrap(URL(string: url))))
        }
    }
}
