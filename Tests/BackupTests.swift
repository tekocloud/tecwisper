import Foundation
import SQLite3

@main
struct BackupTests {
    static func check(_ value: Bool, _ title: String) throws {
        guard value else { throw NSError(domain: "BackupTests", code: 1, userInfo: [NSLocalizedDescriptionKey: title]) }
        print("✓ \(title)")
    }
    static func rejected(_ operation: () throws -> Void) -> Bool {
        do { try operation(); return false } catch { return true }
    }
    static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let suite = "BackupTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var prefs = Preferences(); prefs.dictionary = "TecWisper → TecWisper\nÄÖÜ"; prefs.promptInstructions = "Meine Vorgaben"; prefs.promptOptimization = true
        prefs.holdShortcut = nil; prefs.microphoneID = "missing-device"
        var settings = StatisticsSettings(defaults: defaults); settings.enabled = false; settings.typingWPM = 77
        let record = DictationRecord(id: UUID(), startedAt: Date(), day: "2026-10-31", hour: 10, timeZone: "Europe/Berlin", appID: "editor", appName: "Editor", inputLanguage: "auto", outputLanguage: "de", translated: true, cleanupEnabled: false, outcome: .success, words: 2, transcriptWords: 2, recordingSeconds: 1, processingSeconds: 1, audioSeconds: nil, correctionSeconds: nil, errorStage: nil)
        let entry = DictationHistoryEntry(record: record, text: .init(original: "Hallo Welt", output: "Hallo Welt!"))
        var backup = TecWisperBackup(appVersion: "1.3.9", buildNumber: "15", preferences: prefs, statisticsSettings: settings, historyEnabled: false, statisticsCreatedAt: Date(timeIntervalSince1970: 42), records: [], history: [entry])
        let file = folder.appendingPathComponent("test.tecwisperbackup")
        try BackupService.write(backup, to: file)
        let decoded = try BackupService.read(file)
        try check(decoded.preferences == prefs && decoded.statisticsSettings == settings && !decoded.historyEnabled && decoded.history == [entry], "Vollständiger Datei-Rundlauf einschließlich deaktivierter Erfassung und individueller Vorgaben")
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        try check(permissions?.intValue == 0o600, "Sicherungsdatei nur für eigenen Benutzer lesbar")
        var complete = decoded; complete.records = [record]
        try BackupService.write(complete, to: file)
        let full = try BackupService.read(file)
        try check(full.records == [record] && full.history == [entry], "Statistik und Text gemeinsam unverändert gesichert")
        complete.records.append(record)
        try check(rejected { try complete.validate() }, "Doppelte Statistik-IDs werden abgelehnt")
        complete = decoded; complete.preferences.baseURL = "https://example.com"
        try check(rejected { try complete.validate() }, "Nicht lokale Ollama-Adresse wird abgelehnt")
        complete = decoded; complete.preferences.holdShortcut = Shortcut(keyCode: 999, modifiers: 2048)
        try check(rejected { try complete.validate() }, "Ungültiger Tastencode wird abgelehnt")
        try Data("{broken".utf8).write(to: file)
        try check(rejected { _ = try BackupService.read(file) }, "Beschädigtes JSON wird abgelehnt")
        try Data(#"{"format":"TecWisperBackup","formatVersion":2}"#.utf8).write(to: file)
        do {
            _ = try BackupService.read(file)
            throw NSError(domain: "ExpectedNewer", code: 1)
        } catch BackupError.newer { print("✓ Neueres Dateiformat vor Pflichtfeldprüfung erkannt") }
        let dbURL = folder.appendingPathComponent("test.sqlite")
        let store = try StatisticsStore(url: dbURL)
        try await store.insert(record)
        try await store.replace(with: decoded.snapshot)
        let snapshot = try await store.snapshot()
        try check(snapshot.records.isEmpty && snapshot.history == [entry] && snapshot.createdAt == decoded.statisticsCreatedAt, "Ersetzen erhält Verlauf ohne Statistik und Erfassungsbeginn")
        backup.history.append(entry)
        try check(rejected { try backup.validate() }, "Doppelte IDs werden abgelehnt")
        backup.history = [entry]; backup.preferences.inputLanguage = "invalid"
        try check(rejected { try backup.validate() }, "Ungültige Einstellungen werden abgelehnt")
        backup.preferences = prefs; backup.formatVersion = 2
        try check(rejected { try backup.validate() }, "Neueres Format wird abgelehnt")
        try Data("{}".utf8).write(to: file)
        try check(rejected { _ = try BackupService.read(file) }, "Unvollständige Datei wird abgelehnt")
        try check(rejected { try BackupService.write(decoded, to: folder.appendingPathComponent("missing/backup")) }, "Schreibfehler werden weitergegeben")
        // Force an insertion failure after DELETE to verify transaction rollback.
        var handle: OpaquePointer?; sqlite3_open(dbURL.path, &handle)
        sqlite3_exec(handle, "CREATE TRIGGER reject_restore BEFORE INSERT ON dictations BEGIN SELECT RAISE(ABORT,'test'); END;", nil, nil, nil)
        sqlite3_close(handle)
        do {
            try await store.replace(with: .init(records: [record], createdAt: Date(), history: []))
            throw NSError(domain: "ExpectedFailure", code: 1)
        } catch let error as NSError where error.domain == "ExpectedFailure" { throw error }
        catch { }
        let afterFailure = try await store.snapshot()
        try check(afterFailure.history == [entry] && afterFailure.records.isEmpty && afterFailure.createdAt == decoded.statisticsCreatedAt, "Fehlgeschlagener Restore rollt Löschungen vollständig zurück")
        try await store.replace(with: .init(records: [], createdAt: decoded.statisticsCreatedAt, history: []))
        let empty = try await store.snapshot()
        try check(empty.records.isEmpty && empty.history.isEmpty, "Leerer Stand ersetzt vorhandene Daten")
    }
}
