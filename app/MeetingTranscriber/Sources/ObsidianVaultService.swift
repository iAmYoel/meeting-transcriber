import Foundation

struct PendingMeetingSummary: Codable, Identifiable, Equatable, Sendable {
    let schemaVersion: Int
    let id: UUID
    var meetingStart: Date
    var meetingDate: String
    var hasRecordedStart: Bool
    let sourceTitle: String
    let appName: String
    let mode: SummaryExecutionMode
    let calendar: CalendarMeetingMetadata?
    let transcriptRelativePath: String
    var processed: Bool
    var archivedAt: Date?
    var summaryNote: String?
    var archiveTranscript: String?
    var preparedNote: String?
    var retainTranscript: Bool
}

protocol ObsidianVaultServing {
    func discoverExistingTags() throws -> [String]
    func writePendingTranscript(_ text: String, record: PendingMeetingSummary) throws
    func pendingMeetings() throws -> [PendingMeetingSummary]
    func complete(_ note: MeetingNoteRenderer.Note, record: PendingMeetingSummary, now: Date) throws -> URL
}

/// A persisted two-step transaction: note first, then archive. Every failure preserves a transcript.
struct ObsidianVaultService: ObsidianVaultServing, Sendable {
    let root: URL
    private let fm = FileManager.default

    enum VaultError: LocalizedError {
        case unsafePath, conflict, missingTranscript, invalidMetadata

        var errorDescription: String? {
            switch self {
            case .unsafePath: "A vault path is unsafe or uses a symlink. No files were removed."
            case .conflict: "A destination already exists or changed. Pending was retained."
            case .missingTranscript: "The pending transcript could not be read."
            case .invalidMetadata: "Meeting metadata is unreadable. No files were removed."
            }
        }
    }

    init(root: URL) {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath()
    }

    func checkedURL(_ relative: String) throws -> URL {
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              !relative.contains("\\"), !relative.contains("\0") else { throw VaultError.unsafePath }
        var result = root
        for part in parts {
            result.appendPathComponent(String(part))
            let values = try? result.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard values?.isSymbolicLink != true else { throw VaultError.unsafePath }
        }
        guard result.standardizedFileURL.path.hasPrefix(root.path + "/") else { throw VaultError.unsafePath }
        return result
    }

    private func ensureParent(of url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }

    private func privateWrite(_ data: Data, to url: URL, overwrite: Bool) throws {
        try ensureParent(of: url)
        if overwrite { try data.write(to: url, options: .atomic) }
        else {
            let staging = url.deletingLastPathComponent().appendingPathComponent(".meeting-\(UUID().uuidString).tmp")
            defer { try? fm.removeItem(at: staging) }
            try data.write(to: staging, options: .withoutOverwriting)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: staging.path)
            try fm.moveItem(at: staging, to: url)
        }
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func pendingSidecar(_ id: UUID) throws -> URL {
        try checkedURL("AI/Transcriptions/Pending/\(id.uuidString).json")
    }

    private func save(_ record: PendingMeetingSummary, at path: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try privateWrite(encoder.encode(record), to: path, overwrite: true)
    }

    private func decode(_ url: URL) throws -> PendingMeetingSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(PendingMeetingSummary.self, from: Data(contentsOf: url))
        guard record.schemaVersion == 1,
              record.transcriptRelativePath == "AI/Transcriptions/Pending/\(record.id.uuidString).txt",
              record.meetingDate.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
        else { throw VaultError.invalidMetadata }
        return record
    }

    func installPromptIfAbsent(_ prompt: String) throws {
        let path = try checkedURL("AI/System/Prompts/Meeting-Summary.md")
        guard !fm.fileExists(atPath: path.path) else { return }
        try privateWrite(Data(prompt.utf8), to: path, overwrite: false)
    }

    func loadPrompt() throws -> String {
        try String(contentsOf: checkedURL("AI/System/Prompts/Meeting-Summary.md"), encoding: .utf8)
    }

    func writePendingTranscript(_ text: String, record: PendingMeetingSummary) throws {
        let sidecar = try pendingSidecar(record.id)
        if fm.fileExists(atPath: sidecar.path) {
            let existing = try decode(sidecar)
            guard existing.id == record.id else { throw VaultError.invalidMetadata }
            guard try transcript(for: existing) == text || existing.preparedNote != nil else { throw VaultError.conflict }
            return
        }
        let path = try checkedURL(record.transcriptRelativePath)
        let data = Data(text.utf8)
        if fm.fileExists(atPath: path.path) {
            guard try Data(contentsOf: path) == data else { throw VaultError.conflict }
        } else { try privateWrite(data, to: path, overwrite: false) }
        try save(record, at: sidecar)
    }

    func pendingMeetings() throws -> [PendingMeetingSummary] {
        try loadPending().records
    }

    func loadPending() throws -> (records: [PendingMeetingSummary], unreadableCount: Int) {
        let folder = try checkedURL("AI/Transcriptions/Pending")
        guard fm.fileExists(atPath: folder.path) else { return ([], 0) }
        let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        var records: [PendingMeetingSummary] = []
        var unreadable = 0
        for url in files where url.pathExtension == "json" {
            do {
                _ = try checkedURL("AI/Transcriptions/Pending/" + url.lastPathComponent)
                let record = try decode(url)
                guard url.lastPathComponent == record.id.uuidString + ".json" else { throw VaultError.invalidMetadata }
                records.append(record)
            } catch { unreadable += 1 }
        }
        return (records.sorted { $0.meetingStart < $1.meetingStart }, unreadable)
    }

    func updatePending(id: UUID, meetingStart: Date? = nil, retainTranscript: Bool? = nil) throws {
        let path = try pendingSidecar(id)
        var record = try decode(path)
        guard record.id == id, record.preparedNote == nil else { throw VaultError.conflict }
        if let meetingStart {
            record.meetingStart = meetingStart
            record.meetingDate = MeetingNoteRenderer.dateString(meetingStart)
            record.hasRecordedStart = true
        }
        if let retainTranscript { record.retainTranscript = retainTranscript }
        try save(record, at: path)
    }

    func transcript(for record: PendingMeetingSummary) throws -> String {
        let pending = try checkedURL(record.transcriptRelativePath)
        if fm.fileExists(atPath: pending.path) { return try String(contentsOf: pending, encoding: .utf8) }
        if let relative = record.archiveTranscript {
            let archived = try checkedURL(relative)
            return try String(contentsOf: archived, encoding: .utf8)
        }
        throw VaultError.missingTranscript
    }

    func discoverExistingTags() throws -> [String] {
        var notes: [URL] = []
        guard let enumerator = fm.enumerator(
            at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
        ) else { throw VaultError.unsafePath }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let relative = String(url.path.dropFirst(root.path.count + 1))
            if values.isSymbolicLink == true || url.lastPathComponent == ".git" || url.lastPathComponent == ".obsidian"
                || relative == "AI/System" || relative == "AI/Transcriptions" {
                enumerator.skipDescendants()
                continue
            }
            if values.isDirectory != true, url.pathExtension.lowercased() == "md" { notes.append(url) }
        }
        var canonical: [String: String] = [:]
        for url in notes.sorted(by: { $0.path < $1.path }) {
            for tag in try VaultTagScanner.tags(in: String(contentsOf: url, encoding: .utf8)) {
                if canonical[tag.lowercased()] == nil { canonical[tag.lowercased()] = tag }
            }
        }
        return canonical.values.sorted()
    }

    private func unusedPath(base: String, extension ext: String) throws -> String {
        for suffix in 0 ... 10000 {
            let candidate = base + (suffix == 0 ? "" : " - \(suffix)") + "." + ext
            let url = try checkedURL(candidate)
            let sidecar = url.deletingPathExtension().appendingPathExtension("json")
            if !fm.fileExists(atPath: url.path), !fm.fileExists(atPath: sidecar.path) { return candidate }
        }
        throw VaultError.conflict
    }

    func complete(_ note: MeetingNoteRenderer.Note, record original: PendingMeetingSummary, now: Date) throws -> URL {
        var record = original
        let year = String(record.meetingDate.prefix(4))
        let pending = try pendingSidecar(record.id)
        if record.summaryNote == nil {
            record.summaryNote = try unusedPath(
                base: "AI/Meeting notes/\(year)/\(record.meetingDate) - \(note.title)", extension: "md",
            )
            record.archiveTranscript = try unusedPath(
                base: "AI/Transcriptions/Archive/\(year)/\(record.meetingDate) - transcription - \(note.title)", extension: "txt",
            )
            record.preparedNote = note.markdown
            try save(record, at: pending) // Persist intent before publishing either destination.
        }
        guard let noteRelative = record.summaryNote, let archiveRelative = record.archiveTranscript,
              let markdown = record.preparedNote else { throw VaultError.invalidMetadata }
        guard noteRelative.hasPrefix("AI/Meeting notes/"), noteRelative.hasSuffix(".md"),
              archiveRelative.hasPrefix("AI/Transcriptions/Archive/"), archiveRelative.hasSuffix(".txt")
        else { throw VaultError.invalidMetadata }
        let destination = try checkedURL(noteRelative)
        let expected = Data(markdown.utf8)
        if fm.fileExists(atPath: destination.path) {
            guard try Data(contentsOf: destination) == expected else { throw VaultError.conflict }
        } else {
            try privateWrite(expected, to: destination, overwrite: false)
        }
        guard try Data(contentsOf: destination) == expected else { throw VaultError.conflict }
        let source = try checkedURL(record.transcriptRelativePath)
        let archive = try checkedURL(archiveRelative)
        if fm.fileExists(atPath: source.path) {
            try ensureParent(of: archive)
            if fm.fileExists(atPath: archive.path) {
                // Do not destroy either copy after a conflict. This can only be manually resolved.
                throw VaultError.conflict
            }
            try fm.moveItem(at: source, to: archive)
        } else if !fm.fileExists(atPath: archive.path) { throw VaultError.missingTranscript }
        record.processed = true
        record.archivedAt = now
        record.preparedNote = nil
        try save(record, at: archive.deletingPathExtension().appendingPathExtension("json"))
        try fm.removeItem(at: pending) // The archive and final sidecar already exist.
        return destination
    }

    func resumeCompletion(_ record: PendingMeetingSummary, now: Date) throws -> URL? {
        guard let markdown = record.preparedNote else { return nil }
        return try complete(.init(title: "", tags: [], markdown: markdown), record: record, now: now)
    }

    /// Retention applies only to this service's archived raw transcripts. Notes and upstream audio are never deleted.
    func applyRetention(days: Int, now: Date) throws -> Int {
        guard days > 0 else { return 0 }
        let folder = try checkedURL("AI/Transcriptions/Archive")
        guard fm.fileExists(atPath: folder.path) else { return 0 }
        guard let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: [.isSymbolicLinkKey]) else { return 0 }
        var removed = 0
        for case let sidecar as URL in enumerator {
            guard sidecar.pathExtension == "json" else { continue }
            if try (sidecar.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            guard sidecar.pathExtension == "json" else { continue }
            let record: PendingMeetingSummary
            do { record = try decode(sidecar) } catch { throw VaultError.invalidMetadata }
            guard record.processed, !record.retainTranscript, let date = record.archivedAt,
                  now.timeIntervalSince(date) >= Double(days) * 86400,
                  let note = record.summaryNote, note.hasPrefix("AI/Meeting notes/"), note.hasSuffix(".md"),
                  let transcript = record.archiveTranscript, transcript.hasPrefix("AI/Transcriptions/Archive/"),
                  transcript.hasSuffix(".txt") else { continue }
            let noteURL = try checkedURL(note)
            let transcriptURL = try checkedURL(transcript)
            guard transcriptURL.deletingPathExtension().appendingPathExtension("json") == sidecar,
                  fm.fileExists(atPath: noteURL.path),
                  (try? String(contentsOf: noteURL, encoding: .utf8).isEmpty) == false,
                  fm.fileExists(atPath: transcriptURL.path) else { continue }
            try fm.removeItem(at: transcriptURL)
            removed += 1
        }
        return removed
    }
}
