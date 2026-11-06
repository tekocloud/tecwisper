import SwiftUI
import Charts

struct StatisticsView: View {
    @ObservedObject var model: StatisticsModel
    let reset: () -> Void
    @State private var showAllApps = false
    @State private var chartWords = true
    @State private var confirmReset = false
    private var summary: StatisticsSummary { model.summary() }
    var body: some View {
        let data = summary
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Picker("Zeitraum", selection: $model.period) {
                    ForEach(StatisticsPeriod.allCases) { Text($0.rawValue).tag($0) }
                }.frame(maxWidth: 330)
                Spacer()
                Button("CSV exportieren", systemImage: "square.and.arrow.up") { model.exportCSV() }.help("Exportiert alle gespeicherten Statistik-Metadaten, unabhängig vom gewählten Zeitraum.").disabled(!model.loaded || model.error != nil)
            }
            if let error = model.error {
                VStack(alignment: .leading, spacing: 8) {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    Button("Erneut laden") { model.reload() }
                }.padding().background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
            if !model.settings.enabled {
                Label("Aufzeichnung pausiert. Bisherige Statistiken bleiben erhalten.", systemImage: "pause.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if !model.loaded && model.error == nil { ProgressView("Statistik wird geladen …") }
            if model.loaded && model.records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) { BrandMark(size: 25); Text("Deine Statistik beginnt mit dem nächsten Diktat") }
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("Normale Diktate zählen automatisch. Testdiktate sind ausgeschlossen; frühere Diktate lassen sich nicht nachträglich erfassen.")
                        .font(.callout).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Theme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            } else if model.loaded && data.records.isEmpty {
                Text("In diesem Zeitraum gibt es noch keine Diktate.").foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                tile("Diktate", value: data.records.count.formatted(), note: "Echte Aufnahmen, inklusive Abbruch und Fehler", symbol: "mic")
                tile("Erzeugte Wörter", value: data.words.formatted(), note: "Text nach Übersetzung und optionaler Korrektur", symbol: "text.alignleft")
                tile("Aufnahmedauer", value: duration(data.recordingSeconds), note: "Inklusive Sprechpausen", symbol: "waveform")
                tile("Geschätzt gespart", value: duration(data.savedSeconds), note: "Gegenüber Tippen mit \(model.settings.typingWPM.formatted()) Wörtern/Min.", symbol: "clock")
            }
            GroupBox("Im gewählten Zeitraum") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 14) {
                    valueRow("Erfolgreich", data.succeeded.formatted())
                    valueRow("Abgebrochen", data.cancelled.formatted())
                    valueRow("Fehlgeschlagen", data.failed.formatted())
                    valueRow("Ø Diktatlänge", data.averageLength.map(duration) ?? "—")
                    valueRow("Diktiertempo", data.wpm.map { "\($0.formatted(.number.precision(.fractionLength(0)))) Wörter/Min." } ?? "—")
                    valueRow("Aktive Tage", data.activeDays.formatted())
                    valueRow("Aktuelle Serie", "\(data.currentStreak) Tage")
                    valueRow("Längste Serie", "\(data.longestStreak) Tage")
                }.padding(12)
                Text("Tempo: unkorrigierte Transkripte je Aufnahmeminute, nach Aufnahmedauer gewichtet. Übersetzungen zählen nicht zum Tempo. Serien beziehen sich auf den gewählten Zeitraum; gestern gilt noch als aktuell.")
                    .font(.caption).foregroundStyle(.secondary).padding([.horizontal, .bottom], 12)
            }
            chart(data)
            activity(data)
            apps(data)
            breakdowns(data)
            technical(data)
            settings
            if model.loaded {
                Text("Erfassung seit \(model.createdAt.formatted(date: .abbreviated, time: .shortened)). Tageszuordnung in der beim Diktat gültigen lokalen Zeitzone. Keine Diktattexte, Audiodaten oder Webseitenadressen in der Statistik.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .alert("Statistik vollständig zurücksetzen?", isPresented: $confirmReset) {
            Button("Abbrechen", role: .cancel) { }
            Button("Statistik löschen", role: .destructive, action: reset)
        } message: {
            Text("Alle bisher erfassten Statistikdaten werden gelöscht. Auch das laufende Diktat wird nicht mehr gezählt. Dein separat gespeicherter Textverlauf und sonstige Einstellungen bleiben erhalten.")
        }
    }
    private func tile(_ title: String, value: String, note: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.callout).foregroundStyle(.secondary)
            Text(value).font(.system(size: 30, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
            Text(note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(18).frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(Theme.accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 14))
    }
    private func valueRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.body, design: .rounded, weight: .semibold))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func chart(_ data: StatisticsSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Dein Tagesverlauf").font(.headline)
                    Spacer()
                    Picker("Diagramm", selection: $chartWords) {
                        Text("Wörter").tag(true); Text("Diktate").tag(false)
                    }.labelsHidden().pickerStyle(.segmented).frame(width: 180)
                }
                Chart(data.days) { day in
                    BarMark(x: .value("Tag", day.date, unit: .day), y: .value(chartWords ? "Wörter" : "Diktate", chartWords ? day.words : day.dictations))
                        .foregroundStyle(Theme.accent)
                        .accessibilityLabel(day.day)
                        .accessibilityValue("\(chartWords ? day.words : day.dictations) \(chartWords ? "Wörter" : "Diktate")")
                }
                .chartYScale(domain: 0...max(1, data.days.map { chartWords ? $0.words : $0.dictations }.max() ?? 1))
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in AxisGridLine(); AxisValueLabel(format: .dateTime.day().month(.abbreviated)) } }
                .frame(height: 180)
                if model.period == .all { Text("Diagramm und Kalender zeigen höchstens die letzten zwölf Monate. Kennzahlen oben gelten für die gesamte Nutzung.").font(.caption).foregroundStyle(.secondary) }
            }.padding(12)
        }
    }
    private func activity(_ data: StatisticsSummary) -> some View {
        let offset = data.days.first.map { (Calendar.current.component(.weekday, from: $0.date) + 5) % 7 } ?? 0
        let peak = max(1, data.days.map(\.words).max() ?? 1)
        return GroupBox("Aktivitätskalender") {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal) {
                    LazyHGrid(rows: Array(repeating: GridItem(.fixed(11), spacing: 3), count: 7), spacing: 3) {
                        ForEach(0..<(offset + data.days.count), id: \.self) { index in
                            if index < offset { Color.clear.frame(width: 11, height: 11) }
                            else {
                                let day = data.days[index - offset]
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(day.words == 0 ? Theme.accent.opacity(0.10) : Theme.accent.opacity(0.25 + 0.75 * Double(day.words) / Double(peak)))
                                    .frame(width: 11, height: 11)
                                    .help("\(day.day): \(day.words) Wörter · \(day.dictations) Diktate")
                                    .accessibilityLabel("\(day.day): \(day.words) Wörter, \(day.dictations) Diktate")
                            }
                        }
                    }.padding(.vertical, 4)
                }
                Text("Jede Spalte ist eine Woche, Montag oben. Dunklere Felder bedeuten mehr erzeugte Wörter. Bewege den Zeiger auf einen Tag für die Zahlen.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }
    private func apps(_ data: StatisticsSummary) -> some View {
        GroupBox("Deine Ziel-Apps") {
            VStack(alignment: .leading, spacing: 14) {
                if data.apps.isEmpty { Text("Noch keine Ziel-Apps erfasst.").foregroundStyle(.secondary) }
                ForEach(Array(showAllApps ? data.apps : Array(data.apps.prefix(5)))) { app in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(app.name).font(.headline).help(app.id)
                            Spacer()
                            Text("\(app.words.formatted()) Wörter · \(app.dictations) Diktate").font(.caption)
                        }
                        ProgressView(value: Double(app.words), total: Double(max(1, data.words))).tint(Theme.accent)
                        Text(data.words == 0 ? "0 % der Wörter" : "\((Double(app.words) / Double(data.words)).formatted(.percent.precision(.fractionLength(1)))) der Wörter")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if data.apps.count > 5 { Button(showAllApps ? "Weniger anzeigen" : "Alle \(data.apps.count) Apps anzeigen") { showAllApps.toggle() } }
                Text("Ziel-App beim Start des Diktats. Eine Zuordnung bestätigt nicht, dass die App den Text eingefügt hat.").font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }
    private func languageName(_ id: String) -> String { DictationLanguage.all.first { $0.id == id }?.name ?? id }
    private func breakdowns(_ data: StatisticsSummary) -> some View {
        GroupBox("Sprachen und Verarbeitung") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(data.breakdown { "\(languageName($0.inputLanguage)) → \(languageName($0.outputLanguage))" }) { item in
                    HStack { Text(item.id); Spacer(); Text("\(item.count) Diktate · \(item.words) Wörter").foregroundStyle(.secondary) }.font(.callout)
                }
                Divider()
                valueRow("Transkription / Übersetzung", "\(data.records.filter { !$0.translated }.count) / \(data.records.filter(\.translated).count) Diktate")
                valueRow("KI-Korrektur aktiviert", "\(data.records.filter(\.cleanupEnabled).count) Diktate")
                Text("Automatisch beschreibt deine gewählte Einstellung. Eine erkannte Sprache wird nicht nachträglich angenommen.").font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }
    private func technical(_ data: StatisticsSummary) -> some View {
        GroupBox("Verarbeitung auf deinem Mac") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    valueRow("Audioverarbeitung · Median", data.audioMedian.map { seconds($0) } ?? "—")
                    valueRow("KI-Korrektur · Median", data.correctionMedian.map { seconds($0) } ?? "—")
                }
                Divider()
                ForEach(MetricsStage.allCases, id: \.self) { stage in
                    HStack { Text(stage.title); Spacer(); Text("\(data.records.filter { $0.errorStage == stage }.count) Fehler") }.font(.callout)
                }
                Text("Fehler bei der optionalen Korrektur können trotz erfolgreich erzeugtem Text auftreten. Diese Werte messen Geschwindigkeit und Zuverlässigkeit, nicht die Erkennungsgenauigkeit.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(12)
        }
    }
    private var settings: some View {
        GroupBox("Statistik-Einstellungen") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Nutzungsstatistik lokal aufzeichnen", isOn: $model.settings.enabled)
                HStack {
                    Text("Dein Vergleichstempo beim Tippen")
                    Spacer()
                    TextField("Wörter/Minute", value: $model.settings.typingWPM, format: .number)
                        .textFieldStyle(.roundedBorder).frame(width: 75)
                        .onChange(of: model.settings.typingWPM) { _, value in
                            if !value.isFinite || value <= 0 { model.settings.typingWPM = 40 }
                        }
                    Text("Wörter/Min.").foregroundStyle(.secondary)
                }
                Text("Zeitersparnis ist eine Schätzung: Tippzeit für denselben Text minus Aufnahme und Verarbeitung, mindestens null. Ein neues Vergleichstempo berechnet auch ältere Schätzungen neu.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Statistik zurücksetzen …", role: .destructive) { confirmReset = true }.disabled(!model.loaded || model.error != nil)
            }.padding(12)
        }
    }
    private func seconds(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(1)))) s" }
    private func duration(_ value: Double) -> String {
        if value < 60 { return "\(Int(value.rounded())) s" }
        if value < 3600 { return "\(Int(value) / 60) Min. \(Int(value) % 60) s" }
        return "\(Int(value) / 3600) Std. \(Int(value) % 3600 / 60) Min."
    }
}
