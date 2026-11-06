import SwiftUI

struct HomeView: View {
    @ObservedObject var state: AppState
    @ObservedObject var statistics: StatisticsModel
    var body: some View {
        let recent = Array(statistics.activityRecords.prefix(4))
        VStack(alignment: .leading, spacing: 20) {
            dictationCard
            TodayCards(model: statistics)
            if !state.result.isEmpty && !statistics.history.contains(where: { $0.text.output == state.result }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Letzter Text").font(.headline)
                        Spacer()
                        Text("Nur diese Sitzung").font(.caption).foregroundStyle(Theme.muted)
                        Button("Kopieren", systemImage: "doc.on.doc") { state.copyResult() }.controlSize(.small)
                    }
                    Text(state.result).font(.system(size: 13)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    if !state.message.isEmpty { Text(state.message).font(.caption).foregroundStyle(Theme.muted) }
                }.desktopCard()
            } else if !state.message.isEmpty {
                Label(state.message, systemImage: "info.circle").font(.callout).foregroundStyle(Theme.muted).desktopCard()
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Zuletzt verwendet").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button("Alle anzeigen", systemImage: "arrow.up.right") { state.settingsPage = .activity }.font(.caption).buttonStyle(.plain).foregroundStyle(Theme.link)
                }
                if statistics.activityRecords.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "clock").font(.title2).foregroundStyle(Theme.muted)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dein nächstes Diktat macht den Anfang.").font(.system(size: 13, weight: .medium))
                            Text("Hier erscheinen dein Diktattext, die Ziel-App und der Zeitpunkt.").font(.caption).foregroundStyle(Theme.muted)
                        }
                    }.padding(.vertical, 18)
                } else {
                    ForEach(recent) { record in
                        ActivityRow(record: record, text: statistics.text(for: record.id), compact: true)
                        if record.id != recent.last?.id { Divider().overlay(Theme.border) }
                    }
                }
                Text("Diktattexte und Ziel-App werden lokal gespeichert. Einstellungen unter Aktivität.").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }.desktopCard()
            HStack(spacing: 12) {
                Label("Erkennung lokal", systemImage: "lock.shield")
                Text("·")
                Text(state.preferences.cleanupEnabled ? "KI-Korrektur an" : "Wortgetreue Transkription")
                Spacer()
                Button("Sprachen wählen") { state.settingsPage = .languages }.buttonStyle(.plain).foregroundStyle(Theme.link)
            }.font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
    }
    private var dictationCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                Text("DIKTIEREN").font(.system(size: 9, weight: .semibold)).tracking(1.7).foregroundStyle(Theme.link)
                Text(state.phase.busy ? state.phase.title : "Deine Stimme.\nDirekt im Text.")
                    .font(.system(size: 27, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                if let shortcut = state.preferences.holdShortcut {
                    HStack(spacing: 7) {
                        Text(shortcut.label).font(.system(size: 11, weight: .medium, design: .monospaced)).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
                        Text("halten und sprechen").font(.system(size: 12))
                    }
                } else if let shortcut = state.preferences.toggleShortcut {
                    Text("\(shortcut.label) startet und beendet dein Diktat.").font(.system(size: 12))
                } else { Text("Starte dein Diktat hier oder richte ein Tastenkürzel ein.").font(.system(size: 12)) }
                HStack(spacing: 14) {
                    Button(state.phase == .recording ? "Aufnahme beenden" : "Frei sprechen", systemImage: state.phase == .recording ? "stop.fill" : "mic.fill") { state.toggle() }
                        .buttonStyle(.borderedProminent).disabled(state.phase.busy && state.phase != .recording)
                    Button("Tastenkürzel ändern") { state.settingsPage = .controls }.buttonStyle(.plain).font(.caption).foregroundStyle(Theme.link)
                }
                Text("Esc bricht ab · Der Cursor bestimmt das Ziel.").font(.system(size: 10)).foregroundStyle(Theme.ink.opacity(0.8))
            }.frame(maxWidth: .infinity, alignment: .leading)
            BrandMark(size: 150).accessibilityHidden(true)
        }.padding(25)
            .background(LinearGradient(colors: [Theme.color(0x12334C), Theme.color(0x062137)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
    }
}
struct TodayCards: View {
    @ObservedObject var model: StatisticsModel
    var body: some View {
        let summary = StatisticsSummary(records: model.records, period: .today, typingWPM: model.settings.typingWPM, now: model.now, createdAt: model.createdAt)
        HStack(spacing: 10) {
            smallCard(summary.words.formatted(), "Wörter heute", "text.alignleft")
            smallCard(time(summary.savedSeconds), "Geschätzt gespart", "hourglass")
            smallCard(summary.wpm.map { "\(Int($0.rounded())) WPM" } ?? "—", "Diktiertempo", "speedometer")
            smallCard(summary.records.count.formatted(), "Diktate heute", "mic")
        }
    }
    private func smallCard(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Theme.link)
                .frame(width: 28, height: 28).background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            Text(value).font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.muted).lineLimit(1)
        }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
    private func time(_ seconds: Double) -> String {
        if seconds < 60 { return seconds == 0 ? "0 Min." : "< 1 Min." }
        if seconds < 3600 { return "\(Int(seconds) / 60) Min." }
        return "\(Int(seconds) / 3600) Std."
    }
}
struct ActivityRow: View {
    let record: DictationRecord
    var text: DictationText? = nil
    var compact = false
    @State private var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: record.outcome == .success ? "text.bubble" : record.outcome == .cancelled ? "xmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(record.outcome == .success ? Theme.link : Theme.muted).frame(width: 30, height: 30)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 7) {
                    if let text {
                        Text(text.original).font(.system(size: 13)).foregroundStyle(Theme.ink)
                            // Native selectable text can render vertically mirrored in macOS lazy rows.
                            .lineLimit(compact && !expanded ? 3 : nil).textSelection(.disabled)
                        if compact { Button(expanded ? "Weniger anzeigen" : "Vollständigen Text anzeigen") { expanded.toggle() }.buttonStyle(.plain).font(.caption).foregroundStyle(Theme.link) }
                    } else {
                        Text(record.outcome == .success ? "Für diesen Eintrag wurde kein Diktattext gespeichert." : record.outcome == .cancelled ? "Diktat abgebrochen" : "Diktat fehlgeschlagen")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Text("Ziel-App: \(record.appName) · \(record.startedAt.formatted(date: .abbreviated, time: .shortened)) · \(record.words) Wörter Ausgabe")
                        .font(.system(size: 10)).foregroundStyle(Theme.muted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if let text {
                    Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text.output, forType: .string) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).foregroundStyle(Theme.link).help("Ausgabetext kopieren")
                }
                Text(record.outcome == .success ? "Erzeugt" : record.outcome == .cancelled ? "Abgebrochen" : "Fehler")
                    .font(.system(size: 10)).foregroundStyle(record.outcome == .success ? Theme.mint : Theme.muted)
            }
            if let text, text.output != text.original {
                DisclosureGroup("Ausgabe nach Übersetzung / KI-Korrektur") {
                    Text(text.output).font(.system(size: 12)).textSelection(.disabled)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                }.font(.caption).foregroundStyle(Theme.muted).padding(.leading, 42)
            }
        }
    }
}
struct ActivityView: View {
    @ObservedObject var model: StatisticsModel
    @State private var confirmDelete = false
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Diktattexte lokal speichern", isOn: $model.historyEnabled)
                Text("Neue Diktate erscheinen mit ursprünglicher Transkription, fertigem Text und Ziel-App. Ausschalten behält den bisherigen Verlauf. Audio wird nicht gespeichert.").font(.caption).foregroundStyle(Theme.muted)
                Button("Diktattexte löschen …", role: .destructive) { confirmDelete = true }.disabled(model.history.isEmpty)
            }.desktopCard()
            if let error = model.error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
            if model.activityRecords.isEmpty {
                ContentUnavailableView("Noch keine Aktivität", systemImage: "clock.arrow.circlepath", description: Text("Deine neuen Diktate erscheinen hier mit Text, Ziel-App und Zeitpunkt."))
            }
            ForEach(model.activityRecords) { record in ActivityRow(record: record, text: model.text(for: record.id)).desktopCard() }
            Text("Nur auf diesem Mac gespeichert. Für frühere Metadaten-Einträge lässt sich der Text nicht nachträglich wiederherstellen.").font(.caption).foregroundStyle(Theme.muted)
        }.alert("Gespeicherte Diktattexte löschen?", isPresented: $confirmDelete) {
            Button("Abbrechen", role: .cancel) {}
            Button("Diktattexte löschen", role: .destructive) { model.clearHistory() }
        } message: { Text("Ursprüngliche Transkriptionen und Ausgabetexte werden gelöscht. Die Nutzungsstatistik bleibt erhalten. Ein laufendes Diktat wird nicht mehr im Textverlauf gespeichert.") }
    }
}
extension View {
    func desktopCard() -> some View {
        self.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
    }
}
