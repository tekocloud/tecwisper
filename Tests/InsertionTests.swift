import Foundation

@main
struct InsertionTests {
    static var count = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ name: String) throws {
        guard condition() else { throw NSError(domain: "InsertionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: name]) }
        count += 1; print("✓ \(name)")
    }
    static func main() throws {
        let valid = InsertionContext(sameApplication: true, sameElement: true, sameWindow: true,
                                     sameSelection: true, sameContent: true, editable: true, secure: false)
        try expect(InsertionPolicy.rejection(valid) == nil, "Unverändertes Textfeld wird angenommen")
        var richEditor = valid; richEditor.sameSelection = nil
        try expect(InsertionPolicy.rejection(richEditor) == nil, "Fehlende Cursorposition in Web-/Electron-Editor blockiert nicht")
        richEditor.sameContent = nil; richEditor.sameWindow = nil
        try expect(InsertionPolicy.rejection(richEditor) == nil, "Optionale Attribute sind unbekannt statt fälschlich verändert")
        var changed = valid; changed.sameApplication = false
        try expect(InsertionPolicy.rejection(changed)?.contains("anderen App") == true, "App-Wechsel blockiert Einfügen")
        changed = valid; changed.sameWindow = false
        try expect(InsertionPolicy.rejection(changed)?.contains("Fenster") == true, "Fensterwechsel innerhalb derselben App blockiert")
        changed = valid; changed.sameElement = false
        try expect(InsertionPolicy.rejection(changed)?.contains("Eingabefeld") == true, "Anderes Textfeld wird nicht überschrieben")
        changed = valid; changed.sameSelection = false
        try expect(InsertionPolicy.rejection(changed)?.contains("Schreibposition") == true, "Nachweislich verschobener Cursor wird berücksichtigt")
        changed = valid; changed.sameContent = false
        try expect(InsertionPolicy.rejection(changed)?.contains("Inhalt") == true, "Nachweislich bearbeiteter Inhalt bleibt geschützt")
        changed = valid; changed.secure = true
        try expect(InsertionPolicy.rejection(changed)?.contains("Geschützte") == true, "Passwort-/Secure-Input wird abgelehnt")
        changed = valid; changed.editable = false
        try expect(InsertionPolicy.rejection(changed)?.contains("beschreibbares") == true, "Nicht editierbare Elemente abgelehnt")
        try expect(InsertionPolicy.confirmsInsertion(before: "Hallo Welt", after: "Hallo neue Welt", text: "neue ", selection: nil), "Textzuwachs ohne AX-Cursorposition bestätigt")
        try expect(!InsertionPolicy.confirmsInsertion(before: "Hallo Welt", after: "Hallo Welt", text: "Hallo", selection: nil), "Bereits vorhandener Text ist kein Einfügenachweis")
        try expect(!InsertionPolicy.confirmsInsertion(before: "Alt", after: "Anderer Text", text: "Text", selection: nil), "Unabhängige Änderung bestätigt keine Übernahme")
        try expect(InsertionPolicy.confirmsInsertion(before: "Hallo alt", after: "Hallo neu", text: "neu", selection: NSRange(location: 6, length: 3)), "Ersetzung einer Auswahl bestätigt")
        try expect(InsertionPolicy.confirmsInsertion(before: "", after: "Hallo\u{00a0}Welt", text: "Hallo Welt", selection: nil), "Geschützte Leerzeichen im Web-Editor berücksichtigt")
        try expect(!InsertionPolicy.confirmsInsertion(before: nil, after: "Text", text: "Text", selection: nil), "Fehlender Ausgangstext bleibt unbestätigt")
        print("\n\(count) Einfüge-Prüfungen erfolgreich.")
    }
}
