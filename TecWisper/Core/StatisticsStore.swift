import Foundation
import SQLite3

enum StatisticsStorageError: LocalizedError {
    case unavailable, newerSchema, unreadable
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Statistik oder Diktatverlauf konnten nicht gespeichert oder geladen werden. Prüfe freien Speicherplatz und die Zugriffsrechte. Diktieren ist weiterhin möglich."
        case .newerSchema: return "Die Statistik stammt aus einer neueren TecWisper-Version und wird zum Schutz deiner Daten nicht verändert."
        case .unreadable: return "Die Statistikdatei enthält nicht lesbare Daten. Sie wurde nicht zurückgesetzt."
        }
    }
}
struct StatisticsSnapshot { let records: [DictationRecord]; let createdAt: Date; var history: [DictationHistoryEntry] = [] }

actor StatisticsStore {
    private var database: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    init(url: URL? = nil, now: Date = Date()) throws {
        let destination: URL
        if let url { destination = url }
        else {
            destination = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("TecWisper", isDirectory: true).appendingPathComponent("statistics.sqlite")
        }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard sqlite3_open_v2(destination.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if let handle { sqlite3_close(handle) }; throw StatisticsStorageError.unavailable
        }
        database = handle
        do {
            sqlite3_busy_timeout(handle, 3000)
            sqlite3_exec(handle, "PRAGMA secure_delete=ON", nil, nil, nil)
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(handle, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
            let version = sqlite3_step(statement) == SQLITE_ROW ? sqlite3_column_int(statement, 0) : -1
            sqlite3_finalize(statement)
            guard version <= 2 else { throw StatisticsStorageError.newerSchema }
            guard version >= 0 else { throw StatisticsStorageError.unavailable }
            let sql = """
            BEGIN IMMEDIATE;
            CREATE TABLE IF NOT EXISTS dictations (id TEXT PRIMARY KEY NOT NULL, day TEXT NOT NULL, payload BLOB NOT NULL);
            CREATE INDEX IF NOT EXISTS dictation_day ON dictations(day);
            CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY NOT NULL, value REAL NOT NULL);
            INSERT OR IGNORE INTO metadata(key,value) VALUES ('createdAt', \(now.timeIntervalSince1970));
            CREATE TABLE IF NOT EXISTS history (id TEXT PRIMARY KEY NOT NULL, payload BLOB NOT NULL);
            PRAGMA user_version=2;
            COMMIT;
            """
            guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch { sqlite3_close(handle); database = nil; throw error }
    }
    deinit { if let database { sqlite3_close(database) } }
    private func statement(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw StatisticsStorageError.unavailable }
        return statement
    }
    func insert(_ record: DictationRecord, text: DictationText? = nil, includeStatistics: Bool = true) throws {
        guard sqlite3_exec(database, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
        do {
            if includeStatistics {
                let data = try JSONEncoder().encode(record)
                let query = try statement("INSERT OR IGNORE INTO dictations(id,day,payload) VALUES (?,?,?)")
                defer { sqlite3_finalize(query) }
                sqlite3_bind_text(query, 1, record.id.uuidString, -1, transient)
                sqlite3_bind_text(query, 2, record.day, -1, transient)
                let bound = data.withUnsafeBytes { sqlite3_bind_blob(query, 3, $0.baseAddress, Int32(data.count), transient) }
                guard bound == SQLITE_OK, sqlite3_step(query) == SQLITE_DONE else { throw StatisticsStorageError.unavailable }
            }
            if let text {
                let data = try JSONEncoder().encode(DictationHistoryEntry(record: record, text: text))
                let query = try statement("INSERT OR IGNORE INTO history(id,payload) VALUES (?,?)")
                defer { sqlite3_finalize(query) }
                sqlite3_bind_text(query, 1, record.id.uuidString, -1, transient)
                let bound = data.withUnsafeBytes { sqlite3_bind_blob(query, 2, $0.baseAddress, Int32(data.count), transient) }
                guard bound == SQLITE_OK, sqlite3_step(query) == SQLITE_DONE else { throw StatisticsStorageError.unavailable }
            }
            guard sqlite3_exec(database, "COMMIT", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
        } catch { sqlite3_exec(database, "ROLLBACK", nil, nil, nil); throw error }
    }
    func snapshot() throws -> StatisticsSnapshot {
        let query = try statement("SELECT payload FROM dictations ORDER BY day,id")
        defer { sqlite3_finalize(query) }
        var records: [DictationRecord] = []
        var status = sqlite3_step(query)
        while status == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(query, 0) else { throw StatisticsStorageError.unreadable }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(query, 0)))
            guard let record = try? JSONDecoder().decode(DictationRecord.self, from: data) else { throw StatisticsStorageError.unreadable }
            records.append(record); status = sqlite3_step(query)
        }
        guard status == SQLITE_DONE else { throw StatisticsStorageError.unavailable }
        let meta = try statement("SELECT value FROM metadata WHERE key='createdAt'")
        defer { sqlite3_finalize(meta) }
        guard sqlite3_step(meta) == SQLITE_ROW else { throw StatisticsStorageError.unreadable }
        let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(meta, 0))
        let historyQuery = try statement("SELECT payload FROM history")
        defer { sqlite3_finalize(historyQuery) }
        var history: [DictationHistoryEntry] = []
        var historyStatus = sqlite3_step(historyQuery)
        while historyStatus == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(historyQuery, 0) else { throw StatisticsStorageError.unreadable }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(historyQuery, 0)))
            guard let entry = try? JSONDecoder().decode(DictationHistoryEntry.self, from: data) else { throw StatisticsStorageError.unreadable }
            history.append(entry); historyStatus = sqlite3_step(historyQuery)
        }
        guard historyStatus == SQLITE_DONE else { throw StatisticsStorageError.unavailable }
        return .init(records: records, createdAt: createdAt, history: history)
    }
    func replace(with snapshot: StatisticsSnapshot) throws {
        guard sqlite3_exec(database, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
        do {
            guard sqlite3_exec(database, "DELETE FROM dictations; DELETE FROM history;", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
            for record in snapshot.records {
                try writeBackupRow(table: "dictations", id: record.id, day: record.day, data: JSONEncoder().encode(record))
            }
            for entry in snapshot.history {
                try writeBackupRow(table: "history", id: entry.id, day: nil, data: JSONEncoder().encode(entry))
            }
            let query = try statement("UPDATE metadata SET value=? WHERE key='createdAt'")
            defer { sqlite3_finalize(query) }
            sqlite3_bind_double(query, 1, snapshot.createdAt.timeIntervalSince1970)
            guard sqlite3_step(query) == SQLITE_DONE, sqlite3_exec(database, "COMMIT", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
        } catch { sqlite3_exec(database, "ROLLBACK", nil, nil, nil); throw error }
    }
    private func writeBackupRow(table: String, id: UUID, day: String?, data: Data) throws {
        let query = try statement(day == nil ? "INSERT INTO history(id,payload) VALUES (?,?)" : "INSERT INTO dictations(id,day,payload) VALUES (?,?,?)")
        defer { sqlite3_finalize(query) }
        sqlite3_bind_text(query, 1, id.uuidString, -1, transient)
        if let day { sqlite3_bind_text(query, 2, day, -1, transient) }
        let bound = data.withUnsafeBytes { sqlite3_bind_blob(query, day == nil ? 2 : 3, $0.baseAddress, Int32(data.count), transient) }
        guard bound == SQLITE_OK, sqlite3_step(query) == SQLITE_DONE else { throw StatisticsStorageError.unavailable }
    }
    func clearHistory() throws {
        guard sqlite3_exec(database, "DELETE FROM history", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
    }
    func reset(now: Date = Date()) throws {
        guard sqlite3_exec(database, "BEGIN IMMEDIATE", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
        do {
            guard sqlite3_exec(database, "DELETE FROM dictations", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
            let query = try statement("UPDATE metadata SET value=? WHERE key='createdAt'")
            defer { sqlite3_finalize(query) }
            sqlite3_bind_double(query, 1, now.timeIntervalSince1970)
            guard sqlite3_step(query) == SQLITE_DONE, sqlite3_exec(database, "COMMIT", nil, nil, nil) == SQLITE_OK else { throw StatisticsStorageError.unavailable }
        } catch { sqlite3_exec(database, "ROLLBACK", nil, nil, nil); throw error }
    }
}
