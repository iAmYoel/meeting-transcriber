# Meeting Transcriber Custom Fork — Codex Handoff

Det här paketet är en komplett utvecklingsspecifikation för en egen fork av
`pasrom/meeting-transcriber`.

## Börja här

1. Läs `AGENTS.md`.
2. Läs `docs/ARCHITECTURE.md`.
3. Läs `docs/REQUIREMENTS.md`.
4. Läs `docs/UPSTREAM_BASELINE.md` innan du ändrar upstream-kod.
5. Implementera enligt `docs/IMPLEMENTATION_PLAN.md`.
6. Verifiera med `docs/TEST_PLAN.md`.
7. Använd `prompts/Meeting-Summary.md` som canonical summary-prompt.

## Mål

Bygg vidare på upstream Meeting Transcriber i stället för att bygga en ny app.

```text
Teams/Zoom/Web meeting detected
        ↓
Visual consent: [Record] [Ignore]
        ↓
Dual-source local recording
        ↓
WhisperKit local transcription
        ↓
FluidAudio diarization + speaker recognition
        ↓
Optional local EventKit calendar enrichment
        ↓
Transcript saved to Obsidian Pending
        ↓
Manual "Summarize" action
        ↓
Local Ollama via OpenAI-compatible API
        ↓
Complete-but-compressed Swedish meeting note
        ↓
Obsidian Meeting note + tags + Properties
        ↓
Transcript moved to Archive
        ↓
Retention after 180 days
```

Grundprinciper:
- Local-first.
- Minimal fork delta from upstream.
- No cloud dependency required.
- Recording never starts silently when `Ask before recording` is selected.
- Calendar is enrichment, not meeting detection source-of-truth.
- LLM summarization is manual by default on the target 16 GB M2 Pro.
- Preserve raw transcript for reprocessing.
- Obsidian is the canonical knowledge store.
