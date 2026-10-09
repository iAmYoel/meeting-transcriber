# Complete Architecture and Build Specification

Single-file version of the Codex handoff. The ZIP contains the split documents and canonical prompt.


# Architecture

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


# Requirements

## R1 Detection
Preserve native Teams detection and existing supported detection paths.

## R2 Recording policy
Support Ask, Automatic and Manual only. Default Ask.
Ask must not record before consent and must never silently auto-record if notifications fail.

## R3 Local transcription
Keep local ASR engines and model selection. Full Large v3 selectable if current
WhisperKit exposes it; no silent Turbo substitution.

## R4 Diarization
Retain FluidAudio and known-voice recognition. Calendar attendee presence alone never
confirms identity.

## R5 Calendar
Optional EventKit enrichment, selected calendars only, no notes/body by default.
Denied permission is non-fatal. Ambiguous event match is not silently selected.

## R6 Outlook
No private Outlook DB parsing. M365 works through EventKit when synced into macOS
Calendar. Graph deferred.

## R7 Manual summary
Default Manual. Transcript/diarization finishes without calling Ollama. Multiple pending
items supported. One summary at a time.

## R8 Local LLM
Reuse OpenAI-compatible provider. Ollama works directly. No Local LLM Hub or Obsidian
plugin required.

## R9 Summary content
Swedish, complete-but-compressed, primarily bullet format. Preserve:
- discussion points,
- prices/costs/currencies,
- numbers/percentages,
- dates/timeframes,
- versions/licensing,
- technical values/configuration,
- requirements/constraints/dependencies,
- architecture/design reasoning,
- alternatives/trade-offs,
- decisions,
- action items,
- best-effort owners,
- deadlines,
- open questions,
- risks/blockers,
- uncertainties.

## R10 Owner inference
Best effort but conservative. If identity is unclear use `Ej fastställd`.

## R11 Existing tags only
Scan current Obsidian tags. LLM chooses only from allow-list. App enforces allow-list.

## R12 Properties

```yaml
---
noteType: Meeting
date: YYYY-MM-DD
customer: ""
members: ""
tags:
  - existing-tag
---
```

Date = authoritative local meeting-start date, not summary-run date.

## R13 Paths

```text
AI/
├── Meeting notes/
├── Transcriptions/
│   ├── Pending/
│   └── Archive/
└── System/
    └── Prompts/
```

Meeting:
`AI/Meeting notes/YYYY/YYYY-MM-DD - <AI-title>.md`

Archived transcript:
`AI/Transcriptions/Archive/YYYY/YYYY-MM-DD - transcription - <AI-title>.<ext>`

## R14 Title
LLM proposes title. App sanitizes it. Calendar title is context, not mandatory filename.

## R15 Archive
Archive only after successful meeting-note write. Failed summary/write leaves Pending.

## R16 Retention
Default 180 days after archive. Delete raw transcript only if summary exists, metadata
says processed, age passed and retain flag is false. Never delete meeting note.

## R17 Privacy
No sensitive transcript/calendar/speaker data in logs. Local default. Warn before remote
LLM transmission.

## R18 Resource behavior
On M2 Pro/16 GB, no summary model loads during meeting unless explicitly requested; no
concurrent summaries.


# Obsidian Contract

## Vault layout

```text
<Vault>/
└── AI/
    ├── Meeting notes/
    │   └── YYYY/
    ├── Transcriptions/
    │   ├── Pending/
    │   └── Archive/
    │       └── YYYY/
    └── System/
        └── Prompts/
            └── Meeting-Summary.md
```

Do not create the old numeric folder scheme.

## Meeting note filename

`YYYY-MM-DD - <sanitized AI title>.md`

## Transcript filename

Keep native stable transcript extension:

`YYYY-MM-DD - transcription - <sanitized AI title>.<ext>`

`.txt`, `.md`, `.json` or another machine-readable stable format is acceptable. File
type is not a product constraint.

## Properties

The app constructs:

```yaml
---
noteType: Meeting
date: 2026-10-08
customer: ""
members: ""
tags:
  - azure
  - architecture
---
```

Order:
1. noteType
2. date
3. customer
4. members
5. tags

## Tag discovery

Scan Markdown files for:
- frontmatter `tags`,
- inline Obsidian `#tags`.

Exclude:
- `.obsidian/`
- `.git/`
- `AI/System/`

Preserve canonical spelling/casing.
Pass allow-list to model and validate output deterministically.
Never create a new tag automatically.

## Body structure

```markdown
# <title>

## Sammanfattning
- ...

## Mötesanteckningar

### <dynamic topic>
- ...

## Fakta och konkreta detaljer
- ...

## Beslut
- ...

## Action Items
- [ ] ... — Owner: ... — Due: ...

## Öppna frågor
- ...

## Risker / blockers
- ...

## Tekniska anteckningar
- ...

## Osäkerheter
- ...
```

## Sidecar

Keep lifecycle metadata outside raw transcript:

```json
{
  "schemaVersion": 1,
  "meetingStart": "2026-10-08T14:00:00+02:00",
  "processed": true,
  "archivedAt": "2026-10-08T15:20:00+02:00",
  "summaryNote": "AI/Meeting notes/2026/2026-10-08 - Example.md",
  "retainTranscript": false,
  "sourceExtension": "txt"
}
```

## Safe write order

1. render note,
2. write safely/atomically,
3. verify destination,
4. archive transcript,
5. update state.

Never move/delete the only transcript before the note is safely written.


# Security & Privacy

Sensitive data may include customer names, pricing, architecture, incidents, attendee
identities, calendar subjects and voice embeddings.

## Default flow

```text
Teams audio
→ local capture
→ local ASR
→ local diarization
→ local EventKit
→ local Ollama
→ local Obsidian
```

## EventKit

Reading events requires full calendar access; there is no read-only EventKit permission
for this use case.

Mitigations:
- explicit opt-in,
- selected calendar allow-list,
- narrow time-window query,
- read only title/start/end/attendees/url,
- do not read notes/body/location by default,
- no bulk calendar dump,
- no raw calendar object logging.

Sandboxed build must carry appropriate calendar entitlement and usage description.

## Graph fallback
Future only:
- delegated auth,
- `Calendars.ReadBasic` first,
- `Calendars.Read` only if required,
- never read/write scope,
- Keychain tokens,
- `$select`,
- no application-wide mailbox access.

## Speaker embeddings
Keep app-private with restrictive file permissions. Never write to Obsidian/logs.

## LLM endpoint
Loopback/local endpoint = local.
Anything else = remote.

Warn before first remote use that transcript and selected metadata will be transmitted.

## Filesystem
LLM never supplies a full path.
Sanitize title and reject traversal/separators/control chars.
Do not silently overwrite existing notes.

## Logs
No transcript text, attendee arrays, prompt bodies or embeddings.
Treat meeting titles as private diagnostic data.


# Verified Upstream Baseline

Research date: 2026-10-08.

Repository:
`https://github.com/pasrom/meeting-transcriber`

Upstream moves quickly; inspect the checked-out revision before coding.

Current public docs describe:
- Swift/SwiftUI menu-bar app,
- `AppState` composition root,
- `TranscribingEngine`,
- `WhisperKitEngine`,
- `ParakeetEngine`,
- `DualSourceRecorder`,
- `FluidDiarizer`,
- `SpeakerMatcher`,
- `PipelineQueue`,
- `ProtocolGenerating`,
- `ClaudeCLIProtocolGenerator`,
- `OpenAIProtocolGenerator`,
- local `/v1` automation API.

Detection docs describe:
- `MeetingDetecting`,
- `PowerAssertionDetector`,
- `MicInputDetector`,
- browser WebRTC detection,
- browser consent around `AppMeetingPattern.requiresRecordingConsent`,
  `WatchLoop.requestConsentIfNeeded` and `NotificationManager.askToRecord`.

`CLAUDE.md` is more precise/current than some README wording. Source + current
`CLAUDE.md` are authoritative.

Protocol generation supports:
- `.claudeCLI`,
- `.openAICompatible`,
- `.none`,
- custom prompt file,
- meeting date/time variables,
- Ollama/LM Studio/llama.cpp compatible endpoints,
- raw transcript retention.

Output directory is configurable.

Upstream testing includes XCTest, ViewInspector/SnapshotTesting, fixture E2E,
app-level Apple Silicon E2E, meeting simulator and debug RPC inspection.

Public references:
- https://github.com/pasrom/meeting-transcriber
- https://github.com/pasrom/meeting-transcriber/blob/main/CLAUDE.md
- https://github.com/pasrom/meeting-transcriber/blob/main/docs/automation-api.md
- https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- https://learn.microsoft.com/graph/permissions-reference


# Implementation Plan

## Phase 0 — Baseline
- fork/clone upstream,
- read `CLAUDE.md`,
- run unit/lint/analyzer/E2E,
- record upstream SHA.

## Phase 1 — Recording policy
Add `RecordingStartPolicy`, General settings UI and native ask-before-record.
Generalize existing browser consent flow.

Inspect current symbols for:
- AppSettings
- AppMeetingPattern
- WatchLoop
- requestConsentIfNeeded
- ConsentPromptCoordinator
- BrowserConsentPolicy
- NotificationManager.askToRecord
- General Settings views

## Phase 2 — EventKit provider
Add:
- CalendarProviding
- EventKitCalendarProvider
- CalendarDescriptor
- CalendarAttendee
- CalendarMeetingMetadata
- CalendarMatchScorer

Add opt-in calendar settings and permissions.
Use fake provider in tests.

## Phase 3 — Carry meeting metadata
Attach minimal matched calendar metadata to the meeting job. Calendar failure is
non-fatal.

## Phase 4 — Manual summary state
Add `SummaryExecutionMode`:
- manual,
- automatic,
- transcriptOnly.

In manual:
- write Pending transcript + sidecar,
- transition to pending-summary state,
- notify user,
- no LLM call.

Provide pending list/action. One summary at a time.
Inspect PipelineQueue/job states/terminal store before changing state machine.

## Phase 5 — Obsidian service

Suggested:

```swift
protocol ObsidianVaultServing {
    func discoverExistingTags() throws -> [VaultTag]
    func writePendingTranscript(...) throws -> URL
    func writeMeetingNote(_ note: RenderedMeetingNote) throws -> URL
    func archiveTranscript(...) throws -> URL
}
```

Add vault root picker/bookmark.
Create only required year/system subfolders.

## Phase 6 — Summary rendering

On Summarize:
1. load external prompt,
2. load transcript,
3. load meeting/calendar metadata,
4. scan allowed tags,
5. build LLM request,
6. call existing OpenAI-compatible generator,
7. parse TITLE/TAGS/body,
8. validate/sanitize,
9. build frontmatter deterministically,
10. write note safely,
11. archive transcript,
12. mark complete.

Use simple control lines for small models:

```text
TITLE: <title>
TAGS: tag1, tag2

# <title>
...
```

Fallback title:
- safe calendar title if available,
- else deterministic `Meeting HH-mm`.

## Phase 7 — Retention
Startup/daily RetentionService.
Default 180 days.
Delete only when all safety gates pass.

## Phase 8 — Privacy polish
Remote endpoint warning, redacted logs, calendar minimization, permission UI.

## Phase 9 — Microsoft Graph
Deferred until EventKit is tested on target Mac.

## Phase 10 — Upstream sync
Document fork-only deltas and rebase procedure.


# Test Plan

## Baseline
All upstream unit/lint/analyzer/E2E green first.

## Recording policy
- automatic starts,
- ask does not record before consent,
- ignore stays idle,
- manualOnly does not auto-start,
- no duplicate prompts/recordings,
- unavailable notifications do not auto-record.

Extend existing meeting-simulator/E2E where possible.

## Calendar
Fake provider tests:
- disabled,
- denied,
- selected calendars only,
- strong match,
- no match,
- ambiguous match,
- no body/notes path.

## Speaker
Calendar attendees only provide candidates/context; known voice behavior remains intact.

## Pending summary
- manual stops before LLM,
- pending persists across restart,
- summarize resumes,
- multiple pending independent,
- sequential summaries.

## OpenAI-compatible
Use local stub:
- valid,
- timeout,
- connection refused,
- malformed TITLE,
- hallucinated tags,
- empty body.

## Tags
Fixtures for YAML tags, inline tags, hierarchical tags, duplicate casing, code fences,
excluded `AI/System`, zero tags.

## Frontmatter
Assert exact property order and meeting-start date.

## Filename
Sanitize `/ : * ? " < > | ..` and control chars. No path escape. Non-destructive
duplicate handling.

## Archive
- successful note → archive,
- failed note → Pending retained,
- target conflict → source retained,
- raw transcript unchanged,
- sidecar follows.

## Retention
- 179d keep,
- 181d + valid summary delete,
- missing summary keep,
- retain true keep,
- corrupt metadata keep/report.

## Target Mac manual validation
On M2 Pro 16 GB:
- detect Teams,
- ask,
- record,
- transcribe/diarize,
- verify Ollama summary has not run,
- another Teams meeting can start,
- later Summarize runs exactly one job.


# Architecture Decisions

## ADR-001 Meeting Transcriber upstream
Use `pasrom/meeting-transcriber` rather than MacWhisper/Biscotti/new app.

## ADR-002 Summary inside app
Move summary into the fork. Preserve external prompt, reprocessing, tags, properties,
manual timing and retention. Obsidian no longer orchestrates meetings.

## ADR-003 Manual summary default
Target M2 Pro/16 GB may need another Teams meeting immediately.

## ADR-004 EventKit first
Use local EventKit when M365 calendar is synced to macOS. Graph later if needed.

## ADR-005 Calendar enrichment only
Calendar does not prove a call is active.

## ADR-006 Existing tags only
Model classifies against vault taxonomy; app rejects unknown tags.

## ADR-007 Deterministic file/property logic
LLM supplies semantics/title/tag proposals only.

## ADR-008 Raw transcript retention
180 days by default after successful processing.

## ADR-009 Transcript format is not a requirement
Keep the native stable format; `.txt`, `.md`, `.json`, etc. are acceptable if supported.


# Open Questions

1. Exact current WhisperKit model identifiers: inspect checkout. Full Large v3 must be
   selectable if supported; never guess the identifier.
2. Verify the work Outlook/M365 calendar is visible through EventKit on the target Mac.
3. Verify whether the Teams online meeting URL is directly exposed through EventKit.
   Do not read event body just to recover it in MVP.
4. Inspect current upstream consent code before naming exact files in patches.
5. If vault tag scanning becomes slow, add caching later without changing behavior.
6. Keep upstream audio-retention semantics unless a separate requirement emerges.
