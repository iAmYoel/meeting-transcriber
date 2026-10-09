# Security and Privacy Design

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
