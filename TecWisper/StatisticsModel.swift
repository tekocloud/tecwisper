import AppKit
import Combine
import UniformTypeIdentifiers

@MainActor
final class StatisticsModel: ObservableObject {
    @Published var settings: StatisticsSettings {
        didSet { settings.save(defaults: defaults); if oldValue.enabled && !settings.enabled { onDisable?() } }
    }
    @Published var historyEnabled: Bool {
        didSet { defaults.set(historyEnabled, forKey: "history.enabled"); if oldValue && !historyEnabled { onHistoryDisable?() } }
    }
    var onDisable: (() -> Void)?
    var onHistoryDisable: (() -> Void)?
    @Published private(set) var history: [DictationHistoryEntry] = []
    private var historyIndex: [UUID: DictationText] = [:]
    var activityRecords: [DictationRecord] {
        var byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for entry in history { byID[entry.id] = entry.record }
        return byID.values.sorted { $0.startedAt > $1.startedAt }
    }
    func text(for id: UUID) -> DictationText? { historyIndex[id] }
    @Published var period: StatisticsPeriod = .week
    @Published private(set) var records: [DictationRecord] = []
    @Published private(set) var createdAt = Date()
    @Published private(set) var error: String?
    @Published private(set) var loaded = false
    private var store: StatisticsStore?
    private let databaseURL: URL?
    private let defaults: UserDefaults
    var backupLocked = false
    private var pending: Task<Void, Never>?
    @Published private(set) var now = Date()
    private var clockSubscriptions = Set<AnyCancellable>()

    func refreshTime(now: Date = Date()) { self.now = now }

    private func observeTime() {
        Timer.publish(every: 1, on: .main, in: .common).autoconnect()
            .sink { [weak self] in self?.refreshTime(now: $0) }
            .store(in: &clockSubscriptions)
        for name in [NSApplication.didBecomeActiveNotification, NSWindow.didBecomeKeyNotification,
                     .NSCalendarDayChanged, .NSSystemTimeZoneDidChange, NSNotification.Name.NSSystemClockDidChange] {
            NotificationCenter.default.publisher(for: name)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refreshTime() }
                .store(in: &clockSubscriptions)
        }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshTime() }
            .store(in: &clockSubscriptions)
    }
    init(url: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults; databaseURL = url; settings = StatisticsSettings(defaults: defaults)
        historyEnabled = defaults.object(forKey: "history.enabled") as? Bool ?? true
        do { store = try StatisticsStore(url: url) }
        catch { store = nil; self.error = error.localizedDescription }
        observeTime()
        reload()
    }
    func summary(now: Date? = nil) -> StatisticsSummary {
        .init(records: records, period: period, typingWPM: settings.typingWPM, now: now ?? self.now, createdAt: createdAt)
    }
    private func enqueue(_ operation: @escaping (StatisticsStore) async throws -> Void) {
        guard let store else { return }
        let previous = pending
        pending = Task { [weak self] in
            await previous?.value
            do {
                try await operation(store)
                let snapshot = try await store.snapshot()
                guard let self else { return }
                records = snapshot.records; history = snapshot.history
                historyIndex = Dictionary(uniqueKeysWithValues: snapshot.history.map { ($0.id, $0.text) })
                createdAt = snapshot.createdAt; error = nil; loaded = true
            } catch { self?.error = error.localizedDescription }
        }
    }
    func reload() {
        if store == nil {
            do { store = try StatisticsStore(url: databaseURL) }
            catch { self.error = error.localizedDescription; return }
        }
        enqueue { _ in }
    }
    func record(_ record: DictationRecord, text: DictationText? = nil, includeStatistics: Bool = true) {
        guard !backupLocked else { return }
        enqueue { try await $0.insert(record, text: text, includeStatistics: includeStatistics) }
    }
    func clearHistory() { guard !backupLocked else { return }; onHistoryDisable?(); enqueue { try await $0.clearHistory() } }
    func reset() { guard !backupLocked else { return }; enqueue { try await $0.reset() } }
    func exportCSV() {
        Task {
            await pending?.value
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.commaSeparatedText]
            panel.nameFieldStringValue = "TecWisper-Statistik.csv"
            panel.title = "Statistik-Metadaten exportieren"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do { try StatisticsCSV.export(records).write(to: url, atomically: true, encoding: .utf8) }
            catch { self.error = "Der CSV-Export konnte nicht gespeichert werden. Prüfe den gewählten Speicherort." }
        }
    }
    func backupSnapshot() async throws -> StatisticsSnapshot {
        await pending?.value
        guard let store else { throw StatisticsStorageError.unavailable }
        return try await store.snapshot()
    }
    func restoreSnapshot(_ snapshot: StatisticsSnapshot) async throws {
        await pending?.value
        guard let store else { throw StatisticsStorageError.unavailable }
        try await store.replace(with: snapshot)
        records = snapshot.records; history = snapshot.history; createdAt = snapshot.createdAt
        historyIndex = Dictionary(uniqueKeysWithValues: snapshot.history.map { ($0.id, $0.text) })
        error = nil; loaded = true
    }
    func flush() async { await pending?.value }
}
