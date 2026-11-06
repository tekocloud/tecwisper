import Foundation
import NaturalLanguage

struct StatisticsSettings: Codable, Equatable {
    var enabled: Bool
    var typingWPM: Double
    init(defaults: UserDefaults = .standard) {
        enabled = defaults.object(forKey: "statistics.enabled") as? Bool ?? true
        let speed = defaults.double(forKey: "statistics.typingWPM")
        typingWPM = speed.isFinite && speed > 0 ? speed : 40
    }
    func save(defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: "statistics.enabled")
        defaults.set(typingWPM, forKey: "statistics.typingWPM")
    }
}

enum WordCounter {
    static func count(_ text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            if text[range].unicodeScalars.contains(where: { CharacterSet.alphanumerics.contains($0) }) { count += 1 }
            return true
        }
        return count
    }
}

enum DictationOutcome: String, Codable { case success, cancelled, failed }
enum MetricsStage: String, Codable, CaseIterable {
    case recording, audio, correction
    var title: String {
        switch self { case .recording: return "Aufnahme / Konvertierung"; case .audio: return "Audioverarbeitung"; case .correction: return "KI-Korrektur" }
    }
}
struct DictationRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var startedAt: Date
    var day: String
    var hour: Int
    var timeZone: String
    var appID: String
    var appName: String
    var inputLanguage: String
    var outputLanguage: String
    var translated: Bool
    var cleanupEnabled: Bool
    var outcome: DictationOutcome
    var words: Int
    var transcriptWords: Int
    var recordingSeconds: Double
    var processingSeconds: Double
    var audioSeconds: Double?
    var correctionSeconds: Double?
    var errorStage: MetricsStage?
}

enum StatisticsCalendar {
    static func day(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func date(_ day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// Tracks numeric metadata only. Finalization is idempotent; test sessions are excluded.
struct DictationMetrics {
    private var record: DictationRecord
    private let began: ContinuousClock.Instant
    private var recordingEnded: ContinuousClock.Instant?
    private var audioEnded: ContinuousClock.Instant?
    private var correctionBegan: ContinuousClock.Instant?
    private var finalized = false
    private let excluded: Bool
    init(id: UUID = UUID(), date: Date = Date(), instant: ContinuousClock.Instant = .now,
         calendar: Calendar = .current, appID: String, appName: String,
         route: LanguageRoute, cleanup: Bool, isTest: Bool = false) {
        began = instant; excluded = isTest
        record = .init(id: id, startedAt: date, day: StatisticsCalendar.day(date, calendar: calendar),
                       hour: calendar.component(.hour, from: date), timeZone: calendar.timeZone.identifier,
                       appID: appID, appName: appName, inputLanguage: route.input, outputLanguage: route.output,
                       translated: route.translates, cleanupEnabled: cleanup, outcome: .failed, words: 0,
                       transcriptWords: 0, recordingSeconds: 0, processingSeconds: 0,
                       audioSeconds: nil, correctionSeconds: nil, errorStage: nil)
    }
    static func seconds(_ from: ContinuousClock.Instant, _ to: ContinuousClock.Instant) -> Double {
        let c = from.duration(to: to).components
        return max(0, Double(c.seconds) + Double(c.attoseconds) / 1e18)
    }
    mutating func stopRecording(at instant: ContinuousClock.Instant = .now) {
        guard recordingEnded == nil, !finalized else { return }
        recordingEnded = instant; record.recordingSeconds = Self.seconds(began, instant)
    }
    mutating func audioFinished(words: Int, at instant: ContinuousClock.Instant = .now) {
        guard !finalized else { return }
        audioEnded = instant
        record.transcriptWords = max(0, words)
        if let recordingEnded { record.audioSeconds = Self.seconds(recordingEnded, instant) }
    }
    mutating func startCorrection(at instant: ContinuousClock.Instant = .now) { if !finalized { correctionBegan = instant } }
    mutating func endCorrection(failed: Bool, at instant: ContinuousClock.Instant = .now) {
        guard !finalized else { return }
        if let correctionBegan { record.correctionSeconds = Self.seconds(correctionBegan, instant) }
        if failed { record.errorStage = .correction }
    }
    mutating func finish(_ outcome: DictationOutcome, words: Int = 0, error: MetricsStage? = nil,
                         at instant: ContinuousClock.Instant = .now) -> DictationRecord? {
        guard !finalized else { return nil }
        if recordingEnded == nil { stopRecording(at: instant) }
        if let recordingEnded { record.processingSeconds = Self.seconds(recordingEnded, instant) }
        if let correctionBegan, record.correctionSeconds == nil { record.correctionSeconds = Self.seconds(correctionBegan, instant) }
        else if audioEnded == nil, let recordingEnded, error == .audio { record.audioSeconds = Self.seconds(recordingEnded, instant) }
        record.outcome = outcome
        record.words = outcome == .success ? max(0, words) : 0
        if outcome != .success { record.transcriptWords = 0 }
        if let error { record.errorStage = error }
        finalized = true
        return excluded ? nil : record
    }
}

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case today = "Heute", week = "Letzte 7 Tage", month = "Letzte 30 Tage", calendarMonth = "Dieser Monat", all = "Insgesamt"
    var id: String { rawValue }
    func start(now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .today: return today
        case .week: return calendar.date(byAdding: .day, value: -6, to: today)!
        case .month: return calendar.date(byAdding: .day, value: -29, to: today)!
        case .calendarMonth: return calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        case .all: return nil
        }
    }
}
struct DailyStatistics: Identifiable { var id: String { day }; let day: String; let date: Date; var words = 0; var dictations = 0 }
struct AppStatistics: Identifiable { let id: String; let name: String; let words: Int; let dictations: Int }
struct StatisticsBreakdown: Identifiable { let id: String; let count: Int; let words: Int }

struct StatisticsSummary {
    let records: [DictationRecord]
    let days: [DailyStatistics]
    let apps: [AppStatistics]
    let activeDays: Int
    let currentStreak: Int
    let longestStreak: Int
    let recordingSeconds: Double
    let savedSeconds: Double
    let words: Int
    let wpm: Double?
    var succeeded: Int { records.filter { $0.outcome == .success }.count }
    var cancelled: Int { records.filter { $0.outcome == .cancelled }.count }
    var failed: Int { records.filter { $0.outcome == .failed }.count }
    var averageLength: Double? { records.isEmpty ? nil : recordingSeconds / Double(records.count) }
    var audioMedian: Double? { Self.median(records.compactMap(\.audioSeconds)) }
    var correctionMedian: Double? { Self.median(records.compactMap(\.correctionSeconds)) }
    static func median(_ values: [Double]) -> Double? {
        let sorted = values.filter { $0.isFinite && $0 >= 0 }.sorted()
        guard !sorted.isEmpty else { return nil }
        return sorted.count % 2 == 1 ? sorted[sorted.count / 2] : (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
    }
    func breakdown(_ key: (DictationRecord) -> String) -> [StatisticsBreakdown] {
        Dictionary(grouping: records, by: key).map { .init(id: $0.key, count: $0.value.count, words: $0.value.reduce(0) { $0 + $1.words }) }
            .sorted { $0.words == $1.words ? $0.id < $1.id : $0.words > $1.words }
    }
    init(records source: [DictationRecord], period: StatisticsPeriod, typingWPM: Double = 40,
         now: Date = Date(), calendar: Calendar = .current, createdAt: Date = Date()) {
        let today = calendar.startOfDay(for: now)
        let todayKey = StatisticsCalendar.day(today, calendar: calendar)
        let start = period.start(now: now, calendar: calendar)
        let startKey = start.map { StatisticsCalendar.day($0, calendar: calendar) }
        let filtered = source.filter { $0.day <= todayKey && (startKey == nil || $0.day >= startKey!) }
        records = filtered
        words = filtered.reduce(0) { $0 + $1.words }
        recordingSeconds = filtered.reduce(0) { $0 + $1.recordingSeconds }
        let speed = typingWPM.isFinite && typingWPM > 0 ? typingWPM : 40
        savedSeconds = filtered.filter { $0.outcome == .success }.reduce(0) {
            $0 + max(0, Double($1.words) / speed * 60 - $1.recordingSeconds - $1.processingSeconds)
        }
        let speech = filtered.filter { $0.outcome == .success && !$0.translated && $0.recordingSeconds > 0 && $0.transcriptWords > 0 }
        let duration = speech.reduce(0) { $0 + $1.recordingSeconds }
        wpm = duration > 0 ? Double(speech.reduce(0) { $0 + $1.transcriptWords }) / duration * 60 : nil
        apps = Dictionary(grouping: filtered, by: \.appID).map { id, rows in
            .init(id: id, name: rows.last!.appName, words: rows.reduce(0) { $0 + $1.words }, dictations: rows.count)
        }.sorted { $0.words == $1.words ? $0.name < $1.name : $0.words > $1.words }
        let active = Set(filtered.filter { $0.outcome == .success }.map(\.day))
        activeDays = active.count
        var longest = 0, streak = 0, previous: Date?
        for key in active.sorted() {
            guard let date = StatisticsCalendar.date(key, calendar: calendar) else { continue }
            if let previous, calendar.dateComponents([.day], from: previous, to: date).day == 1 { streak += 1 } else { streak = 1 }
            longest = max(longest, streak); previous = date
        }
        longestStreak = longest
        var cursor = today
        if !active.contains(todayKey) { cursor = calendar.date(byAdding: .day, value: -1, to: today)! }
        var current = 0
        while active.contains(StatisticsCalendar.day(cursor, calendar: calendar)) {
            current += 1; cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        currentStreak = current
        let yearStart = calendar.date(byAdding: .year, value: -1, to: today)!
        let earliest = source.map(\.day).min().flatMap { StatisticsCalendar.date($0, calendar: calendar) } ?? calendar.startOfDay(for: createdAt)
        let graphStart = max(yearStart, start ?? min(earliest, today))
        let grouped = Dictionary(grouping: filtered, by: \.day)
        var daily: [DailyStatistics] = []; cursor = graphStart
        while cursor <= today {
            let key = StatisticsCalendar.day(cursor, calendar: calendar)
            let rows = grouped[key] ?? []
            daily.append(.init(day: key, date: cursor, words: rows.reduce(0) { $0 + $1.words }, dictations: rows.count))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        days = daily
    }
}

enum StatisticsCSV {
    static func export(_ records: [DictationRecord]) -> String {
        func field(_ text: String) -> String {
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(String(text.prefix(1))) ? "'" + text : text
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let formatter = ISO8601DateFormatter()
        let header = "ID,Start UTC,Lokaler Tag,Lokale Stunde,Zeitzone,App-ID,App,Eingang,Ausgang,Übersetzung,KI-Korrektur,Ergebnis,Wörter,Transkriptwörter,Aufnahme Sekunden,Verarbeitung Sekunden,Audio Sekunden,Korrektur Sekunden,Fehlerstufe"
        let lines = records.map { r in
            [r.id.uuidString, formatter.string(from: r.startedAt), r.day, String(r.hour), r.timeZone, r.appID, r.appName,
             r.inputLanguage, r.outputLanguage, String(r.translated), String(r.cleanupEnabled), r.outcome.rawValue,
             String(r.words), String(r.transcriptWords), String(r.recordingSeconds), String(r.processingSeconds),
             r.audioSeconds.map { String($0) } ?? "", r.correctionSeconds.map { String($0) } ?? "", r.errorStage?.rawValue ?? ""].map(field).joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\r\n") + "\r\n"
    }
}
