# Verified Upstream Baseline

Research date: 2026-10-08.

Repository:
`https://github.com/pasrom/meeting-transcriber`

Upstream moves quickly; inspect the checked-out revision before coding.

Current public docs describe:
- Swift/SwiftUI menu-bar app,
- `AppState` composition root,
- `TranscribingEngine`,
- `WhisperKitEngine`,
- `ParakeetEngine`,
- `DualSourceRecorder`,
- `FluidDiarizer`,
- `SpeakerMatcher`,
- `PipelineQueue`,
- `ProtocolGenerating`,
- `ClaudeCLIProtocolGenerator`,
- `OpenAIProtocolGenerator`,
- local `/v1` automation API.

Detection docs describe:
- `MeetingDetecting`,
- `PowerAssertionDetector`,
- `MicInputDetector`,
- browser WebRTC detection,
- browser consent around `AppMeetingPattern.requiresRecordingConsent`,
  `WatchLoop.requestConsentIfNeeded` and `NotificationManager.askToRecord`.

`CLAUDE.md` is more precise/current than some README wording. Source + current
`CLAUDE.md` are authoritative.

Protocol generation supports:
- `.claudeCLI`,
- `.openAICompatible`,
- `.none`,
- custom prompt file,
- meeting date/time variables,
- Ollama/LM Studio/llama.cpp compatible endpoints,
- raw transcript retention.

Output directory is configurable.

Upstream testing includes XCTest, ViewInspector/SnapshotTesting, fixture E2E,
app-level Apple Silicon E2E, meeting simulator and debug RPC inspection.

Public references:
- https://github.com/pasrom/meeting-transcriber
- https://github.com/pasrom/meeting-transcriber/blob/main/CLAUDE.md
- https://github.com/pasrom/meeting-transcriber/blob/main/docs/automation-api.md
- https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- https://learn.microsoft.com/graph/permissions-reference
