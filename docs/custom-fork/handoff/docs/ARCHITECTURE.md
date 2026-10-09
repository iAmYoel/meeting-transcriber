# Architecture — Local Meeting Intelligence Pipeline

## 1. Purpose

Extend Meeting Transcriber into a privacy-first local meeting capture and knowledge
pipeline for a work Mac and an Obsidian vault.

```text
detect → ask → record → transcribe → diarize → enrich → queue
      → summarize on demand → write Obsidian → archive → retain/delete
```

Obsidian is the canonical knowledge store, not the orchestration engine.

## 2. Why Meeting Transcriber

Reuse upstream because it already provides:
- native macOS menu-bar app,
- Teams/Zoom/Webex detection,
- dual app-audio + microphone capture,
- WhisperKit and Parakeet,
- FluidAudio diarization,
- persistent speaker recognition,
- configurable output folder,
- OpenAI-compatible summary provider including Ollama/LM Studio,
- custom protocol prompt,
- background pipeline,
- local automation API,
- Apple Silicon E2E testing,
- MIT license.

Keep the fork close to upstream.

## 3. Target environment

- Apple M2 Pro
- 16 GB unified memory
- macOS 14.2+ inherited minimum
- Microsoft Teams native client primary
- Teams/Edge/work apps may remain open
- Ollama local via OpenAI-compatible endpoint

Resource rules:
- manual summary default,
- one summary at a time,
- never auto-load a heavy summary model merely because a transcript exists,
- model configurable.

## 4. Component model

```text
Existing CompositeMeetingDetector
PowerAssertionDetector + MicInputDetector
                ↓
RecordingPolicyController (new)
ask | automatic | manualOnly
                ↓
Existing DualSourceRecorder
                ↓
Existing TranscribingEngine
WhisperKit | Parakeet
                ↓
Existing FluidDiarizer + SpeakerMatcher
                ↓
CalendarProvider (new)
EventKit, opt-in, minimal metadata
                ↓
PendingSummaryStore (new)
AI/Transcriptions/Pending
                ↓ user clicks Summarize
MeetingSummaryService
existing OpenAIProtocolGenerator + prompt + allowed tags
                ↓
ObsidianVaultService (new)
frontmatter + validated tags + filename + archive
                ↓
RetentionService (new)
180-day safe cleanup
```

## 5. Detection and recording consent

Preserve upstream production meeting detection. Current upstream architecture documents
`MeetingDetecting`, `PowerAssertionDetector`, `MicInputDetector`, browser WebRTC
detection and a browser consent path.

Add:

```swift
enum RecordingStartPolicy: String, CaseIterable, Codable {
    case ask
    case automatic
    case manualOnly
}
```

Default: `ask`.

UI:

```text
When a meeting is detected

● Ask before recording
○ Record automatically
○ Do not start automatically
```

Reuse/generalize the existing consent path around:
- `AppMeetingPattern.requiresRecordingConsent`
- `WatchLoop.requestConsentIfNeeded`
- `NotificationManager.askToRecord`
- consent coordinator/policy

Ask-mode:
- show `Record` / `Ignore`,
- record nothing before acceptance,
- Ignore suppresses current episode,
- notification failure never falls back to auto-record,
- show Settings warning if visible notifications are unavailable,
- provide menu-bar fallback action.

## 6. Recording and ASR

Keep upstream dual-source recording and channel-health behavior.

Preferred ASR: WhisperKit.
Requirements:
- model selection preserved,
- full Large v3 selectable when current WhisperKit exposes it,
- no silent substitution with Turbo,
- Parakeet remains available.

## 7. Diarization and speaker identity

Keep:
- FluidAudio,
- OfflineDiarizer/Sortformer,
- dual-track diarization,
- SpeakerMatcher,
- known voice embeddings,
- interactive speaker naming.

Calendar attendees are candidate names/context only. Calendar presence alone never
proves speaker identity.

Voice embeddings remain app-private and are never written to Obsidian.

## 8. Calendar enrichment

Add abstraction:

```swift
protocol CalendarProviding {
    func authorizationStatus() -> CalendarAuthorizationStatus
    func requestAccess() async throws -> Bool
    func calendars() async throws -> [CalendarDescriptor]
    func matchingEvent(for context: MeetingDetectionContext) async throws -> CalendarMeetingMetadata?
}
```

MVP: `EventKitCalendarProvider`.
Future: `MicrosoftGraphCalendarProvider`.

### EventKit path

Work M365/Exchange account should be synced into macOS Calendar/Internet Accounts.
Read it through EventKit.

Do not read Outlook's private local database.

EventKit requires full calendar access to read events, so enforce minimization in code.

Settings:

```text
Calendar enrichment: Enabled/Disabled

Calendars:
[x] Work
[ ] Personal

Use:
[x] Title
[x] Start/end
[x] Attendees
[x] Event URL where directly exposed
[ ] Notes/body
[ ] Location
```

Defaults:
- opt-in,
- body/notes off and not read,
- location off and not read.

Calendar is enrichment, not detection.

### Event matching

Query only a narrow window around detection.

Score:
1. interval overlap,
2. provider/meeting URL hints,
3. normalized title similarity when a useful detected title exists.

If ambiguous, attach no event automatically or prompt the user.

Persist only:

```swift
struct CalendarMeetingMetadata: Codable, Sendable {
    var title: String?
    var start: Date?
    var end: Date?
    var attendees: [CalendarAttendee]
    var meetingURL: URL?
    var sourceCalendarName: String?
}
```

## 9. Outlook / Graph fallback

Not MVP.

If EventKit cannot see the corporate calendar:
- future delegated Microsoft Graph provider,
- least privilege,
- try `Calendars.ReadBasic` first,
- use `Calendars.Read` only if required fields are unavailable,
- never request Calendars.ReadWrite,
- tokens in Keychain,
- `$select` only needed fields,
- no application-wide mailbox permissions.

## 10. Pending summary lifecycle

Add:

```swift
enum SummaryExecutionMode: String, CaseIterable, Codable {
    case manual
    case automatic
    case transcriptOnly
}
```

Default: `manual`.

Manual:
- transcription + diarization complete,
- save transcript to Pending,
- persist sidecar metadata,
- stop before LLM,
- notify `Transcript ready`,
- user can choose `Summarize` or `Later`.

Multiple pending items supported.
Default summary execution strictly sequential.

## 11. Summary service

Reuse upstream `ProtocolGenerating` / `OpenAIProtocolGenerator`.

Default local example:

```text
Provider: OpenAI-compatible
Endpoint: http://localhost:11434/v1/chat/completions
Model: configurable
```

Canonical prompt can live externally in the Obsidian vault:

```text
AI/System/Prompts/Meeting-Summary.md
```

Load it at summary time.

Context sent to the LLM:
- diarized transcript,
- authoritative meeting start date/time,
- matched calendar title,
- attendee names,
- app/provider,
- allow-list of existing Obsidian tags.

Do not send:
- calendar body/notes,
- unrelated events,
- voice embeddings,
- unrelated vault content.

For local small models prefer simple control lines:

```text
TITLE: <title>
TAGS: tag1, tag2

# <title>
...
```

App owns:
- meeting date,
- frontmatter,
- tag validation,
- filename sanitization,
- paths,
- archive,
- retention.

## 12. Obsidian

No Obsidian plugin is required.

Use security-scoped bookmark handling as appropriate.

See `docs/OBSIDIAN_CONTRACT.md`.

## 13. Failure handling

Calendar failure:
- non-fatal.

Ollama/summary failure:
- transcript remains Pending,
- expose Retry,
- move/delete nothing.

Obsidian write failure:
- transcript remains Pending,
- never mark complete.

Only archive after meeting note exists safely.

## 14. Security

Default data path is local:
audio → ASR → diarization → EventKit → Ollama → Obsidian.

If user configures a non-loopback OpenAI-compatible endpoint, warn explicitly that
transcript and selected meeting metadata will leave the Mac.

## 15. Upstream sync

Keep focused changes:
1. recording policy/consent,
2. EventKit provider,
3. pending-summary state,
4. Obsidian service,
5. summary/tags/rendering,
6. retention.

Avoid unrelated refactors.
