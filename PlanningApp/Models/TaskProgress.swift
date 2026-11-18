import Foundation

struct ProgressMarker: Codable, Identifiable, Equatable {
    let id: UUID
    var label: String

    init(id: UUID = UUID(), label: String) {
        self.id = id
        self.label = label
    }
}

struct ProgressConfiguration: Codable, Equatable {
    // Stable identities let legacy tasks resolve consistently before their first save.
    static let defaultMarkers = [
        ProgressMarker(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, label: "To do"),
        ProgressMarker(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, label: "In progress")
    ]

    var isEnabled = false
    var markers: [ProgressMarker] = Self.defaultMarkers

    var isValid: Bool {
        guard !markers.isEmpty, Set(markers.map(\.id)).count == markers.count else { return false }
        var names = Set<String>()
        for marker in markers {
            let trimmed = marker.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed == marker.label,
                  names.insert(Self.nameKey(trimmed)).inserted else { return false }
        }
        return true
    }

    static func nameKey(_ label: String) -> String {
        label.folding(options: .caseInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
    }
}
