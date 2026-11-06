import AppKit
import SwiftUI

// Only needed by the linked settings/overlay views. No AppState is instantiated.
@MainActor final class AppDelegate: NSObject { @objc func openSystemCheck() {} }

@main
struct StatisticsPreview {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let menu = NSMenu()
        let item = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Vorschau beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu; menu.addItem(item); app.mainMenu = menu
        Task { @MainActor in
            do {
                let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appendingPathComponent("preview-\(UUID()).sqlite")
                let store = try StatisticsStore(url: url)
                let calendar = Calendar.current
                let apps = ["TextEdit", "Mail", "Codex", "Safari", "Notizen", "Nachrichten", "Pages"]
                for day in 0..<120 where day % 9 != 3 {
                    let date = calendar.date(byAdding: .day, value: -day, to: Date())!
                    for index in 0..<(day % 6 + 1) {
                        let failed = day % 17 == 0 && index == 0
                        let name = apps[(day + index) % apps.count]
                        let record = DictationRecord(id: UUID(), startedAt: date,
                            day: StatisticsCalendar.day(date, calendar: calendar), hour: 10, timeZone: calendar.timeZone.identifier,
                            appID: "preview.\(name)", appName: name, inputLanguage: index % 3 == 0 ? "auto" : "de",
                            outputLanguage: index % 4 == 0 ? "en" : "auto", translated: index % 4 == 0,
                            cleanupEnabled: index % 2 == 0, outcome: failed ? .failed : .success,
                            words: failed ? 0 : (day % 30 + 12) * (index + 1), transcriptWords: failed ? 0 : (day % 30 + 16) * (index + 1),
                            recordingSeconds: Double(day % 35 + 8), processingSeconds: Double(index + 1), audioSeconds: Double(index) * 0.4 + 0.3,
                            correctionSeconds: index % 2 == 0 ? 0.7 : nil, errorStage: failed ? .audio : nil)
                        try await store.insert(record)
                    }
                }
                let defaults = UserDefaults(suiteName: "de.tecwisper.statistics-preview")!
                let model = StatisticsModel(url: url, defaults: defaults)
                await model.flush()
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 840), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.title = "TecWisper · Beispieldaten (isolierte Vorschau)"
                window.contentView = NSHostingView(rootView: ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Statistiken · Beispieldaten").font(.largeTitle.bold())
                        StatisticsView(model: model, reset: {})
                    }.padding(30)
                }.tint(Theme.accent))
                window.center(); window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)
            } catch { print(error); app.terminate(nil) }
        }
        app.run()
    }
}
