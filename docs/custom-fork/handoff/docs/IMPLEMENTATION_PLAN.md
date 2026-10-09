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
