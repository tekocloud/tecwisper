import AppKit
import SwiftUI

@MainActor final class AppDelegate: NSObject { @objc func openSystemCheck() {} }
@main struct HistoryPreview {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.regular)
        let menu = NSMenu(); let item = NSMenuItem(); let submenu = NSMenu()
        submenu.addItem(withTitle: "Vorschau beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = submenu; menu.addItem(item); app.mainMenu = menu
        Task { @MainActor in
            do {
                let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
                let url = folder.appendingPathComponent("history-preview-\(UUID()).sqlite")
                let store = try StatisticsStore(url: url)
                let samples = [
                    ("ChatGPT", "Kannst du mir die Zahlen morgen schicken?", "Kannst du mir die Zahlen morgen schicken?"),
                    ("Mail", "äh können wir das Meeting auf Donnerstag zehn Uhr schieben", "Können wir das Meeting auf Donnerstag, 10 Uhr verschieben?"),
                    ("TextEdit", "Guten Morgen, wir treffen uns um neun.", "Good morning, let's meet at nine.")
                ]
                for (index, sample) in samples.enumerated() {
                    let now = Date().addingTimeInterval(Double(-index * 300))
                    let record = DictationRecord(id: UUID(), startedAt: now, day: StatisticsCalendar.day(now, calendar: .current), hour: 12, timeZone: TimeZone.current.identifier, appID: "preview.\(sample.0)", appName: sample.0, inputLanguage: "de", outputLanguage: index == 2 ? "en" : "auto", translated: index == 2, cleanupEnabled: index == 1, outcome: .success, words: WordCounter.count(sample.2), transcriptWords: WordCounter.count(sample.1), recordingSeconds: 5, processingSeconds: 1, audioSeconds: 1, correctionSeconds: nil, errorStage: nil)
                    try await store.insert(record, text: .init(original: sample.1, output: sample.2))
                }
                let model = StatisticsModel(url: url, defaults: UserDefaults(suiteName: "de.tecwisper.history-fixtures")!)
                await model.flush()
                let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 900, height: 820), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.title = "TecWisper Verlauf · isolierte Beispieldaten"
                window.contentView = NSHostingView(rootView: ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Zuletzt verwendet · Vorschau").font(.title2.bold())
                        ForEach(model.activityRecords.prefix(2)) { record in ActivityRow(record: record, text: model.text(for: record.id), compact: true).desktopCard() }
                        Text("Aktivität · Vorschau").font(.title2.bold())
                        ActivityView(model: model)
                    }.padding(25)
                }.background(Theme.background).foregroundStyle(Theme.ink).preferredColorScheme(.dark).tint(Theme.accent))
                window.center(); window.makeKeyAndOrderFront(nil); app.activate()
            } catch { print(error); app.terminate(nil) }
        }
        app.run()
    }
}
