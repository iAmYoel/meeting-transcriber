import Foundation

/// Outcome of an explicit recording-consent question. Only `.granted` permits
/// recording; an unavailable notification channel leaves the menu-bar fallback open.
enum ConsentAnswer: Equatable {
    /// The user tapped Record.
    case granted
    /// The user said no: the Ignore action, a swipe-away dismiss, or a tap on
    /// the notification body. Also what a notifier with no prompt reports,
    /// since "we could not ask" must never record.
    case declined
    /// Nobody answered before `NotificationManager.consentPromptTimeout`.
    case expired
    /// Notifications cannot present the question; the menu-bar action remains available.
    case unavailable
    /// The user said no *about this app*, not about this call: the "Never for
    /// this app" action. Distinct from `.declined` because a decline expires
    /// with the cooldown and this does not — it goes on `ConsentDenyList`
    /// and is only undone in Settings. Mapping it onto `.declined` would
    /// re-prompt ten minutes later, which is the thing the user just said no to.
    case never

    /// Whether a recording may start.
    var isGranted: Bool {
        self == .granted
    }
}
