import Foundation
import SQLite3

@main
struct HistoryTests {
    static var count = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ title: String) throws {
        guard condition() else { throw NSError(domain: "HistoryTests", code: 1, userInfo: [NSLocalizedDescriptionKey: title]) }
        count += 1; print("✓ \(title)")
    }
    static func fixture() -> DictationRecord {
        .init(id: UUID(), startedAt: Date(), day: "2026-10-29", hour: 22, timeZone: "Europe/Berlin", appID: "test.editor", appName: "Test-Editor", inputLanguage: "de", outputLanguage: "auto", translated: false, cleanupEnabled: true, outcome: .success, words: 3, transcriptWords: 4, recordingSeconds: 2, processingSeconds: 1, audioSeconds: 0.5, correctionSeconds: 0.5, errorStage: nil)
    }
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("TecWisperHistoryTests-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("history.sqlite")
        // Make an actual version-1 database, as shipped before text history existed.
        var db: OpaquePointer?
        sqlite3_open(url.path, &db)
        sqlite3_exec(db, "CREATE TABLE dictations(id TEXT PRIMARY KEY,day TEXT,payload BLOB); CREATE TABLE metadata(key TEXT PRIMARY KEY,value REAL); INSERT INTO metadata VALUES ('createdAt',12345); PRAGMA user_version=1;", nil, nil, nil)
        let old = fixture()
        let data = try JSONEncoder().encode(old)
        var query: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO dictations VALUES (?,?,?)", -1, &query, nil)
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(query, 1, old.id.uuidString, -1, transient)
        sqlite3_bind_text(query, 2, old.day, -1, transient)
        _ = data.withUnsafeBytes { sqlite3_bind_blob(query, 3, $0.baseAddress, Int32(data.count), transient) }
        sqlite3_step(query); sqlite3_finalize(query); sqlite3_close(db)
        let store = try StatisticsStore(url: url)
        let migrated = try await store.snapshot()
        try expect(migrated.records == [old] && migrated.history.isEmpty, "V1-Migration erhält alte Einträge ohne erfundene Texte")
        try expect(migrated.createdAt == Date(timeIntervalSince1970: 12345), "Migration erhält Erfassungsbeginn")
        let new = fixture()
        let text = DictationText(original: "äh wir treffen uns morgen", output: "Wir treffen uns morgen.")
        try await store.insert(new, text: text)
        try await store.insert(new, text: text)
        let saved = try await store.snapshot()
        try expect(saved.records.count == 2 && saved.history.count == 1, "Atomare Speicherung und idempotente Verlaufseinträge")
        try expect(saved.history[0].text.original == text.original && saved.history[0].text.output == text.output, "Ursprünglich Gesprochenes und korrigierter Text bleiben getrennt")
        try expect(saved.history[0].record.appName == "Test-Editor" && saved.history[0].id == new.id, "Text bleibt eindeutig mit Ziel-App und Aufnahme verknüpft")
        let reopened = try StatisticsStore(url: url)
        let restored = try await reopened.snapshot()
        try expect(restored.history == saved.history, "Diktattexte überstehen App-Neustart")
        let csv = StatisticsCSV.export(saved.records)
        try expect(!csv.contains(text.original) && !csv.contains(text.output), "Statistik-CSV exportiert keine Diktattexte")
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        try expect((attrs[.posixPermissions] as? NSNumber)?.intValue == 0o600, "Verlaufsdatei nur für den lokalen Benutzer lesbar")
        try await store.reset()
        let statsReset = try await store.snapshot()
        try expect(statsReset.records.isEmpty && statsReset.history.count == 1, "Statistik-Reset erhält separat gespeicherten Verlauf")
        try await store.clearHistory()
        let historyCleared = try await store.snapshot()
        try expect(historyCleared.history.isEmpty, "Diktattexte gezielt löschbar")
        let only = fixture()
        try await store.insert(only, text: text, includeStatistics: false)
        let historyOnly = try await store.snapshot()
        try expect(historyOnly.records.isEmpty && historyOnly.history.count == 1, "Verlauf unabhängig von Statistik aufzeichnen")
        try await store.insert(old)
        try await store.clearHistory()
        let cleared = try await store.snapshot()
        try expect(cleared.history.isEmpty && cleared.records.count == 1, "Löschen des Verlaufs erhält Statistik")
        try await modelTests(folder: folder, record: new, text: text)
        print("\n\(count) Verlaufs-Prüfungen erfolgreich.")
    }
    @MainActor static func modelTests(folder: URL, record: DictationRecord, text: DictationText) async throws {
        let suite = "TecWisperHistoryModel-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = StatisticsModel(url: folder.appendingPathComponent("model.sqlite"), defaults: defaults)
        await model.flush()
        try expect(model.historyEnabled, "Textverlauf wie angefordert standardmäßig aktiviert")
        model.settings.enabled = false
        model.record(record, text: text, includeStatistics: false)
        await model.flush()
        try expect(model.records.isEmpty && model.activityRecords.count == 1 && model.text(for: record.id) == text, "Start und Aktivität können Text ohne Statistik-Eintrag anzeigen")
        var capturing = true
        model.onHistoryDisable = { capturing = false }
        model.historyEnabled = false
        try expect(!capturing && model.history.count == 1, "Abschalten stoppt laufende Text-Erfassung und erhält vorhandenen Verlauf")
        let reload = StatisticsModel(url: folder.appendingPathComponent("model.sqlite"), defaults: defaults)
        await reload.flush()
        try expect(!reload.historyEnabled && reload.text(for: record.id) == text, "Verlaufsschalter und Texte bleiben über Neustart erhalten")
        model.clearHistory(); await model.flush()
        try expect(model.history.isEmpty && model.activityRecords.isEmpty && model.text(for: record.id) == nil, "Verlauf löschen aktualisiert beide Ansichten und Textindex")
    }
}
