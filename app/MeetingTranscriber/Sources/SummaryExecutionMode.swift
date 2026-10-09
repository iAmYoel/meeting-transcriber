import Foundation

enum SummaryExecutionMode: String, Codable, CaseIterable, Sendable {
    case manual
    case automatic
    // swiftlint:disable:next raw_value_for_camel_cased_codable_enum
    case transcriptOnly

    var label: String {
        switch self {
        case .manual: "Manual after transcript"
        case .automatic: "Automatic"
        case .transcriptOnly: "Transcript only"
        }
    }
}
