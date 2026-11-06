import Foundation

struct DictationText: Codable, Equatable {
    let original: String
    var output: String
}
struct DictationHistoryEntry: Codable, Identifiable, Equatable {
    var id: UUID { record.id }
    let record: DictationRecord
    let text: DictationText
}
