import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case idle, preparing, recording, transcribing, translating, correcting, finished, failed
        var title: String {
            switch self {
            case .idle: return "Bereit für deine Worte"
            case .preparing: return "Voraussetzungen prüfen"
            case .recording: return "Ich höre zu"
            case .transcribing: return "Sprache wird zu Text"
            case .translating: return "Text wird übersetzt"
            case .correcting: return "Text wird geprüft"
            case .finished: return "Text ist bereit"
            case .failed: return "Bitte prüfen"
            }
        }
        var busy: Bool { [.preparing, .recording, .transcribing, .translating, .correcting].contains(self) }
    }
    @Published var settingsPage: SettingsPage? = .home
    @Published var preferences = Preferences.load() {
        didSet {
            preferences.save()
            if oldValue.holdShortcut != preferences.holdShortcut || oldValue.toggleShortcut != preferences.toggleShortcut {
                hotKeys.register(preferences)
            }
            if oldValue != preferences { testSummary = "Einstellungen geändert. Für diese Konfiguration ist noch kein Testdiktat bestätigt." }
            scheduleCheck()
        }
    }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var checks: [CheckItem] = []
    @Published private(set) var models: [OllamaModel] = []
    @Published private(set) var microphones: [Microphone] = []
    @Published private(set) var level: Float = 0
    @Published private(set) var result = ""
    @Published private(set) var message = ""
    @Published private(set) var testSummary = "Noch kein Testdiktat durchgeführt."
    @Published private(set) var backupBusy = false
    @Published private(set) var backupMessage = ""
    @Published private(set) var safetyBackupURL: URL?
    var canBackup: Bool { !phase.busy && !recordingShortcut && !backupBusy }
    @Published var recordingShortcut = false { didSet { hotKeys.suspended = recordingShortcut } }
    let statistics = StatisticsModel()
    private var metrics: DictationMetrics?
    private var captureStatistics = false
    private var captureHistory = false
    private var pendingHistoryText: DictationText?
    private var failureStage: MetricsStage = .recording
    @Published private(set) var connectionCheck = ConnectionCheckRun()
    var connectionChecks: [CheckItem] {
        var ids = ["ollama", "audio"]
        if preferences.usesTextModel { ids.append("cleanup") }
        return ids.map { id in
            checks.first(where: { $0.id == id }) ?? CheckItem(id: id, title: id == "ollama" ? "Ollama-Verbindung / Version" : id == "audio" ? "Audiomodell" : "Textmodell", status: .unchecked, detail: "Noch nicht geprüft.")
        }
    }
    let hotKeys = HotKeys()
    private let recorder = AudioRecorder()
    private let insertion = TextInsertion()
    private var processing: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var target: TextInsertion.Target?
    private var snapshot = Preferences()
    private var isTest = false
    private var holdDown = false
    private var startedByHold = false
    private var generation = UUID()
    private var overlay: OverlayController?
    var localAudioModels: [OllamaModel] { models.filter { $0.isLocal && ($0.capabilities?.contains("audio") ?? true) } }
    var localTextModels: [OllamaModel] { models.filter { $0.isLocal && ($0.capabilities?.contains("completion") ?? true) && !$0.name.hasPrefix("lfm3-audio") } }
    var allReady: Bool { !checks.isEmpty && checks.allSatisfy { $0.status == .ready } }

    init() {
        statistics.onDisable = { [weak self] in
            self?.captureStatistics = false
            if self?.captureHistory == false { self?.metrics = nil }
        }
        statistics.onHistoryDisable = { [weak self] in
            self?.captureHistory = false; self?.pendingHistoryText = nil
            if self?.captureStatistics == false { self?.metrics = nil }
        }
        hotKeys.onHold = { [weak self] pressed in
            guard let self else { return }
            self.holdDown = pressed
            if pressed { if !self.phase.busy { self.start(hold: true) } }
            else if self.startedByHold && self.phase == .recording { self.stop() }
            else if self.startedByHold && self.phase == .preparing { self.cancel() }
        }
        hotKeys.onToggle = { [weak self] in self?.toggle() }
        hotKeys.onEscape = { [weak self] in self?.cancel() }
        hotKeys.register(preferences)
        recorder.onLevel = { [weak self] level in Task { @MainActor in self?.level = level } }
        recorder.onFailure = { [weak self] message in
            Task { @MainActor in
                guard let self, self.phase == .recording else { return }
                self.finishMetrics(.failed, error: .recording)
                self.cancel(); self.fail(message)
            }
        }
        scheduleCheck()
    }
    private func makeBackup() async throws -> TecWisperBackup {
        let data = try await statistics.backupSnapshot()
        return TecWisperBackup(appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                              buildNumber: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                              preferences: preferences, statisticsSettings: statistics.settings, historyEnabled: statistics.historyEnabled,
                              statisticsCreatedAt: data.createdAt, records: data.records, history: data.history)
    }
    func exportBackup() {
        guard canBackup else { return }
        backupBusy = true; statistics.backupLocked = true; backupMessage = ""; hotKeys.suspended = true
        Task {
            defer { statistics.backupLocked = false; backupBusy = false; hotKeys.suspended = recordingShortcut }
            do {
                let backup = try await makeBackup()
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.tecWisperBackup]
                panel.nameFieldStringValue = BackupService.filename()
                panel.title = "Vollständiges Backup speichern"
                guard panel.runModal() == .OK, let url = panel.url else { return }
                try BackupService.write(backup, to: url)
                backupMessage = "Das vollständige Backup wurde gespeichert."
            } catch { backupMessage = "Backup fehlgeschlagen: " + error.localizedDescription }
        }
    }
    func importBackup() {
        guard canBackup else { return }
        backupBusy = true; statistics.backupLocked = true; backupMessage = ""; hotKeys.suspended = true
        Task {
            defer { statistics.backupLocked = false; backupBusy = false; hotKeys.suspended = recordingShortcut }
            do {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.tecWisperBackup]; panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false; panel.title = "Backup wiederherstellen"
                guard panel.runModal() == .OK, let url = panel.url else { return }
                let backup = try BackupService.read(url)
                let alert = NSAlert()
                alert.messageText = "Aktuellen Stand vollständig ersetzen?"
                alert.informativeText = "Sicherung vom \(backup.createdAt.formatted(date: .numeric, time: .standard)) · TecWisper \(backup.appVersion) (\(backup.buildNumber))\n\(backup.history.count) Diktattexte · \(backup.records.count) Statistikdatensätze\n\nAlle aktuellen Einstellungen, Diktattexte und Statistiken werden ersetzt. Vorher wird automatisch eine Sicherheitssicherung erstellt."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Wiederherstellen"); alert.addButton(withTitle: "Abbrechen")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                let current = try await makeBackup()
                let safety = try BackupService.safetyURL()
                try BackupService.write(current, to: safety)
                safetyBackupURL = safety
                try await statistics.restoreSnapshot(backup.snapshot)
                statistics.settings = backup.statisticsSettings
                statistics.historyEnabled = backup.historyEnabled
                preferences = backup.preferences
                hotKeys.register(preferences)
                checkNow()
                backupMessage = "Backup vollständig wiederhergestellt. Der vorherige Stand wurde als Sicherheitssicherung gespeichert."
            } catch { backupMessage = "Wiederherstellung fehlgeschlagen: " + error.localizedDescription }
        }
    }
    func installOverlay() { overlay = OverlayController(state: self) }
    func settingsOpened() { checkNow() }
    func toggle() {
        if phase == .recording { stop() }
        else if !phase.busy && !recordingShortcut { start() }
    }
    func startTest() { if !phase.busy { start(test: true) } }
    func start(test: Bool = false, hold: Bool = false) {
        guard !phase.busy && !recordingShortcut && !backupBusy else { return }
        result = ""; message = ""; level = 0
        isTest = test; startedByHold = hold; snapshot = preferences
        target = test ? nil : insertion.capture()
        generation = UUID(); let run = generation
        let frontmost = NSWorkspace.shared.frontmostApplication
        let destination = target?.application ?? (frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : frontmost)
        let appID = destination?.bundleIdentifier ?? "unknown"
        let appName = destination?.localizedName ?? "Ohne Ziel-App"
        failureStage = .recording
        phase = .preparing; hotKeys.escapeEnabled = true; overlay?.show()
        processing = Task { [weak self] in
            guard let self else { return }
            do {
                guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
                    throw AppError.microphone("Mikrofonzugriff fehlt. Öffne die Einstellungen und erlaube den Zugriff im Bereich Systemprüfung.")
                }
                let client = try OllamaClient(address: snapshot.baseURL)
                let version = try await client.version()
                guard let parsed = SemanticVersion(version), parsed >= .minimum else { throw AppError.version(version) }
                let models = try await client.models()
                guard models.contains(where: { ($0.name == snapshot.audioModel || $0.name == snapshot.audioModel + ":latest") && $0.isLocal }) else { throw AppError.missingModel(snapshot.audioModel) }
                let info = try await client.show(snapshot.audioModel)
                guard info.isLocal, info.capabilities?.contains("audio") == true else { throw AppError.server(400, "Das gewählte Audiomodell muss lokal installiert sein und Audioeingabe unterstützen.") }
                try Task.checkCancellation()
                guard run == generation, !hold || holdDown else { return }
                try recorder.start(microphoneID: snapshot.microphoneID)
                captureStatistics = statistics.settings.enabled && !test
                captureHistory = statistics.historyEnabled && !test
                pendingHistoryText = nil
                if captureStatistics || captureHistory {
                    metrics = DictationMetrics(appID: appID, appName: appName, route: snapshot.route, cleanup: snapshot.usesTextModel)
                }
                phase = .recording
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 300_000_000_000) } catch { return }
                    guard let self, self.generation == run, self.phase == .recording else { return }
                    self.stop()
                }
            } catch is CancellationError { return }
            catch { guard run == generation else { return }; fail(error.localizedDescription) }
        }
    }
    func stop() {
        guard phase == .recording else { return }
        timeoutTask?.cancel(); timeoutTask = nil
        metrics?.stopRecording()
        let audio: Data
        do { audio = try recorder.finish() } catch { fail(error.localizedDescription); return }
        failureStage = .audio
        phase = snapshot.route.translates ? .translating : .transcribing
        let run = generation, settings = snapshot
        processing = Task { [weak self] in
            guard let self else { return }
            do {
                let client = try OllamaClient(address: settings.baseURL)
                let recognized = try await client.recognize(audio: audio, route: settings.route, preserveOriginal: captureHistory && statistics.historyEnabled)
                try Task.checkCancellation(); guard run == generation else { return }
                let transcript = recognized.output
                if captureHistory && statistics.historyEnabled { pendingHistoryText = DictationText(original: recognized.original, output: transcript) }
                metrics?.audioFinished(words: WordCounter.count(transcript))
                result = transcript
                var cleanupFailed = false
                if settings.usesTextModel {
                    phase = .correcting
                    metrics?.startCorrection()
                    do {
                        result = try await client.cleanup(transcript, model: settings.cleanupModel, dictionary: settings.dictionary, promptInstructions: settings.optimizesPrompt ? (settings.promptInstructions ?? Preferences.defaultPromptInstructions) : nil)
                        try Task.checkCancellation()
                        metrics?.endCorrection(failed: false)
                    } catch is CancellationError { throw CancellationError() }
                    catch { metrics?.endCorrection(failed: true); cleanupFailed = true; message = "Die Textverarbeitung ist fehlgeschlagen. Der ursprüngliche Text bleibt verfügbar. \(error.localizedDescription)" }
                }
                try Task.checkCancellation(); guard run == generation else { return }
                // Text generation is complete before an insertion attempt; it is counted once.
                pendingHistoryText?.output = result
                finishMetrics(.success, words: WordCounter.count(result))
                var insertionAttempted = false
                if isTest {
                    testSummary = cleanupFailed ? "Audioverarbeitung erfolgreich; Textverarbeitung fehlgeschlagen." : "Testdiktat erfolgreich: Aufnahme und Modellverarbeitung funktionieren."
                    if !cleanupFailed { message = "Testdiktat erfolgreich. Der Text wird hier angezeigt und nicht in eine andere App eingefügt." }
                } else if !cleanupFailed {
                    let outcome = await insertion.insert(result, into: target)
                    guard run == generation else { return }
                    message = outcome.message
                    insertionAttempted = outcome.attempted
                }
                phase = .finished; hotKeys.escapeEnabled = false; level = 0
                if insertionAttempted { overlay?.hide() }
                else { overlay?.showResult() }
            } catch is CancellationError { return }
            catch { guard run == generation else { return }; fail(error.localizedDescription) }
        }
    }
    func finishMetrics(_ outcome: DictationOutcome, words: Int = 0, error: MetricsStage? = nil) {
        if let record = metrics?.finish(outcome, words: words, error: error) {
            let storeStatistics = captureStatistics && statistics.settings.enabled
            let text = captureHistory && statistics.historyEnabled && outcome == .success ? pendingHistoryText : nil
            if storeStatistics || text != nil { statistics.record(record, text: text, includeStatistics: storeStatistics) }
        }
        metrics = nil; pendingHistoryText = nil; captureStatistics = false; captureHistory = false
    }
    var insertionTestApplications: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
    func testInsertion(processID: pid_t = 0) {
        guard !phase.busy else { return }
        let explicit = processID == 0 ? nil : NSRunningApplication(processIdentifier: processID)
        if processID != 0 && explicit == nil { message = "Die gewählte Test-App wurde beendet."; return }
        let destination = insertion.capture(application: explicit)
        result = "TecWisper-Test"; message = "Einfügen wird geprüft …"
        hotKeys.escapeEnabled = true
        phase = .preparing
        generation = UUID(); let run = generation
        processing = Task { [weak self] in
            guard let self else { return }
            let outcome = await insertion.insert(result, into: destination, activateTarget: explicit != nil)
            guard run == generation else { return }
            message = outcome.message; phase = outcome.attempted ? .finished : .failed
            hotKeys.escapeEnabled = false
            overlay?.showResult()
        }
    }
    func resetStatistics() { captureStatistics = false; if !captureHistory { metrics = nil }; statistics.reset() }
    func cancel() {
        finishMetrics(.cancelled)
        generation = UUID(); processing?.cancel(); processing = nil; timeoutTask?.cancel(); timeoutTask = nil
        recorder.discard(); phase = .idle; level = 0; result = ""; message = "Diktat abgebrochen."
        target = nil; startedByHold = false; hotKeys.escapeEnabled = false; overlay?.hide()
    }
    private func fail(_ detail: String) {
        finishMetrics(.failed, error: failureStage)
        recorder.discard(); timeoutTask?.cancel(); phase = .failed; message = detail; level = 0
        hotKeys.escapeEnabled = false
        if isTest { testSummary = "Testdiktat fehlgeschlagen: \(detail)" }
        overlay?.showResult()
    }
    func dismissOverlay() { overlay?.hide() }
    func copyResult() {
        guard !result.isEmpty else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(result, forType: .string)
    }
    func requestMicrophone() {
        Task {
            _ = await AVCaptureDevice.requestAccess(for: .audio)
            checkNow()
        }
    }
    private var accessibilityCheck: CheckItem {
        let trusted = TextInsertion.isTrusted
        return CheckItem(id: "accessibility", title: "Einfügen in andere Apps", status: trusted ? .ready : .missing,
            detail: trusted ? "Bedienungshilfenzugriff für die laufende App erlaubt." : "macOS gibt der laufenden App noch keinen Zugriff. Ist der Schalter bereits an, entferne den alten TecWisper-Eintrag und füge die hier laufende App neu hinzu. Danach TecWisper gegebenenfalls neu starten.")
    }
    func refreshAccessibilityStatus() {
        guard let index = checks.firstIndex(where: { $0.id == "accessibility" }) else { return }
        let latest = accessibilityCheck
        if checks[index].status != latest.status || checks[index].detail != latest.detail { checks[index] = latest }
    }
    func revealRunningApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    var runningAppPath: String { Bundle.main.bundleURL.path }
    func requestAccessibility() { TextInsertion.requestPermission(); refreshAccessibilityStatus() }
    func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
    private func invalidateConnection() {
        connectionCheck.invalidate()
        for index in checks.indices where ["ollama", "audio", "cleanup"].contains(checks[index].id) {
            checks[index].status = .unchecked; checks[index].detail = "Einstellungen geändert. Erneute Prüfung erforderlich."
        }
    }
    func scheduleCheck() {
        checkTask?.cancel(); invalidateConnection()
        checkTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 350_000_000) } catch { return }
            guard let self else { return }
            let token = connectionCheck.begin()
            await runChecks(token: token)
        }
    }
    func checkNow() {
        checkTask?.cancel()
        let token = connectionCheck.begin()
        checkTask = Task { [weak self] in await self?.runChecks(token: token) }
    }
    private func runChecks(token check: UUID) async {
        guard connectionCheck.accepts(check), !Task.isCancelled else { return }
        defer { if !Task.isCancelled { connectionCheck.complete(check) } }
        let settings = preferences
        microphones = AudioRecorder.microphones
        var rows = [
            CheckItem(id: "ollama", title: "Ollama", status: .checking, detail: "Verbindung und Version werden geprüft."),
            CheckItem(id: "audio", title: "Audiomodell", status: .checking, detail: "\(settings.audioModel) wird geprüft."),
            CheckItem(id: "microphone", title: "Mikrofonzugriff", status: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? .ready : .missing, detail: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized ? "Zugriff erlaubt." : "Mikrofonzugriff für TecWisper erlauben."),
            CheckItem(id: "device", title: "Aufnahmegerät", status: !microphones.isEmpty && (settings.microphoneID.isEmpty || microphones.contains(where: { $0.id == settings.microphoneID })) ? .ready : .missing, detail: microphones.isEmpty ? "Kein Mikrofon gefunden." : "\(microphones.count) Mikrofon(e) gefunden. Auswahl: \(microphones.first(where: { $0.id == settings.microphoneID })?.name ?? "Systemstandard")."),
            accessibilityCheck,
            CheckItem(id: "shortcuts", title: "Tastenkürzel", status: hotKeys.registrationError == nil ? .ready : .missing, detail: hotKeys.registrationError ?? (settings.holdShortcut == nil && settings.toggleShortcut == nil ? "Beide Kürzel deaktiviert. Aufnahme über das Menü möglich." : "Aktivierte Kürzel registriert. Andere Apps können zusätzliche Konflikte verursachen."))
        ]
        if settings.usesTextModel { rows.append(.init(id: "cleanup", title: "KI-Korrektur", status: .checking, detail: "Textmodell wird geprüft.")) }
        checks = rows
        func update(_ id: String, _ status: Readiness, _ detail: String) {
            guard connectionCheck.accepts(check), !Task.isCancelled, let index = checks.firstIndex(where: { $0.id == id }) else { return }
            checks[index].status = status; checks[index].detail = detail
        }
        do {
            let report = try await OllamaConnectionProbe().check(address: settings.baseURL, audioModel: settings.audioModel, cleanupModel: settings.usesTextModel ? settings.cleanupModel : nil)
            try Task.checkCancellation()
            guard connectionCheck.accepts(check) else { return }
            models = report.models
            for item in report.checks {
                if let index = checks.firstIndex(where: { $0.id == item.id }) { checks[index] = item }
            }
        } catch is CancellationError { return }
        catch {
            guard connectionCheck.accepts(check), !Task.isCancelled else { return }
            models = []
            update("ollama", .unreachable, error.localizedDescription)
            update("audio", .unchecked, "Die Prüfung konnte nicht abgeschlossen werden.")
            update("cleanup", .unchecked, "Die Prüfung konnte nicht abgeschlossen werden.")
        }
    }
}
