import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let tecWisperBackup = UTType(exportedAs: "de.tekocloud.tecwisper.backup", conformingTo: .json)
}

enum BackupError: LocalizedError {
    case invalid, newer
    var errorDescription: String? {
        switch self {
        case .invalid: return "Diese Datei ist keine gültige vollständige TecWisper-Sicherung. Es wurden keine Daten übernommen."
        case .newer: return "Diese Sicherung benötigt eine neuere TecWisper-Version. Es wurden keine Daten übernommen."
        }
    }
}

struct TecWisperBackup: Codable {
    var format = "TecWisperBackup"
    var formatVersion = 1
    var createdAt = Date()
    var appVersion: String
    var buildNumber: String
    var preferences: Preferences
    var statisticsSettings: StatisticsSettings
    var historyEnabled: Bool
    var statisticsCreatedAt: Date
    var records: [DictationRecord]
    var history: [DictationHistoryEntry]
    var snapshot: StatisticsSnapshot { .init(records: records, createdAt: statisticsCreatedAt, history: history) }

    func validate() throws {
        guard formatVersion <= 1 else { throw BackupError.newer }
        guard format == "TecWisperBackup", formatVersion == 1,
              !appVersion.isEmpty, !buildNumber.isEmpty,
              createdAt.timeIntervalSince1970.isFinite, statisticsCreatedAt.timeIntervalSince1970.isFinite,
              preferences.shortcutError == nil,
              DictationLanguage.all.contains(where: { $0.id == preferences.inputLanguage }),
              DictationLanguage.all.contains(where: { $0.id == preferences.outputLanguage }),
              !preferences.cleanupModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              statisticsSettings.typingWPM.isFinite, statisticsSettings.typingWPM > 0,
              Set(records.map(\.id)).count == records.count,
              Set(history.map(\.id)).count == history.count else { throw BackupError.invalid }
        guard let url = URL(string: preferences.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              ["localhost", "127.0.0.1", "::1", "[::1]"].contains(url.host?.lowercased() ?? ""),
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { throw BackupError.invalid }
        for shortcut in [preferences.holdShortcut, preferences.toggleShortcut].compactMap({ $0 }) {
            guard shortcut.keyCode < 128, shortcut.modifiers & ~UInt32(256 | 512 | 2048 | 4096) == 0 else { throw BackupError.invalid }
        }
        let indexed = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for entry in history {
            if let record = indexed[entry.id], record != entry.record { throw BackupError.invalid }
        }
        for record in records + history.map(\.record) {
            guard record.startedAt.timeIntervalSince1970.isFinite, (0...23).contains(record.hour),
                  validDay(record.day),
                  record.words >= 0, record.transcriptWords >= 0,
                  [record.recordingSeconds, record.processingSeconds].allSatisfy({ $0.isFinite && $0 >= 0 }),
                  [record.audioSeconds, record.correctionSeconds].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 >= 0 }) else { throw BackupError.invalid }
        }
    }
    private func validDay(_ day: String) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        guard let date = StatisticsCalendar.date(day, calendar: calendar) else { return false }
        return StatisticsCalendar.day(date, calendar: calendar) == day
    }
}

enum BackupService {
    static func read(_ url: URL) throws -> TecWisperBackup {
        let data = try Data(contentsOf: url)
        // Check the format version before decoding fields introduced by future formats.
        guard let header = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              header["format"] as? String == "TecWisperBackup",
              let version = header["formatVersion"] as? Int else { throw BackupError.invalid }
        guard version <= 1 else { throw BackupError.newer }
        let backup: TecWisperBackup
        do { backup = try JSONDecoder().decode(TecWisperBackup.self, from: data) }
        catch { throw BackupError.invalid }
        try backup.validate()
        return backup
    }
    static func write(_ backup: TecWisperBackup, to url: URL) throws {
        try backup.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func filename(now: Date = Date()) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "TecWisper-Backup-\(formatter.string(from: now)).tecwisperbackup"
    }
    static func safetyURL() throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("TecWisper/Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return folder.appendingPathComponent("Vor-Restore-\(UUID().uuidString)-\(filename())")
    }
}
