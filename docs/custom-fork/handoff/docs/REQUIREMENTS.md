# Requirements and Acceptance Criteria

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
