import SwiftUI

struct QuickPanelView: View {
    @ObservedObject var state: AppState
    @ObservedObject var statistics: StatisticsModel
    let open: (SettingsPage) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                BrandMark(size: 29)
                VStack(alignment: .leading, spacing: 3) {
                    Text("TecWisper").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    Text("Ollama · \(state.preferences.audioModel)").font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
                Spacer()
                EngineBadge(state: state)
            }
            Button {
                dismiss()
                state.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: state.phase == .recording ? "stop.fill" : "mic.fill")
                        .frame(width: 30, height: 30).background(.white.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.phase == .recording ? "Aufnahme beenden" : "Frei sprechen").font(.system(size: 13, weight: .semibold))
                        Text(state.preferences.holdShortcut.map { "oder \($0.label) halten" } ?? "Diktat starten")
                            .font(.system(size: 10)).opacity(0.8)
                    }
                    Spacer()
                }.padding(12).frame(maxWidth: .infinity).foregroundStyle(.white)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).disabled(state.phase.busy && state.phase != .recording)
            if state.phase.busy && state.phase != .recording {
                HStack { ProgressView().controlSize(.mini); Text(state.phase.title).font(.caption); Spacer(); Button("Abbrechen") { state.cancel() }.controlSize(.small) }
            }
            Toggle("KI-Korrektur", isOn: $state.preferences.cleanupEnabled).toggleStyle(.switch).controlSize(.mini).font(.system(size: 11))
            HStack {
                Text("Eingang").foregroundStyle(Theme.muted)
                Spacer()
                Picker("Eingang", selection: $state.preferences.inputLanguage) { ForEach(DictationLanguage.all) { Text($0.name).tag($0.id) } }.labelsHidden().frame(width: 155)
            }.font(.system(size: 11))
            HStack {
                Text("Ausgabe").foregroundStyle(Theme.muted)
                Spacer()
                Picker("Ausgabe", selection: $state.preferences.outputLanguage) { ForEach(DictationLanguage.all) { Text($0.name).tag($0.id) } }.labelsHidden().frame(width: 155)
            }.font(.system(size: 11))
            Divider().overlay(Theme.border)
            Text("ZULETZT").font(.system(size: 9, weight: .medium)).tracking(1.2).foregroundStyle(Theme.muted)
            if !state.result.isEmpty {
                Button { state.copyResult() } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(state.result).font(.system(size: 12)).lineLimit(4).foregroundStyle(Theme.ink)
                        Text("Klicken zum Kopieren · nur diese Sitzung").font(.system(size: 9)).foregroundStyle(Theme.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            } else {
                Text("Dein nächstes Diktat erscheint hier.").font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.vertical, 5)
            }
            if !statistics.records.isEmpty {
                ForEach(Array(statistics.records.sorted { $0.startedAt > $1.startedAt }.prefix(2))) { record in
                    HStack {
                        Text(record.appName)
                        Spacer()
                        Text("\(record.words) Wörter")
                    }.font(.system(size: 10)).foregroundStyle(Theme.muted)
                }
            }
            Divider().overlay(Theme.border)
            HStack(spacing: 12) {
                Button { go(.home) } label: { Label("TecWisper öffnen", systemImage: "macwindow").font(.system(size: 11, weight: .medium)) }
                    .buttonStyle(.plain)
                Spacer()
                Button { go(.controls) } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).help("Einstellungen öffnen")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.buttonStyle(.plain).help("TecWisper beenden")
            }.foregroundStyle(Theme.ink)
        }.disabled(state.backupBusy).padding(16).frame(width: 350)
            .background(Theme.background).foregroundStyle(Theme.ink).tint(Theme.accent)
            .preferredColorScheme(.dark)
    }
    private func go(_ page: SettingsPage) { dismiss(); open(page) }
}
