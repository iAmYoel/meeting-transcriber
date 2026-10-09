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
