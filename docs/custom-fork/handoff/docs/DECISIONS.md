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
