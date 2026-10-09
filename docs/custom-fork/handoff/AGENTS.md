# AGENTS.md

This repository is a fork/customization of `pasrom/meeting-transcriber`.

## Prime directive

Do not rewrite the application. Reuse upstream architecture and make the smallest
maintainable changes required to satisfy the product requirements in `/docs`.

Before changing code, read upstream `CLAUDE.md` and the relevant source headers.
The upstream repository's `AGENTS.md` points to `CLAUDE.md`; preserve that convention
where practical.

Keep code, identifiers, tests, UI text, comments and commit-ready text in English.
The generated meeting note is Swedish.

## Required behavior

1. Native Teams/Zoom/Webex detection supports:
   - Ask before recording (DEFAULT)
   - Record automatically
   - Manual only
2. Ask mode uses visible native macOS consent. Never silently auto-record if the
   notification channel is unavailable.
3. Reuse/generalize the existing browser-meeting consent infrastructure.
4. EventKit calendar integration is opt-in and enrichment-only.
5. Only selected calendars and minimum fields are read. Do not read event notes/body
   by default.
6. Do not scrape Outlook's private local database.
7. Microsoft Graph is future fallback, not MVP.
8. Transcription and diarization stay local.
9. Summarization uses the existing OpenAI-compatible provider path.
10. Summary modes:
    - Manual after transcript (DEFAULT)
    - Automatic
    - Transcript only
11. In manual mode, do not start/load the summary LLM until the user requests it.
12. Multiple pending transcripts are supported; summaries run sequentially.
13. Keep raw transcript until summary succeeds and archive completes.
14. Obsidian output follows `docs/OBSIDIAN_CONTRACT.md`.
15. LLM may only choose tags already present in the Obsidian vault.
16. App validates tags after LLM output.
17. LLM never controls arbitrary filesystem paths.
18. Do not log transcript contents, attendee lists, calendar bodies or speaker embeddings.
19. Preserve and extend upstream tests.

## Target hardware

- MacBook Pro, Apple M2 Pro
- 16 GB unified memory
- Teams, Edge and normal work apps may be open concurrently

Therefore summary defaults to manual, no parallel summary jobs, and model choice is
configurable.

## Whisper requirement

The user prefers full Whisper Large v3 when practical.

Do not hard-code a model name the checked-out WhisperKit cannot resolve. Expose models
available through the installed WhisperKit version. Ensure full `large-v3` is selectable
if WhisperKit exposes it. Never silently substitute `large-v3-turbo`.

## Implementation discipline

- Prefer protocols/injected providers.
- Keep calendar provider behind a protocol.
- Keep Obsidian integration behind a service/protocol.
- Use explicit enums for recording policy and summary mode.
- Deterministic code owns filenames, frontmatter, tag validation, file moves, retention.
- Failed summary leaves Pending intact.
- Do not claim done until requirements and tests pass.
