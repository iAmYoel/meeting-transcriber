# CODEX_TASK.md

You are modifying `pasrom/meeting-transcriber`.

1. Read upstream `CLAUDE.md`.
2. Read this handoff's `AGENTS.md` and all `/docs`.
3. Establish a green baseline.
4. Before coding, produce an implementation map from the CURRENT checkout:
   - exact Phase 1 files/classes,
   - current consent flow,
   - current settings model,
   - current pipeline job/state model,
   - any stale symbol assumptions in this handoff.
5. Implement `docs/IMPLEMENTATION_PLAN.md` one phase at a time.
6. Add tests with every phase.
7. Do not implement Microsoft Graph until EventKit has been tested and Graph is
   explicitly requested.

Non-negotiable defaults:
- Ask before recording.
- Manual summary.
- EventKit enrichment only for MVP.
- Local OpenAI-compatible endpoint by default.
- Existing Obsidian tags only.
- Preserve raw transcript.
- No destructive action after failed summary.
