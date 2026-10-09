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
