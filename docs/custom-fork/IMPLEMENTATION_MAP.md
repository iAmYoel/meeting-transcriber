# Custom fork implementation map

Baseline: a4f6af6df2674bc4e18097084a128af469823fab in iAmYoel/meeting-transcriber.

- Recording: `WatchLoop` polls, gates through `WatchLoop+Consent`, then calls `handleMeeting`. Native patterns currently bypass consent; browser patterns use `requiresRecordingConsent`, `BrowserConsentPolicy`, `ConsentDenyListStore` and `NotificationManager.askToRecord`. Add a dynamic recording-policy accessor and generalize this gate, retaining explicit browser consent even in automatic mode. Explicit ignores suppress the active meeting episode. Menu-bar consent must work without notifications.
- Settings: `AppSettings` persists stored properties in UserDefaults; `GeneralSettingsView` owns watching controls, `OutputSettingsView` owns provider/output controls. Add explicit recording/summary enums, calendar selections and a separate security-scoped vault bookmark. Keep current user choices when already saved.
- Processing: `PipelineQueue+Stages.generateProtocol` is shared by initial processing, late speaker naming and recovery. `PipelineJob` records the authoritative meeting start and durable transcript/audio locations. Add an optional custom output handler at that shared seam; leave existing queue states/API and upstream test defaults intact. A separate persisted Pending sidecar represents summary lifecycle, independent of the short-lived `.done` transcription job.
- Calendar: no current EventKit provider. Add an injected provider/scorer; copy minimal optional metadata onto the job before the transcript-output stage. Permission requests belong to Settings, never background processing.
- Summary: reuse `OpenAIProtocolGenerator` transport with an injectable system prompt. No generator call in manual or transcript-only modes. Sequential manual execution with retry and a persisted transaction record.
- Vault: new service owns existing tag discovery, deterministic frontmatter/paths, non-overwriting note creation, archive transactions and safe retention. Canonical prompt is bundled as a package resource and installed in the vault only when absent.
- Stale assumptions: there is no `RecordingPolicyController`, `PendingSummaryStore` or EventKit integration yet; `ConsentPromptCoordinator` exists but is owned by the notifier, not WatchLoop. `PipelineController`, `WatchingController` and `SpeakerNamingSession` own concerns previously attributed to AppState. Existing provider default outside App Store is Claude; fresh fork defaults become local OpenAI-compatible, Swedish and manual.

## Validation boundary

Linux baseline: nine portable script test files pass, eight depend on Apple tools and fail here. Swift app unit tests, analyzer, app/audio E2E and EventKit runtime tests require macOS/Xcode. Do not call the macOS baseline green. No remote changes or publication are part of this coding task.
