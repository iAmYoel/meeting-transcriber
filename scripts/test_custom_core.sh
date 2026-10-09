#!/usr/bin/env bash
# Compile the actual Foundation-only production files and shared XCTest cases.
# This does not replace macOS SwiftUI/EventKit/audio integration tests.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_DIR="$(mktemp -d /tmp/meeting-custom-core.XXXXXX)"
trap 'rm -rf "$TASK_DIR"' EXIT
mkdir -p "$TASK_DIR/Sources/CustomMeetingCore" "$TASK_DIR/Tests/CustomMeetingCoreTests" "$TASK_DIR/cache"
for name in RecordingStartPolicy SummaryExecutionMode MeetingOutputReceipt CalendarMeetingMetadata MeetingNoteRenderer VaultTagScanner ObsidianVaultService SummaryEndpointPolicy SerialSummaryQueue; do
    cp "$REPO_ROOT/app/MeetingTranscriber/Sources/$name.swift" "$TASK_DIR/Sources/CustomMeetingCore/"
done
for name in CustomMeetingCoreTests CustomSummaryQueueTests; do
    cp "$REPO_ROOT/app/MeetingTranscriber/Tests/$name.swift" "$TASK_DIR/Tests/CustomMeetingCoreTests/"
done
cat > "$TASK_DIR/Package.swift" <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "CustomMeetingCore",
    products: [.library(name: "CustomMeetingCore", targets: ["CustomMeetingCore"])],
    targets: [
        .target(name: "CustomMeetingCore", swiftSettings: [.treatAllWarnings(as: .error)]),
        .testTarget(name: "CustomMeetingCoreTests", dependencies: ["CustomMeetingCore"]),
    ]
)
SWIFT
export CLANG_MODULE_CACHE_PATH="$TASK_DIR/cache/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$TASK_DIR/cache/swift"
"${SWIFT_EXECUTABLE:-swift}" test --package-path "$TASK_DIR" --cache-path "$TASK_DIR/cache/swiftpm" --config-path "$TASK_DIR/config" --security-path "$TASK_DIR/security" -j 4
