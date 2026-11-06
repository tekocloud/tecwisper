import AppKit
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case backup = "Backup & Restore"
    case home = "Start", activity = "Aktivität", statistics = "Statistiken", dictionary = "Wörterbuch", status = "Systemprüfung", controls = "Bedienung", languages = "Sprache", ollama = "Ollama"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .backup: return "externaldrive.badge.timemachine"
        case .home: return "house"
        case .activity: return "clock.arrow.circlepath"
        case .statistics: return "chart.bar.xaxis"
        case .dictionary: return "character.book.closed"
        case .status: return "checkmark.shield"
        case .controls: return "keyboard"
        case .languages: return "character.bubble"
        case .ollama: return "externaldrive.connected.to.line.below"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    @State private var insertionTestPID: pid_t = 0
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Theme.border).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    switch state.settingsPage ?? .home {
                    case .backup: backupContent
                    case .home: HomeView(state: state, statistics: state.statistics)
                    case .activity: ActivityView(model: state.statistics)
                    case .statistics: StatisticsView(model: state.statistics, reset: state.resetStatistics)
                    case .dictionary: dictionaryContent
                    case .status: statusContent
                    case .controls: controlsContent
                    case .languages: languageContent
                    case .ollama: ollamaContent
                    }
                }.disabled(state.backupBusy).padding(32).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
            }.background(Theme.background).id(state.settingsPage)
        }
        .background(Theme.background)
        .foregroundStyle(Theme.ink)
        .groupBoxStyle(DesktopGroupBoxStyle())
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .frame(minWidth: 940, minHeight: 720)
        .onAppear { state.settingsOpened() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            state.refreshAccessibilityStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in state.checkNow() }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark()
                VStack(alignment: .leading, spacing: 3) {
                    Text("TecWisper").font(.system(size: 15, weight: .semibold))
                    Text("Lokal auf deinem Mac").font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            }.padding(.horizontal, 18).padding(.top, 24).padding(.bottom, 28)
            VStack(spacing: 5) {
                navigation(.home); navigation(.activity); navigation(.statistics); navigation(.dictionary)
                Text("EINSTELLUNGEN").font(.system(size: 9, weight: .semibold)).tracking(1.2)
                    .foregroundStyle(Theme.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 24).padding(.bottom, 8).padding(.leading, 12)
                navigation(.controls); navigation(.languages); navigation(.ollama); navigation(.status); navigation(.backup)
            }.padding(.horizontal, 10)
            Spacer(minLength: 30)
            VStack(alignment: .leading, spacing: 10) {
                HStack { Label("Engine", systemImage: "cpu").font(.caption); Spacer(); EngineBadge(state: state) }
                Text("Ollama · \(state.preferences.audioModel)").font(.system(size: 11, weight: .medium))
                Text("Audio lokal · Korrektur optional").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }.padding(12).background(Theme.panel, in: RoundedRectangle(cornerRadius: 10)).padding(12)
            Text("TECWISPER  \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                .font(.system(size: 9, design: .monospaced)).tracking(1).foregroundStyle(Theme.muted)
                .padding(.horizontal, 24).padding(.bottom, 18)
        }.frame(width: 210).background(Theme.sidebar)
    }
    private func navigation(_ page: SettingsPage) -> some View {
        let selected = state.settingsPage == page
        return Button { state.settingsPage = page } label: {
            HStack(spacing: 11) {
                Image(systemName: page.icon).frame(width: 16)
                Text(page.rawValue)
                Spacer()
            }.font(.system(size: 12, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Theme.link : Theme.ink)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(selected ? Theme.selected : .clear, in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(state.settingsPage == .home ? "Hallo." : (state.settingsPage ?? .home).rawValue)
                    .font(.system(size: 28, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if state.settingsPage == .home { EngineBadge(state: state) }
        }
    }
    private var subtitle: String {
        switch state.settingsPage ?? .home {
        case .backup: return "Alle Einstellungen, Diktate und Statistiken sichern und wiederherstellen."
        case .home: return "Sprich einfach. Dein Text bleibt auf deinem Mac."
        case .activity: return "Was du gesprochen hast und in welcher App du es verwendet hast."
        case .dictionary: return "Deine Begriffe und deine Vorgaben für optimierte Prompts."
        case .statistics: return "So viel wird aus deiner Stimme."
        case .status: return "Alles an einem Ort prüfen, bevor du lossprichst."
        case .controls: return "Dein Diktat beginnt mit deiner Tastenkombination."
        case .languages: return "Sprich natürlich. Wähle die Sprache für deinen Text."
        case .ollama: return "Audio und Text bleiben auf deinem Mac."
        }
    }
    private var backupContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("Vollständige Sicherung") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sichert alle Einstellungen, Tastenkürzel, Mikrofonwahl, Sprachen, Ollama-Konfiguration, Wörterbuch und Prompt-Vorgaben sowie sämtliche gespeicherten Diktattexte und Statistiken.")
                    Button("Backup erstellen …", systemImage: "square.and.arrow.up") { state.exportBackup() }
                        .disabled(!state.canBackup)
                    Text("Die Backup-Datei ist unverschlüsselt und enthält persönliche Diktattexte. Bewahre sie an einem geschützten Ort auf.")
                        .font(.callout).foregroundStyle(Theme.muted)
                }.padding(12)
            }
            GroupBox("Backup wiederherstellen") {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Die Wiederherstellung ersetzt den aktuellen Stand vollständig. Vorher wird automatisch eine Sicherheitssicherung erstellt.")
                    Button("Backup wiederherstellen …", systemImage: "square.and.arrow.down") { state.importBackup() }
                        .disabled(!state.canBackup)
                    Text("Ollama-Modelle und macOS-Berechtigungen werden nicht mitgesichert. Fehlende Modelle oder Mikrofone kannst du nach dem Restore über die Systemprüfung prüfen.")
                        .font(.callout).foregroundStyle(Theme.muted)
                }.padding(12)
            }
            if state.backupBusy { ProgressView("Sicherung wird verarbeitet …") }
            if !state.backupMessage.isEmpty { Text(state.backupMessage).textSelection(.enabled) }
            if let url = state.safetyBackupURL {
                Button("Sicherheitssicherung im Finder zeigen") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        }
    }
    private var dictionaryContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("Aus Gesprochenem einen Prompt erstellen") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Diktate als optimierte Prompts ausgeben", isOn: Binding(
                        get: { state.preferences.optimizesPrompt },
                        set: { state.preferences.promptOptimization = $0 }))
                    Text("Sprich deine Aufgabe frei aus. Das lokale Textmodell formuliert daraus einen fertigen Prompt, den TecWisper in dein Textfeld einfügt. Die beschriebene Aufgabe wird dabei nicht ausgeführt. Dieser Modus ersetzt die normale KI-Korrektur.")
                        .font(.callout).foregroundStyle(Theme.muted)
                    Text("So soll dein Prompt aufgebaut sein").font(.headline)
                    TextEditor(text: Binding(
                        get: { state.preferences.promptInstructions ?? Preferences.defaultPromptInstructions },
                        set: { state.preferences.promptInstructions = $0 }))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden).padding(12).frame(minHeight: 150)
                        .background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
                    Button("Standardvorgaben wiederherstellen") { state.preferences.promptInstructions = nil }
                    Text("Das lokale Textmodell wählst du unter Ollama. Änderungen gelten ab dem nächsten Diktat.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }.padding(8)
            }
        GroupBox("Persönliches Wörterbuch") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Ein Begriff pro Zeile, optional mit Erkennungsvariante → Begriff. Das Wörterbuch wird bei der KI-Korrektur und der Prompt-Erstellung berücksichtigt.")
                    .font(.callout).foregroundStyle(Theme.muted)
                TextEditor(text: $state.preferences.dictionary).font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden).padding(12).frame(minHeight: 300)
                    .background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
                Toggle("KI-Korrektur verwenden", isOn: $state.preferences.cleanupEnabled)
                Text("Das ausgewählte Textmodell findest du unter Ollama.").font(.caption).foregroundStyle(Theme.muted)
            }
        }
        }
    }
    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                if state.allReady {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(Theme.mint)
                } else { BrandMark(size: 40) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.allReady ? "Dein Mac ist bereit" : "Dein Diktierplatz").font(.title3.weight(.semibold))
                    Text(state.allReady ? "Die Voraussetzungen sind erfüllt. Prüfe die echte Verarbeitung mit einem Testdiktat." : "Fehlende Voraussetzungen findest du in der Liste unten.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            HStack {
                Button("Erneut prüfen", systemImage: "arrow.clockwise") { state.checkNow() }
                Spacer()
                Button(state.phase == .recording ? "Testaufnahme beenden" : "Testdiktat", systemImage: "mic.fill") {
                    if state.phase == .recording { state.stop() } else { state.startTest() }
                }.buttonStyle(.borderedProminent).disabled(state.phase.busy && state.phase != .recording)
                if state.phase.busy { Button("Abbrechen") { state.cancel() } }
            }
            VStack(spacing: 0) {
                ForEach(state.checks) { check in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(check.title).font(.headline)
                            Spacer()
                            HStack(spacing: 5) {
                                if check.status == .checking { ProgressView().controlSize(.mini) }
                                else { Image(systemName: check.status == .ready ? "checkmark.circle.fill" : "circle.dashed") }
                                Text(check.status.rawValue)
                            }.font(.caption.weight(.medium)).foregroundStyle(check.status == .ready ? Theme.mint : .secondary)
                        }
                        Text(check.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                        if check.id == "microphone" && check.status != .ready {
                            HStack {
                                Button("Mikrofon erlauben") { state.requestMicrophone() }
                                Button("Systemeinstellungen öffnen") { state.openPrivacy("Privacy_Microphone") }
                            }
                        }
                        if check.id == "accessibility" && check.status != .ready {
                            HStack {
                                Button("Zugriff erlauben") { state.requestAccessibility() }
                                Button("Systemeinstellungen öffnen") { state.openPrivacy("Privacy_Accessibility") }
                            }
                            Button("Laufende App im Finder zeigen") { state.revealRunningApp() }
                            Text(state.runningAppPath).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        if check.id == "accessibility" && check.status == .ready {
                            Picker("Testziel", selection: $insertionTestPID) {
                                Text("Zuletzt aktive App").tag(pid_t(0))
                                ForEach(state.insertionTestApplications, id: \.processIdentifier) { app in
                                    Text(app.localizedName ?? "App").tag(app.processIdentifier)
                                }
                            }
                            Button("Einfügen testen") { state.testInsertion(processID: insertionTestPID) }.disabled(state.phase.busy)
                            Text("Schreibt „TecWisper-Test“ in das aktive Textfeld der gewählten App und aktiviert sie dafür. Öffne für den Test ein leeres Dokument.").font(.caption).foregroundStyle(.secondary)
                        }

                    }.padding(16)
                    if check.id != state.checks.last?.id { Divider().padding(.horizontal, 16) }
                }
            }.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            Text(state.testSummary).font(.caption).foregroundStyle(.secondary)
            resultContent
        }
    }
    private var controlsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 20) {
                    ShortcutRow(title: "Zum Sprechen gedrückt halten", subtitle: "Loslassen beendet die Aufnahme.", shortcut: $state.preferences.holdShortcut, other: state.preferences.toggleShortcut, state: state)
                    Divider()
                    ShortcutRow(title: "Aufnahme starten / stoppen", subtitle: "Einmal drücken zum Starten, erneut zum Beenden.", shortcut: $state.preferences.toggleShortcut, other: state.preferences.holdShortcut, state: state)
                    Divider()
                    HStack { Text("Escape").font(.system(.body, design: .monospaced)); Text("bricht das aktuelle Diktat ab.").foregroundStyle(.secondary) }
                }.padding(12)
            }
            if let error = state.hotKeys.registrationError { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            Button("Standardkürzel wiederherstellen") {
                var preferences = state.preferences
                preferences.holdShortcut = .holdDefault; preferences.toggleShortcut = .toggleDefault
                state.preferences = preferences
            }
            Text("Die Kombinationen gelten in anderen Apps. Reservierte macOS-Kürzel oder zusätzliche Belegungen anderer Apps können Konflikte verursachen.")
                .font(.callout).foregroundStyle(.secondary)
            GroupBox("Mikrofon") {
                Picker("Aufnahmegerät", selection: $state.preferences.microphoneID) {
                    Text("Systemstandard").tag("")
                    ForEach(state.microphones) { Text($0.name).tag($0.id) }
                    if !state.preferences.microphoneID.isEmpty && !state.microphones.contains(where: { $0.id == state.preferences.microphoneID }) {
                        Text("Ausgewähltes Mikrofon nicht verfügbar").tag(state.preferences.microphoneID)
                    }
                }.padding(12)
            }
            Text("Aufnahmen enden spätestens nach fünf Minuten. Danach wird der Text verarbeitet.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var languageContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Eingangssprache", selection: $state.preferences.inputLanguage) { ForEach(DictationLanguage.all) { Text($0.name).tag($0.id) } }
                    Text("Automatisch: Das Modell erkennt die gesprochene Sprache.").font(.callout).foregroundStyle(.secondary)
                    Divider()
                    Picker("Ausgabesprache", selection: $state.preferences.outputLanguage) { ForEach(DictationLanguage.all) { Text($0.name).tag($0.id) } }
                    Text("Automatisch: Die gesprochene Sprache bleibt erhalten. Eine fest gewählte andere Sprache übersetzt dein Diktat.").font(.callout).foregroundStyle(.secondary)
                }.padding(12)
            }
            Label(state.preferences.route.translates ? "Dein Diktat wird in die gewählte Ausgabesprache übersetzt." : "Dein Diktat wird ohne Übersetzung transkribiert.", systemImage: state.preferences.route.translates ? "character.bubble" : "text.quote")
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            Text("Die Auswahl gilt ab dem nächsten Diktat. Ohne KI-Korrektur wird eine wortgetreue Wiedergabe angefordert. Fragen werden als Text ausgegeben, nicht beantwortet.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
    private var ollamaContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox("Lokale Verbindung") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Ollama-Adresse", text: $state.preferences.baseURL).textFieldStyle(.roundedBorder)
                    TextField("Audiomodell (Modellname inklusive Tag)", text: $state.preferences.audioModel)
                        .textFieldStyle(.roundedBorder)
                    if !state.localAudioModels.isEmpty {
                        Picker("Installierte lokale Modelle", selection: $state.preferences.audioModel) {
                            if !state.localAudioModels.contains(where: { $0.name == state.preferences.audioModel }) {
                                Text(state.preferences.audioModel.isEmpty ? "Modellnamen eingeben" : state.preferences.audioModel + " (nicht bestätigt)").tag(state.preferences.audioModel)
                            }
                            ForEach(state.localAudioModels) { Text($0.name).tag($0.name) }
                        }
                    }
                    Text("Wähle ein installiertes Modell oder gib einen eigenen Namen ein. Es muss lokale Audioeingabe über die Ollama-Audioschnittstelle unterstützen. Die Verbindung prüfen bestätigt die Audiofähigkeit; ein Testdiktat prüft die Verarbeitung. Modelle werden nicht automatisch installiert.").font(.caption).foregroundStyle(.secondary)
                    Text("Ollama 0.40.12 oder neuer. Erlaubt sind localhost, 127.0.0.1 und ::1. Keine Anmeldung erforderlich.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Verbindung prüfen") { state.checkNow() }.disabled(state.connectionCheck.isRunning)
                        if state.connectionCheck.isRunning {
                            ProgressView().controlSize(.small)
                            Text("Prüfung läuft …").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(state.connectionChecks) { check in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(check.title).font(.headline)
                                Spacer()
                                Label(check.status.rawValue, systemImage: check.status == .ready ? "checkmark.circle.fill" : check.status == .checking ? "hourglass" : "circle.dashed")
                                    .foregroundStyle(check.status == .ready ? Theme.mint : check.status == .missing || check.status == .unreachable ? .orange : .secondary)
                            }
                            Text(check.detail).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                        }.padding(.vertical, 4)
                    }
                    if let date = state.connectionCheck.completedAt {
                        Text("Letzte abgeschlossene Prüfung: \(date.formatted(date: .numeric, time: .standard))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(12)
            }
            GroupBox("Optionale KI-Korrektur") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Text nach dem Diktat behutsam korrigieren", isOn: $state.preferences.cleanupEnabled)
                    Text("Glättet Grammatik und Satzzeichen und entfernt Füllwörter. Für wortgetreue Ausgabe ausgeschaltet lassen.").font(.callout).foregroundStyle(.secondary)
                    Picker("Lokales Textmodell", selection: $state.preferences.cleanupModel) {
                        if !state.localTextModels.contains(where: { $0.name == state.preferences.cleanupModel }) { Text(state.preferences.cleanupModel + " (nicht bestätigt)").tag(state.preferences.cleanupModel) }
                        ForEach(state.localTextModels) { Text($0.name).tag($0.name) }
                    }.disabled(!state.preferences.usesTextModel)
                    Text("Die Prompt-Erstellung aktivierst du im Wörterbuch. Sie verwendet ebenfalls dieses Textmodell.").font(.caption).foregroundStyle(.secondary)
                    Button("Wörterbuch öffnen") { state.settingsPage = .dictionary }
                }.padding(12)
            }
            Label("Audio wird nur für das aktuelle Diktat zwischengespeichert und danach gelöscht. Diktatverlauf und Statistik bleiben lokal. Den Textverlauf verwaltest du unter Aktivität.", systemImage: "lock.shield")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private var resultContent: some View {
        if !state.message.isEmpty {
            Label(state.message, systemImage: state.phase == .failed ? "exclamationmark.triangle" : "info.circle")
                .font(.callout).foregroundStyle(state.phase == .failed ? Color.orange : .secondary).textSelection(.enabled)
        }
        if !state.result.isEmpty {
            GroupBox("Letztes Ergebnis · nur für diese Sitzung") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(state.result).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    Button("Text kopieren", systemImage: "doc.on.doc") { state.copyResult() }
                }.padding(12)
            }
        }
    }
}

private struct ShortcutRow: View {
    let title: String
    let subtitle: String
    @Binding var shortcut: Shortcut?
    let other: Shortcut?
    @ObservedObject var state: AppState
    @State private var listening = false
    @State private var monitor: Any?
    @State private var error = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button(listening ? "Kombination drücken …" : shortcut?.label ?? "Nicht belegt") {
                    if listening { end() } else { begin() }
                }.buttonStyle(.bordered).disabled(state.phase.busy || (state.recordingShortcut && !listening))
                Button { shortcut = nil; end() } label: { Image(systemName: "xmark.circle") }.help("Tastenkürzel deaktivieren").disabled(listening || shortcut == nil)
            }
            if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.orange) }
            if listening { Text("Drücke eine Kombination mit ⌘, ⌥, ⌃ oder ⇧. Escape bricht die Auswahl ab.").font(.caption).foregroundStyle(Theme.accent) }
        }.onDisappear { end() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in if listening { end() } }
    }
    private func begin() {
        error = ""; listening = true; state.recordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { end(); return nil }
            let candidate = Shortcut(event: event)
            guard candidate.isValid else { error = "Bitte mindestens eine Zusatztaste verwenden."; return nil }
            guard candidate != other else { error = "Diese Kombination ist bereits für die andere Aktion belegt."; return nil }
            shortcut = candidate; end(); return nil
        }
    }
    private func end() {
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        if listening { listening = false; state.recordingShortcut = false }
    }
}
