# Desired Settings Profile

## General
```text
Microsoft Teams watch: On
When meeting detected: Ask before recording
```

## Transcription
```text
Engine: WhisperKit
Model: selectable
Preferred: full Large v3 when available/practical
```

## Speakers
```text
Diarization: On
Known voice recognition: On
```

## Calendar
```text
EventKit enrichment: On after explicit opt-in
Selected calendar(s): Work
Title/start/end/attendees/URL: On
Notes/body/location: Off
```

## Summary
```text
Execution: Manual
Provider: OpenAI-compatible
Endpoint: http://localhost:11434/v1/chat/completions
Model: configurable
Prompt: <Vault>/AI/System/Prompts/Meeting-Summary.md
```

Candidate model strategy on 16 GB M2 Pro:
- small ~4B quantized daily model,
- 7–9B quantized optional quality mode,
- never auto-load summary model during meetings.

## Obsidian
```text
AI/Meeting notes/
AI/Transcriptions/Pending/
AI/Transcriptions/Archive/
AI/System/Prompts/Meeting-Summary.md
Retention: 180 days
```
