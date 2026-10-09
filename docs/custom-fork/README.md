# Custom fork draft and Mac test guide

This draft implements the handoff in `handoff/` on `iAmYoel/meeting-transcriber`, baseline commit `a4f6af6df2674bc4e18097084a128af469823fab`. The draft was prepared and validated in the cloud checkout for review in the user's fork. No deployment, application release, or change to a user's Mac or Obsidian vault has been performed.

The main app has **not been built or executed** in this Linux environment. This is a code draft for macOS validation, not a verified application release.

## Implemented workflow

- Fresh settings default to **Ask before recording**, manual summary, OpenAI-compatible local provider, and Swedish notes. Existing saved choices remain intact; set the desired profile explicitly when testing an existing installation.
- Native Teams/Zoom/Webex Ask mode shares the browser consent path. Only explicit Record grants consent. Ignore suppresses the active episode. A failed notification channel leaves Record/Ignore in the menu bar. Manual-only suppresses detection-triggered starts; explicit manual recording remains available.
- Optional EventKit enrichment reads selected calendars only. It excludes all-day events, scores overlapping events using timing, provider URL and meaningful title hints, and leaves ambiguous matches unattached. It reads no event body, notes or location. Calendar permission is requested only from Settings. Denial does not stop recording or transcription.
- The existing ASR, diarization and voice recognition pipeline remains in place. Refreshing available WhisperKit models preserves selection. Full Large V3 and Turbo remain distinct choices; the existing exact download/load path does not substitute Turbo for a selected full variant.
- After transcription and any speaker-naming confirmation/skip, a raw `.txt` and private JSON sidecar are written to `AI/Transcriptions/Pending`. A verified vault copy replaces the pipeline's duplicate generated transcript. Upstream audio storage and retention are unchanged.
- Pending summaries persist independently of the upstream job's short-lived `.done` state. Explicit requests run in FIFO order with one model request at a time; duplicate active/queued requests are ignored. Manual and transcript-only modes never start a summary automatically.
- The canonical Swedish prompt is copied into `AI/System/Prompts/Meeting-Summary.md` only if absent, and is reloaded for each summary. The OpenAI-compatible transport requires a complete stream for this workflow. HTTP error descriptions never expose an echoed prompt/transcript.
- The model supplies title, tag proposals and body. Code sanitizes titles, validates existing tags (including inline hashtags), builds ordered YAML properties and uses the stored local meeting-start date. Imported audio/transcripts require the actual date/time to be supplied in Pending before summarizing.
- Notes are written to `AI/Meeting notes/YYYY/YYYY-MM-DD - <title>.md`. Transcripts archive only after the note is safely verified, under `AI/Transcriptions/Archive/YYYY/`. Existing files are never overwritten. Persisted transaction intent supports retry after note-write or archive interruption without another model call.
- Retention runs at startup and daily, defaults to 180 days **after archiving**, and requires valid processed metadata, an existing nonempty note, and a false retain flag. It never deletes notes or upstream audio. A Pending item can be marked to retain its transcript indefinitely.
- A non-loopback model endpoint requires explicit approval for that exact endpoint before meeting data is transmitted. Changing endpoints requires a new decision.
- Raw transcripts can be imported/reprocessed from the menu without deleting the source. Microsoft Graph and private Outlook database access are not included.

## Validation performed in this box

| Check | Result |
| --- | --- |
| Shared Foundation/queue XCTest suite using actual production files | **31 tests passed**, Swift 6.2, Linux |
| SwiftFormat 0.63.0, repository-wide check | Passed for the inspected source directories; changed/new Swift files rechecked after final edits |
| Swift syntax parse of app sources and added/changed tests | Passed; this is not Apple SDK type checking |
| SwiftPM manifest and prompt resource declaration | Passed |
| Changed shell scripts and privacy/entitlement plist syntax | Passed |
| Existing script regression files | 9 passed; 8 fail because Linux lacks Apple tools and real signatures, same platform boundary as baseline |
| SwiftLint 0.65.1 | Not executed: missing tool; full `lint.sh` exits nonzero for that reason |
| Full app/unit tests, Xcode analyzer, UI/audio E2E, EventKit runtime | **Unrun: macOS/Xcode required** |

The standalone core runner copies the unchanged production sources into a temporary SwiftPM test package; it does not replace the app with mock logic. It covers raw-byte preservation, private file permissions, path safety, tag discovery/rendering, dates, duplicate destinations, failing note writes, archive conflicts, interrupted transactions, corrupt metadata, retention, calendar scoring, endpoint classification and serial execution. The XCTest runner executed the counts above; the Swift Testing footer reports zero tests because these cases use XCTest.

Additional macOS integration tests are included for fresh settings, native recording policy, notification fallback, manual/no-model behavior, sequential summaries, provider privacy, failed model calls and selected-calendar forwarding. These tests have been syntax checked but **not executed** here.

On Linux with a Swift 6.2 toolchain:

```bash
./scripts/test_custom_core.sh
```

In this prepared box the toolchain is available outside the checkout:

```bash
SWIFT_EXECUTABLE=/workspace/toolchains/swift-6.2-RELEASE-ubuntu24.04/usr/bin/swift ./scripts/test_custom_core.sh
```

## Build and validate on the target Mac

Use the existing fork checkout; a separate Git worktree is unnecessary. macOS 14.2+ and Xcode 26+ / Swift 6.2+ are required. Review the local patch and apply it on the matching baseline or carry these modified/new files over. For a patch transfer:

```bash
git status --short
git apply --check /path/to/meeting-transcriber-custom-draft.patch
git apply /path/to/meeting-transcriber-custom-draft.patch
```

Preserve existing local changes before applying a patch. Do not reset the checkout to make it apply.

From the fork root:

```bash
xcodebuild -version
swift --version
./scripts/test_custom_core.sh
(cd app/MeetingTranscriber && swift test --parallel)
./scripts/lint.sh
./scripts/run_app.sh
```

Use the exact formatter/linter versions in `scripts/tool-versions.sh`; the repository's `scripts/ci/install-lint-tool.sh` documents the checksum-verified pinned Mac downloads. Full SwiftLint, Xcode analyzer and real-model/audio E2E remain required before calling the fork release-ready. Consult `.github/workflows/ci.yml` and `.claude/skills/e2e-architecture/SKILL.md` for those commands and prerequisites. No signing or notarization credentials are needed to run the portable core tests; release signing is separate.

## First functional smoke test

Use a **test vault and synthetic/non-sensitive transcript** before your work vault. Do not run retention tests against real archive content.

1. Start local Ollama. Install a small model appropriate for the 16 GB machine, for example `ollama pull qwen2.5:3b` for an initial non-thinking smoke test. Keep the model unloaded until a summary is requested; the server can remain running.
2. In Settings → General, select Ask before recording and enable Teams. Confirm notification visibility; the menu-bar fallback must remain available if notifications are disabled.
3. In Output, choose the test vault, Manual after transcript, OpenAI-compatible provider, endpoint `http://localhost:11434/v1`, and the exact installed model name. Open the meeting-summary prompt; confirm an existing prompt is preserved.
4. Create a test vault note containing an existing tag such as `#architecture`. Use the menu's Import / reprocess transcript action. The source must remain unchanged. Set its real meeting date/time in Pending. Confirm no model request occurred before Summarize.
5. Summarize. Verify a Swedish note, ordered properties, supplied meeting date, allowed tags only and complete relevant facts. Verify the original bytes in Archive and the absence of the corresponding Pending entry.
6. Import another transcript, stop Ollama, and request a summary. It must stay Pending with an actionable error. Restart Ollama and retry; verify completion.
7. Import two transcripts and request both, including a repeated click on the first. Observe exactly one live generation at a time, two resulting notes and no overwrite when titles match.
8. Test a live Teams meeting: Ignore must record nothing; a new approved meeting must record/transcribe/diarize normally. Confirm or skip speaker naming. Verify the raw transcript enters Pending and another meeting can start while it waits, without loading Ollama.
9. Enable calendar enrichment explicitly, grant access, and select Work only. Verify the work M365 calendar is visible through macOS Calendar/EventKit. Test a good match, overlap ambiguity and denied access; do not expect body-based Teams URL extraction.
10. On the actual M2 Pro, refresh WhisperKit models and explicitly select full Large V3 if exposed. Verify the selected model loads without substituting Turbo and check peak memory with Teams/Edge open.
11. Build/relocate the `.app` and verify the external default prompt can still be created without relying on the original build directory. Both app assembly scripts now carry SwiftPM resource bundles.

The summary currently uses one request per transcript. Configure enough input context in the model server for the entire transcript plus prompt and output; verify long-meeting coverage before relying on it. There is no automatic chunking or reliable server-context introspection in this draft. Explicit truncated/incomplete output is rejected, but model-side input truncation and factual omissions require runtime/content verification.

EventKit availability for the corporate account, actual 16 GB model performance, notification behavior under Focus, macOS sandbox/bookmarks, app compilation and full integration test results are still runtime validation tasks. No remote runner or user machine was contacted to perform them.

## Upstream maintenance

Keep fork changes in consent/settings, calendar, the optional post-transcription output seam, vault services, summary transport options and test/support files. Before a future sync, compare upstream changes to `WatchingController`, `PipelineController`, `SpeakerNamingSession`, recovery and resource assembly. Carry the custom output seam and raw-retention guard through any rebase; changing `.done` to mean “summary finished” would lose durable Pending behavior. Update the recorded baseline after verifying a sync. Submit draft changes to a feature branch in the user's fork, with the PR targeting that fork's `main`. Upstream pushes, merges and application releases require separate authorization.
