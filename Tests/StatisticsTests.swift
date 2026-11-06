import Foundation
import SQLite3
import Combine

@main
struct StatisticsTests {
    static var count = 0
    static func expect(_ condition: @autoclosure () -> Bool, _ title: String) throws {
        guard condition() else { throw NSError(domain: "StatisticsTests", code: 1, userInfo: [NSLocalizedDescriptionKey: title]) }
        count += 1; print("✓ \(title)")
    }
    static func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Berlin")!; return c
    }
    static func fixture(_ day: String = "2026-10-29", words: Int = 100, raw: Int = 120, duration: Double = 30,
                        processing: Double = 5, status: DictationOutcome = .success, translated: Bool = false,
                        app: String = "TextEdit", error: MetricsStage? = nil) -> DictationRecord {
        .init(id: UUID(), startedAt: date(day + "T10:00:00Z"), day: day, hour: 11, timeZone: "Europe/Berlin",
              appID: "test." + app, appName: app, inputLanguage: "de", outputLanguage: translated ? "en" : "auto",
              translated: translated, cleanupEnabled: false, outcome: status, words: status == .success ? words : 0,
              transcriptWords: status == .success ? raw : 0, recordingSeconds: duration, processingSeconds: processing,
              audioSeconds: processing, correctionSeconds: nil, errorStage: error)
    }
    static func main() async throws {
        let now = date("2026-10-29T12:00:00Z")
        let instant = ContinuousClock.now
        var metrics = DictationMetrics(date: now, instant: instant, calendar: calendar, appID: "test", appName: "TextEdit", route: .init(input: "de", output: "auto"), cleanup: true)
        metrics.stopRecording(at: instant.advanced(by: .seconds(30)))
        metrics.stopRecording(at: instant.advanced(by: .seconds(100)))
        metrics.audioFinished(words: 120, at: instant.advanced(by: .seconds(34)))
        metrics.startCorrection(at: instant.advanced(by: .seconds(34)))
        metrics.endCorrection(failed: false, at: instant.advanced(by: .seconds(36)))
        let successful = metrics.finish(.success, words: 100, at: instant.advanced(by: .seconds(36)))!
        try expect(successful.words == 100 && successful.transcriptWords == 120, "Endtext und unkorrigierte Wortanzahl getrennt")
        try expect(successful.recordingSeconds == 30 && successful.processingSeconds == 6, "Monotone Dauer ohne doppelte Stop-Zählung")
        try expect(successful.audioSeconds == 4 && successful.correctionSeconds == 2, "Verarbeitungsstufen getrennt gemessen")
        try expect(metrics.finish(.success, words: 100) == nil, "Verspäteter/doppelter Abschluss wird ignoriert")
        var cancelled = DictationMetrics(date: now, instant: instant, calendar: calendar, appID: "a", appName: "a", route: .init(input: "auto", output: "auto"), cleanup: false)
        let cancellation = cancelled.finish(.cancelled, words: 900, at: instant.advanced(by: .seconds(5)))!
        try expect(cancellation.words == 0 && cancellation.recordingSeconds == 5 && cancellation.processingSeconds == 0, "Aufnahmeabbruch zählt Dauer aber keine Wörter")
        var failed = DictationMetrics(date: now, instant: instant, calendar: calendar, appID: "a", appName: "a", route: .init(input: "auto", output: "auto"), cleanup: false)
        failed.stopRecording(at: instant.advanced(by: .seconds(10)))
        let failure = failed.finish(.failed, error: .audio, at: instant.advanced(by: .seconds(12)))!
        try expect(failure.words == 0 && failure.audioSeconds == 2 && failure.errorStage == .audio, "Audiofehler mit technischer Kategorie ohne Fehlertext")
        var correctedFailure = DictationMetrics(date: now, instant: instant, calendar: calendar, appID: "a", appName: "a", route: .init(input: "auto", output: "auto"), cleanup: true)
        correctedFailure.stopRecording(at: instant.advanced(by: .seconds(10)))
        correctedFailure.audioFinished(words: 10, at: instant.advanced(by: .seconds(11)))
        correctedFailure.startCorrection(at: instant.advanced(by: .seconds(11)))
        correctedFailure.endCorrection(failed: true, at: instant.advanced(by: .seconds(12)))
        let retained = correctedFailure.finish(.success, words: 10, at: instant.advanced(by: .seconds(12)))!
        try expect(retained.words == 10 && retained.outcome == .success && retained.errorStage == .correction, "Korrekturfehler erhält erfolgreich erzeugten Text")
        var test = DictationMetrics(date: now, instant: instant, calendar: calendar, appID: "a", appName: "a", route: .init(input: "de", output: "auto"), cleanup: false, isTest: true)
        try expect(test.finish(.success, words: 100) == nil, "Testdiktate ausgeschlossen")
        let midnight = DictationMetrics(date: date("2026-10-28T23:30:00Z"), instant: instant, calendar: calendar, appID: "a", appName: "a", route: .init(input: "auto", output: "auto"), cleanup: false)
        var midnightCopy = midnight
        let local = midnightCopy.finish(.success, words: 1)!
        try expect(local.day == "2026-10-29" && local.hour == 0 && local.timeZone == "Europe/Berlin", "Tag, Stunde und Zeitzone beim Start festgehalten")
        try expect(WordCounter.count("Hallo Welt, das sind 42 Wörter!") == 6, "Deutsche Wörter, Zahlen und Satzzeichen")
        try expect(WordCounter.count("Hello, this is a test.") == 5, "Englische Wörter")
        try expect(WordCounter.count("... !? 😀") == 0 && WordCounter.count("") == 0, "Keine Wörter aus Satzzeichen oder Emojis")
        try expect(WordCounter.count("今日は良い天気です") > 1 && WordCounter.count("今天天气很好") > 1, "Wortzählung ohne Leerzeichen")
        let source = [fixture(words: 100, raw: 120, duration: 30), fixture(words: 100, raw: 120, duration: 90), fixture(words: 80, raw: 500, duration: 10, translated: true), fixture(status: .cancelled), fixture(status: .failed, error: .audio)]
        let summary = StatisticsSummary(records: source, period: .week, now: now, calendar: calendar)
        try expect(summary.records.count == 5 && summary.words == 280 && summary.succeeded == 3 && summary.cancelled == 1 && summary.failed == 1, "Ergebnisse und Wörter korrekt aggregiert")
        try expect(summary.wpm == 120, "Tempo nach Dauer gewichtet, Übersetzungen ausgeschlossen")
        try expect(summary.savedSeconds == 275, "Zeitersparnis pro erfolgreichem Diktat berechnet")
        let fasterTyping = StatisticsSummary(records: source, period: .week, typingWPM: 80, now: now, calendar: calendar)
        try expect(fasterTyping.savedSeconds < summary.savedSeconds, "Geändertes Tippvergleichstempo berechnet Historie neu")
        let slow = StatisticsSummary(records: [fixture(words: 1, duration: 100)], period: .all, now: now, calendar: calendar)
        try expect(slow.savedSeconds == 0, "Zeitersparnis wird nie negativ")
        try expect(StatisticsSummary.median([9, 1, 4]) == 4 && StatisticsSummary.median([1, 3]) == 2 && StatisticsSummary.median([]) == nil, "Median mit ungeraden, geraden und fehlenden Werten")
        try expect(summary.days.count == 7 && summary.days.first!.dictations == 0 && summary.days.last!.dictations == 5, "Wochenverlauf enthält Tage ohne Aktivität")
        let streaks = [fixture("2026-10-25"), fixture("2026-10-26"), fixture("2026-10-27"), fixture("2026-10-28"), fixture("2026-10-28")]
        let streak = StatisticsSummary(records: streaks, period: .all, now: now, calendar: calendar)
        try expect(streak.activeDays == 4 && streak.longestStreak == 4 && streak.currentStreak == 4, "Serie bleibt bis gestern aktuell; mehrere Diktate zählen als ein Tag")
        let broken = StatisticsSummary(records: streaks, period: .all, now: date("2026-10-30T12:00:00Z"), calendar: calendar)
        try expect(broken.currentStreak == 0 && broken.longestStreak == 4, "Unterbrochene Serie korrekt")
        let failuresOnly = StatisticsSummary(records: [fixture(status: .failed)], period: .today, now: now, calendar: calendar)
        try expect(failuresOnly.activeDays == 0 && failuresOnly.currentStreak == 0 && failuresOnly.wpm == nil, "Fehler erzeugen keine Nutzungsserie oder Tempo")
        let month = StatisticsSummary(records: [fixture("2026-09-30"), fixture("2026-10-01"), fixture("2026-10-29")], period: .calendarMonth, now: now, calendar: calendar)
        try expect(month.records.count == 2 && month.days.count == 29, "Kalendermonat statt rollierendem 30-Tage-Fenster")
        let dst = StatisticsSummary(records: [fixture("2026-10-24"), fixture("2026-10-25"), fixture("2026-10-26")], period: .week, now: date("2026-10-26T12:00:00Z"), calendar: calendar)
        try expect(dst.days.count == 7 && dst.currentStreak == 3, "Sommerzeitwechsel verschiebt keine Tage oder Serien")
        let historic = StatisticsSummary(records: [fixture("2024-01-01"), fixture()], period: .all, now: now, calendar: calendar)
        try expect(historic.records.count == 2 && historic.days.count <= 367, "Gesamtzahlen vollständig, Diagramm auf zwölf Monate begrenzt")
        let appStats = StatisticsSummary(records: [fixture(words: 30, app: "B"), fixture(words: 50, app: "A"), fixture(words: 40, app: "B")], period: .all, now: now, calendar: calendar)
        try expect(appStats.apps[0].name == "B" && appStats.apps[0].words == 70 && appStats.apps[0].dictations == 2, "Ziel-Apps nach Wörtern sortiert und zusammengeführt")
        try expect(summary.breakdown { $0.translated ? "Übersetzung" : "Transkription" }.count == 2, "Verarbeitungsarten aufgeschlüsselt")
        let csv = StatisticsCSV.export([fixture(app: "=TEST,\"App\"")])
        try expect(csv.contains("\"'=TEST,\"\"App\"\"\"") && csv.hasSuffix("\r\n"), "CSV maskiert Anführungszeichen und Tabellenformeln")
        let encoded = String(data: try JSONEncoder().encode(successful), encoding: .utf8)!
        try expect(!encoded.contains("\"text\"") && !encoded.contains("transcript\"") && !encoded.contains("audioData"), "Gespeichertes Schema enthält keine Text-/Audioinhalte")
        var check = ConnectionCheckRun()
        let old = check.begin(); check.invalidate()
        try expect(!check.accepts(old) && check.completedAt == nil, "Adressänderung verwirft alte Prüfergebnisse sofort")
        let current = check.begin(); check.complete(old, at: now)
        try expect(check.isRunning && check.completedAt == nil, "Verspätete Prüfung kann aktuelle Prüfung nicht abschließen")
        check.complete(current, at: now)
        try expect(!check.isRunning && check.completedAt == now, "Aktuelle Prüfung veröffentlicht Abschlusszeit")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TecWisperStatsTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("stats.sqlite")
        let store = try StatisticsStore(url: url, now: now)
        try await store.insert(successful); try await store.insert(successful)
        let saved = try await store.snapshot()
        try expect(saved.records.count == 1 && saved.records[0] == successful, "SQLite verhindert doppelte Abschlüsse")
        let reopened = try StatisticsStore(url: url)
        let restored = try await reopened.snapshot()
        try expect(restored.records == saved.records && restored.createdAt == now, "SQLite-Neustart erhält Zahlen und Erfassungsbeginn")
        try await store.reset(now: now.addingTimeInterval(1))
        let reset = try await store.snapshot()
        try expect(reset.records.isEmpty && reset.createdAt == now.addingTimeInterval(1), "Zurücksetzen löscht Datensätze und erneuert Beginn atomar")
        let futureURL = directory.appendingPathComponent("future.sqlite")
        var handle: OpaquePointer?; sqlite3_open(futureURL.path, &handle); sqlite3_exec(handle, "PRAGMA user_version=99", nil, nil, nil); sqlite3_close(handle)
        do { _ = try StatisticsStore(url: futureURL); throw NSError(domain: "Test", code: 2) }
        catch StatisticsStorageError.newerSchema { count += 1; print("✓ Neueres Schema wird nicht überschrieben") }
        let blocked = directory.appendingPathComponent("blocked")
        try Data([0]).write(to: blocked)
        do { _ = try StatisticsStore(url: blocked.appendingPathComponent("db")); throw NSError(domain: "Test", code: 3) }
        catch { try expect((error as NSError).domain != "Test", "Speicherfehler wird gemeldet") }
        try await modelTests(directory: directory, now: now, record: successful)
        print("\n\(count) Statistik-Prüfungen erfolgreich.")
    }
    @MainActor static func modelTests(directory: URL, now: Date, record: DictationRecord) async throws {
        let suite = "TecWisperStatsTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = StatisticsModel(url: directory.appendingPathComponent("model.sqlite"), defaults: defaults)
        await model.flush()
        try expect(model.loaded && model.error == nil && model.settings.enabled && model.settings.typingWPM == 40, "Statistik startet aktiviert mit 40 Wörtern/Minute")
        var activeMetrics: DictationMetrics? = .init(appID: "test", appName: "Test", route: .init(input: "de", output: "auto"), cleanup: false)
        model.onDisable = { activeMetrics = nil }
        model.settings.enabled = false
        try expect(activeMetrics == nil, "Deaktivieren verwirft laufende Erfassung")
        model.settings.enabled = true
        try expect(activeMetrics == nil, "Erneutes Aktivieren zählt laufendes Diktat nicht rückwirkend")
        model.record(record); model.reset()
        await model.flush()
        try expect(model.records.isEmpty, "Reset wartet auf vorherige Schreiboperationen")
        model.record(record); await model.flush()
        model.period = .today
        model.refreshTime(now: date("2026-10-29T12:00:00Z"))
        try expect(model.summary().words == record.words, "Tagesanzeige verwendet gemeinsame Modellzeit")
        var updates = 0
        let observation = model.objectWillChange.sink { updates += 1 }
        model.refreshTime(now: date("2026-10-30T12:00:00Z"))
        try expect(updates > 0 && model.summary().words == 0 && model.summary().records.isEmpty,
                   "Tageswechsel veröffentlicht Aktualisierung und setzt Tageswerte ohne Tabwechsel zurück")
        model.period = .all
        try expect(model.summary().words == record.words, "Tageswechsel erhält gespeicherte Gesamtstatistik")
        observation.cancel()
        model.settings.enabled = false
        try expect(model.records.count == 1, "Deaktivieren erhält vorhandene Statistik")
        model.settings.typingWPM = 70
        let loadedSettings = StatisticsSettings(defaults: defaults)
        try expect(!loadedSettings.enabled && loadedSettings.typingWPM == 70, "Statistikeinstellungen bleiben über Neustarts erhalten")
    }
}
