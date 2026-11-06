import Foundation

struct InsertionContext {
    var sameApplication: Bool
    var sameElement: Bool
    var sameWindow: Bool?
    var sameSelection: Bool?
    var sameContent: Bool?
    var editable: Bool
    var secure: Bool
}
enum InsertionPolicy {
    static func confirmsInsertion(before: String?, after: String?, text: String, selection: NSRange?) -> Bool {
        guard let before, let after, !text.isEmpty else { return false }
        func normalized(_ value: String) -> String {
            value.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\u{2029}", with: "\n")
                .replacingOccurrences(of: "\u{00a0}", with: " ")
        }
        guard normalized(before) != normalized(after) else { return false }
        if let selection, selection.location >= 0, selection.length >= 0,
           selection.location <= (before as NSString).length,
           selection.length <= (before as NSString).length - selection.location {
            return normalized((before as NSString).replacingCharacters(in: selection, with: text)) == normalized(after)
        }
        // Some web editors expose their value but no selected range. Confirm only
        // if removing exactly the inserted text reconstructs the complete old value.
        let old = normalized(before), new = normalized(after), inserted = normalized(text)
        var search = new.startIndex..<new.endIndex
        while let range = new.range(of: inserted, range: search) {
            var candidate = new; candidate.removeSubrange(range)
            if candidate == old { return true }
            search = range.upperBound..<new.endIndex
        }
        return false
    }

    static func rejection(_ context: InsertionContext) -> String? {
        if context.secure { return "Geschützte Eingabe: Der Text wird nicht automatisch eingefügt." }
        if !context.sameApplication { return "Du hast zu einer anderen App gewechselt. Der Text bleibt zum Kopieren verfügbar." }
        if context.sameWindow == false { return "Das ursprüngliche Fenster ist nicht mehr aktiv. Der Text bleibt zum Kopieren verfügbar." }
        if !context.sameElement { return "Das ursprüngliche Eingabefeld ist nicht mehr aktiv. Der Text bleibt zum Kopieren verfügbar." }
        if !context.editable { return "Das aktive Element ist kein beschreibbares Textfeld." }
        if context.sameSelection == false { return "Die Schreibposition wurde während des Diktats verändert. Der Text bleibt zum Kopieren verfügbar." }
        if context.sameContent == false { return "Der Inhalt des Eingabefelds wurde während des Diktats verändert. Der Text bleibt zum Kopieren verfügbar." }
        return nil
    }
}
