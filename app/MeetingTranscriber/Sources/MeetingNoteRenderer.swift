import Foundation

/// The model supplies semantic text only. Code controls properties, tag spelling and filenames.
enum MeetingNoteRenderer {
    struct Note: Equatable, Sendable {
        let title: String
        let tags: [String]
        let markdown: String
    }

    enum RenderError: LocalizedError {
        case emptyBody
        case invalidControlLines

        var errorDescription: String? {
            switch self {
            case .emptyBody: "The summary contains no meeting note. Pending was retained."
            case .invalidControlLines: "The summary response is missing TITLE/TAGS control lines. Pending was retained."
            }
        }
    }

    static func safeTitle(_ title: String, fallback: String) -> String {
        let forbidden = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/\\:*?\"<>|"))
        let cleaned = title.components(separatedBy: forbidden).joined(separator: " ")
            .replacingOccurrences(of: "..", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return cleaned.isEmpty ? fallback : String(cleaned.prefix(100))
    }

    static func dateString(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func fallbackTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH-mm"
        return "Meeting " + formatter.string(from: date)
    }

    static func render(
        response: String, allowedTags: [String], meetingDate: String, fallback: String,
    ) throws -> Note {
        let lines = response.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\n")
        guard lines.count >= 3, lines[0].hasPrefix("TITLE:"), lines[1].hasPrefix("TAGS:") else {
            throw RenderError.invalidControlLines
        }
        let proposed = String(lines[0].dropFirst(6)).trimmingCharacters(in: .whitespaces)
        let allowed = Set(allowedTags)
        let title = safeTitle(
            neutralizeUnknownInlineTags(proposed, allowed: allowed),
            fallback: safeTitle(neutralizeUnknownInlineTags(fallback, allowed: allowed), fallback: "Meeting"),
        )
        let requested = lines[1].dropFirst(5).split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        }
        let tags = Array(Set(requested.filter { allowed.contains($0) })).sorted()
        var body = lines.dropFirst(2).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !body.hasPrefix("---"), !body.hasPrefix("```") else { throw RenderError.emptyBody }
        if body.hasPrefix("# ") {
            body = body.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !body.isEmpty else { throw RenderError.emptyBody }
        body = neutralizeUnknownInlineTags(body, allowed: allowed)
        let yamlTags = tags.isEmpty ? "tags: []" : "tags:\n" + tags.map { "  - " + yamlString($0) }.joined(separator: "\n")
        let markdown = "---\nnoteType: Meeting\ndate: \(meetingDate)\ncustomer: \"\"\nmembers: \"\"\n\(yamlTags)\n---\n\n# \(title)\n\n\(body)\n"
        return Note(title: title, tags: tags, markdown: markdown)
    }

    private static func neutralizeUnknownInlineTags(_ body: String, allowed: Set<String>) -> String {
        let pattern = #"(?<![\p{L}\p{N}_/])#([\p{L}\p{N}_-]+(?:/[\p{L}\p{N}_-]+)*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return body }
        var fence: String?
        return body.components(separatedBy: "\n").map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                let marker = String(trimmed.prefix(3))
                if fence == marker { fence = nil } else if fence == nil { fence = marker }
                return line
            }
            guard fence == nil else { return line }
            return line.components(separatedBy: "`").enumerated().map { index, part in
                guard index.isMultiple(of: 2) else { return part }
                var result = part
                let matches = regex.matches(in: part, range: NSRange(part.startIndex..., in: part))
                for match in matches.reversed() {
                    guard let tagRange = Range(match.range(at: 1), in: part),
                          !allowed.contains(String(part[tagRange])),
                          let fullRange = Range(match.range, in: result) else { continue }
                    result.replaceSubrange(fullRange, with: String(part[tagRange]))
                }
                return result
            }.joined(separator: "`")
        }.joined(separator: "\n")
    }

    private static func yamlString(_ text: String) -> String {
        // JSON strings are valid YAML quoted scalars and escape control characters deterministically.
        let encoded = try? JSONEncoder().encode(text)
        return encoded.flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
    }
}
