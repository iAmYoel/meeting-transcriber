import Foundation

/// Explicit choices for automatic meeting detection; manual Record actions remain available.
enum RecordingStartPolicy: String, Codable, CaseIterable, Sendable {
    case ask
    case automatic
    // swiftlint:disable:next raw_value_for_camel_cased_codable_enum
    case manualOnly

    var label: String {
        switch self {
        case .ask: "Ask before recording"
        case .automatic: "Record automatically"
        case .manualOnly: "Manual only"
        }
    }

    func requiresConsent(forBrowser: Bool) -> Bool {
        self == .ask || forBrowser
    }
}
