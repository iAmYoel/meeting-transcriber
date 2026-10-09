@testable import MeetingTranscriber
import XCTest

@MainActor
final class CustomMeetingSummaryTests: XCTestCase {
    private final class CalendarFake: CalendarProviding {
        var isAuthorized = false
        var queriedIDs: [String] = []
        func requestAccess() async throws -> Bool {
            false
        }

        func calendars() -> [CalendarDescriptor] {
            []
        }

        func matchingEvent(start _: Date, title _: String, calendarIDs: [String], appName _: String) -> CalendarMeetingMetadata? {
            queriedIDs = calendarIDs
            return nil
        }
    }

    private func fixture() throws -> (AppSettings, MeetingSummaryController, URL, CalendarFake) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CustomSummaryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suiteName = "CustomSummaryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settings = AppSettings(defaults: defaults, apiKeyAccount: suiteName)
        try settings.setVaultRoot(root)
        let provider = CalendarFake()
        let controller = MeetingSummaryController(settings: settings, notifier: SilentNotifier(), calendar: provider)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return (settings, controller, root, provider)
    }

    private func job() -> PipelineJob {
        PipelineJob(
            meetingTitle: "Design",
            appName: "Teams",
            mixPath: nil,
            appPath: nil,
            micPath: nil,
            micDelay: 0,
            meetingStartTime: Date(timeIntervalSince1970: 1_700_000_000),
        )
    }

    private func waitUntilIdle(_ controller: MeetingSummaryController) async {
        // Wait for actual worker state, bounded so a stranded request fails rather than hanging XCTest.
        for _ in 0 ..< 100 {
            if controller.pending.isEmpty || controller.errorMessage != nil { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    func testManualAndTranscriptOnlyNeverCallModel() async throws {
        let (settings, controller, _, _) = try fixture()
        var calls = 0
        controller.generateOverride = { _, _ in calls += 1; return "unexpected" }
        for mode in [SummaryExecutionMode.manual, .transcriptOnly] {
            settings.summaryExecutionMode = mode
            _ = try await controller.receive(job: job(), transcript: "Raw")
        }
        await Task.yield()
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(controller.pending.count, 2)
    }

    func testExplicitSummariesRunSequentiallyAndFilterUnknownTags() async throws {
        let (_, controller, root, _) = try fixture()
        var concurrent = 0
        var maximum = 0
        var calls = 0
        controller.generateOverride = { _, _ in
            concurrent += 1
            maximum = max(maximum, concurrent)
            calls += 1
            try await Task.sleep(for: .milliseconds(20))
            concurrent -= 1
            return "TITLE: Design\nTAGS: invented\n\n# Design\n- Pris 120 SEK."
        }
        let first = job()
        let second = job()
        _ = try await controller.receive(job: first, transcript: "First")
        _ = try await controller.receive(job: second, transcript: "Second")
        controller.requestSummary(id: first.id)
        controller.requestSummary(id: first.id)
        controller.requestSummary(id: second.id)
        await waitUntilIdle(controller)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(maximum, 1)
        XCTAssertTrue(controller.pending.isEmpty)
        let noteURL = try XCTUnwrap(controller.lastNote)
        XCTAssertTrue(noteURL.path.hasPrefix(root.path))
        XCTAssertTrue(try String(contentsOf: noteURL, encoding: .utf8).contains("tags: []"))
    }

    func testModelErrorLeavesPendingAndRawBytes() async throws {
        let (_, controller, root, _) = try fixture()
        controller.generateOverride = { _, _ in throw URLError(.cannotConnectToHost) }
        let input = job()
        _ = try await controller.receive(job: input, transcript: "Keep me")
        controller.requestSummary(id: input.id)
        await waitUntilIdle(controller)
        XCTAssertNotNil(controller.errorMessage)
        XCTAssertEqual(controller.pending.count, 1)
        XCTAssertEqual(try ObsidianVaultService(root: root).transcript(for: controller.pending[0]), "Keep me")
    }

    func testRemoteEndpointMustBeApprovedBeforeCallingModel() async throws {
        let (settings, controller, _, _) = try fixture()
        settings.openAIEndpoint = "https://model.example/v1"
        var calls = 0
        controller.generateOverride = { _, _ in calls += 1; return "unexpected" }
        let input = job()
        _ = try await controller.receive(job: input, transcript: "Private")
        controller.requestSummary(id: input.id)
        await waitUntilIdle(controller)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(controller.pending.count, 1)
        XCTAssertNotNil(controller.errorMessage)
    }

    func testCalendarDisabledAndSelectedCalendarsOnly() throws {
        let (settings, controller, _, provider) = try fixture()
        XCTAssertNil(controller.metadata(for: job()))
        XCTAssertTrue(provider.queriedIDs.isEmpty)
        settings.calendarEnrichmentEnabled = true
        settings.selectedCalendarIDs = ["Work"]
        XCTAssertNil(controller.metadata(for: job()))
        XCTAssertEqual(provider.queriedIDs, ["Work"])
    }
}
