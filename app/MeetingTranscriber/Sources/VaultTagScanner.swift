import Foundation

/// Read tag declarations only; never send unrelated note contents to the model.
enum VaultTagScanner {
    static func tags(in markdown: String) -> [String] {
        var tags = Set<String>()
        var inFrontmatter = false
        var tagList = false
        var fence: String?
        for (index, rawLine) in markdown.components(separatedBy: "\n").enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if index == 0, line == "---" { inFrontmatter = true; continue }
            if inFrontmatter {
                if line == "---" { inFrontmatter = false; continue }
                if line.hasPrefix("tags:") {
                    let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    tagList = value.isEmpty
                    if !value.isEmpty {
                        let list = value.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                        for token in list.split(separator: ",") {
                            insert(String(token), into: &tags)
                        }
                    }
                } else if tagList, line.hasPrefix("- ") {
                    insert(String(line.dropFirst(2)), into: &tags)
                } else if !line.isEmpty, !line.hasPrefix("#") { tagList = false }
                continue
            }
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                let marker = String(line.prefix(3))
                if fence == marker { fence = nil } else if fence == nil { fence = marker }
                continue
            }
            guard fence == nil else { continue }
            // Strip inline code spans before looking for hashtags.
            let visible = rawLine.components(separatedBy: "`").enumerated()
                .filter { $0.offset.isMultiple(of: 2) }.map(\.element).joined(separator: " ")
            let pattern = #"(?<![\p{L}\p{N}_/])#([\p{L}\p{N}_-]+(?:/[\p{L}\p{N}_-]+)*)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                for match in regex.matches(in: visible, range: NSRange(visible.startIndex..., in: visible)) {
                    if let range = Range(match.range(at: 1), in: visible) { insert(String(visible[range]), into: &tags) }
                }
            }
        }
        // Case-folded duplicates use the first deterministic spelling discovered by the vault traversal.
        return tags.sorted()
    }

    private static func insert(_ raw: String, into tags: inout Set<String>) {
        let tag = raw.trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard !tag.isEmpty, tag.range(of: #"^[\p{L}\p{N}_/-]+$"#, options: .regularExpression) != nil,
              tag.rangeOfCharacter(from: .letters) != nil else { return }
        tags.insert(tag)
    }
}
