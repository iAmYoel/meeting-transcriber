import Foundation
import os.log

private let logger = Logger(subsystem: AppPaths.logSubsystem, category: "WatchLoopConsent")

/// Shared gate for native Ask mode and browser meetings. Await the user's answer
/// in a separate task so polling continues while the question is visible.
/// Unavailable notifications keep explicit Record/Ignore actions in the menu bar.
extension WatchLoop {
    /// Whether this meeting has to wait for the user instead of recording now.
    /// Returns immediately in every case.
    ///
    /// True also covers "we are already asking about this app" and "a recent
    /// decline still suppresses the question" — both reasons to skip the
    /// meeting, neither a reason to ask again.
    func requestConsentIfNeeded(for meeting: DetectedMeeting) -> Bool {
        guard recordingStartPolicy() != .manualOnly else { return true }
        guard recordingStartPolicy().requiresConsent(forBrowser: meeting.pattern.requiresRecordingConsent) else {
            return false
        }
        let identity = meeting.pattern.appName
        if let ignored = ignoredConsentMeetings[identity] {
            if detector.isMeetingActive(ignored) { return true }
            ignoredConsentMeetings.removeValue(forKey: identity)
        }
        // One question at a time. The WebRTC assertion re-detects the same call
        // every poll, so without this the loop would post a fresh prompt every
        // few seconds while the first one is still on screen.
        guard pendingConsentApp == nil else { return true }

        let app = meeting.pattern.appName
        guard case .ask = consentPolicy.decision(
            app: app, now: nowProvider(), isDenied: denyListStore.isDenied(app),
        ) else {
            detector.reset(appName: app) // re-detect after the debounce
            return true
        }

        let promptID = UUID()
        pendingConsentApp = app
        consentMeeting = meeting
        consentPromptID = promptID
        // `app` is already the concrete browser: a browser meeting is carried
        // under the process that held the assertion, so the debounce above and
        // the name below refer to the same one browser. `ownerName` is kept as
        // the source with a fallback because it is the value the detector read
        // straight off the assertion, and an empty identity would otherwise
        // produce a prompt naming nothing at all.
        let browserName = meeting.pattern.requiresRecordingConsent && !meeting.ownerName.isEmpty ? meeting.ownerName : app
        consentTask = Task { [weak self] in
            guard let self else { return }
            let answer = await notifier.askToRecord(
                title: meeting.pattern.requiresRecordingConsent ? "Record browser meeting?" : "Record meeting?",
                body: "A meeting is active in \(browserName).",
            )
            finishConsent(for: meeting, promptID: promptID, answer: answer)
        }
        return true
    }

    func refreshConsentEpisodeState() {
        ignoredConsentMeetings = ignoredConsentMeetings.filter { detector.isMeetingActive($0.value) }
        if let meeting = consentMeeting,
           recordingStartPolicy() == .manualOnly || !detector.isMeetingActive(meeting) {
            declineParkedConsent()
        }
    }

    func answerConsentFromMenu(granted: Bool) {
        guard let meeting = consentMeeting, let promptID = consentPromptID else { return }
        _ = notifier.resolveBrowserConsent(granted: granted)
        finishConsent(for: meeting, promptID: promptID, answer: granted ? .granted : .declined)
    }

    /// Take the approved meeting, if any, clearing it. The poll loop is the
    /// only caller: recordings start there and nowhere else, so two of them
    /// cannot overlap.
    func takeApprovedConsentMeeting() -> DetectedMeeting? {
        defer { approvedConsentMeeting = nil }
        return approvedConsentMeeting
    }

    /// Answer a parked prompt as a decline, for `stop()`. Routed through the
    /// notifier so the real prompt's parked continuation completes; without it
    /// the question would linger for the rest of its timeout.
    func declineParkedConsent() {
        guard pendingConsentApp != nil else { return }
        _ = notifier.resolveBrowserConsent(granted: false)
        // Cleared regardless of whether anything was waiting: a notifier with
        // no coordinator behind it never resolves, and a prompt stuck
        // "pending" forever would silence every future question.
        clearConsentState()
    }

    /// Land the user's answer. Main-actor isolated like the rest of
    /// `WatchLoop`, so it cannot race the poll loop's reads.
    private func finishConsent(for meeting: DetectedMeeting, promptID: UUID, answer: ConsentAnswer) {
        let app = meeting.pattern.appName
        guard consentPromptID == promptID else { return }
        guard answer != .unavailable else { return }
        clearConsentState()

        guard answer.isGranted else {
            // A refusal and a prompt nobody saw are different facts, and the
            // cooldown treats them differently: ten minutes of quiet after a
            // no, one minute after silence. Never is a third fact and outlives
            // both, and takes no cooldown of its own.
            switch answer {
            case .expired:
                consentPolicy.recordExpiry(app: app, now: nowProvider())

            case .never:
                // No decline cooldown alongside it. The denial already
                // suppresses, and a cooldown would outlive a Settings "Remove"
                // by up to ten minutes, so undoing a mistaken Never would
                // silently keep doing nothing.
                denyListStore.deny(app)

            default:
                if recordingStartPolicy() == .ask { ignoredConsentMeetings[app] = meeting }
                else { consentPolicy.recordDecline(app: app, now: nowProvider()) }
            }
            detector.reset(appName: app)
            return
        }
        // Minutes can pass between prompt and click, and watching may have been
        // switched off in between — recording then would be recording without
        // having been asked to watch at all.
        guard isActive, recordingStartPolicy() != .manualOnly else {
            logger.info("Consent granted for \(app, privacy: .public) after watching stopped — ignoring")
            return
        }
        // The call itself may also have ended while the question sat there.
        guard detector.isMeetingActive(meeting) else {
            detector.reset(appName: app)
            return
        }
        approvedConsentMeeting = meeting
    }
}
