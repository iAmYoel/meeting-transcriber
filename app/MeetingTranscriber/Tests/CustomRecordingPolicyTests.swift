@testable import MeetingTranscriber
import XCTest

@MainActor
final class CustomRecordingPolicyTests: XCTestCase {
    private final class Detector: MeetingDetecting {
        var active = true
        func checkOnce() -> DetectedMeeting? {
            nil
        }

        func isMeetingActive(_: DetectedMeeting) -> Bool {
            active
        }

        func reset(appName _: String?) {}
    }

    private final class Notifier: AppNotifying {
        var calls = 0
        var answer: ConsentAnswer = .declined
        func notify(title _: String, body _: String, urgency _: NotificationUrgency) {}
        func askToRecord(title _: String, body _: String) async -> ConsentAnswer {
            calls += 1
            return answer
        }
    }

    private func meeting() -> DetectedMeeting {
        DetectedMeeting(pattern: .teams, windowTitle: "Teams call", ownerName: "MSTeams", windowPID: 1234)
    }

    func testAskGatesNativeMeetingAndIgnoreSuppressesEntireActiveEpisode() async {
        let detector = Detector()
        let notifier = Notifier()
        let loop = WatchLoop(detector: detector, notifier: notifier, recordingStartPolicy: { .ask })
        XCTAssertTrue(loop.requestConsentIfNeeded(for: meeting()))
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(notifier.calls, 1)
        XCTAssertNil(loop.approvedConsentMeeting)
        XCTAssertTrue(loop.requestConsentIfNeeded(for: meeting()))
        await Task.yield()
        XCTAssertEqual(notifier.calls, 1, "Ignoring must suppress the current meeting, even after cooldown")
    }

    func testManualOnlyNeitherAsksNorApprovesDetectedMeeting() async {
        let notifier = Notifier()
        let loop = WatchLoop(detector: Detector(), notifier: notifier, recordingStartPolicy: { .manualOnly })
        XCTAssertTrue(loop.requestConsentIfNeeded(for: meeting()))
        await Task.yield()
        XCTAssertEqual(notifier.calls, 0)
        XCTAssertNil(loop.approvedConsentMeeting)
    }

    func testAutomaticNativeMeetingBypassesConsent() {
        let loop = WatchLoop(detector: Detector(), recordingStartPolicy: { .automatic })
        XCTAssertFalse(loop.requestConsentIfNeeded(for: meeting()))
    }

    func testUnavailableNotificationsKeepMenuConsentAndNeverAutoApprove() async {
        let notifier = Notifier()
        notifier.answer = .unavailable
        let loop = WatchLoop(detector: Detector(), notifier: notifier, recordingStartPolicy: { .ask })
        XCTAssertTrue(loop.requestConsentIfNeeded(for: meeting()))
        await Task.yield()
        await Task.yield()
        XCTAssertNotNil(loop.pendingConsentApp)
        XCTAssertNil(loop.approvedConsentMeeting)
        loop.answerConsentFromMenu(granted: false)
        XCTAssertNil(loop.pendingConsentApp)
        XCTAssertNil(loop.approvedConsentMeeting)
    }

    func testMenuApprovalRevalidatesMeetingAndWatching() async {
        let detector = Detector()
        let notifier = Notifier()
        notifier.answer = .unavailable
        let loop = WatchLoop(detector: detector, notifier: notifier, recordingStartPolicy: { .ask })
        loop.start()
        XCTAssertTrue(loop.requestConsentIfNeeded(for: meeting()))
        await Task.yield()
        detector.active = false
        loop.answerConsentFromMenu(granted: true)
        XCTAssertNil(loop.approvedConsentMeeting)
        loop.stop()
    }

    func testFreshSettingsDefaultToAskManualLocalAndSwedish() throws {
        let suiteName = "CustomRecordingPolicyTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults, apiKeyAccount: suiteName)
        XCTAssertEqual(settings.recordingStartPolicy, .ask)
        XCTAssertEqual(settings.summaryExecutionMode, .manual)
        XCTAssertEqual(settings.protocolProvider, .openAICompatible)
        XCTAssertEqual(settings.protocolLanguage, "Swedish")
        XCTAssertFalse(settings.calendarEnrichmentEnabled)
        XCTAssertEqual(settings.transcriptRetentionDays, 180)
        settings.recordingStartPolicy = .manualOnly
        settings.summaryExecutionMode = .transcriptOnly
        let restored = AppSettings(defaults: defaults, apiKeyAccount: suiteName)
        XCTAssertEqual(restored.recordingStartPolicy, .manualOnly)
        XCTAssertEqual(restored.summaryExecutionMode, .transcriptOnly)
    }
}
