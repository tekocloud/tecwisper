import AppKit
import SwiftUI

@main
struct TecWisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            QuickPanelView(state: delegate.state, statistics: delegate.state.statistics) { page in
                delegate.state.settingsPage = page
                delegate.openSettings()
            }
        } label: {
            MenuBarLabel(state: delegate.state)
        }.menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Einstellungen …") { delegate.state.settingsPage = .controls; delegate.openSettings() }.keyboardShortcut(",")
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private var settingsWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [.activateAllWindows])
            NSApp.terminate(nil)
            return
        }
        // Use the bundled image directly so Dock does not retain a cached older icon.
        if let iconURL = Bundle.main.url(forResource: "TecWisperIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        NSApp.setActivationPolicy(.regular)
        state.installOverlay()
        // Remove orphaned audio from a previous abnormal termination.
        let folder = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("TecWisper-") && file.pathExtension == "caf" { try? FileManager.default.removeItem(at: file) }
        }
        openSettings()
    }
    @objc func openSystemCheck() {
        state.settingsPage = .status
        openSettings()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(); return true
    }
    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 820), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "TecWisper"; window.isReleasedWhenClosed = false
            window.backgroundColor = NSColor(calibratedWhite: 31.0 / 255.0, alpha: 1)
            window.appearance = NSAppearance(named: .darkAqua)
            window.setFrameAutosaveName("TecWisperMainWindow")
            window.contentView = NSHostingView(rootView: SettingsView(state: state))
            window.center(); settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
        state.settingsOpened()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !state.backupBusy else { return .terminateCancel }
        state.cancel()
        Task { await state.statistics.flush(); sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var state: AppState
    var body: some View {
        Image(nsImage: BrandAssets.menuBar).resizable().interpolation(.high).renderingMode(.original)
            .aspectRatio(contentMode: .fit).frame(width: 22, height: 22)
            .overlay(alignment: .bottomTrailing) {
                if state.phase == .recording { Circle().fill(.red).frame(width: 5, height: 5).overlay(Circle().stroke(.white, lineWidth: 0.5)) }
            }
            .accessibilityLabel(state.phase == .recording ? "TecWisper nimmt auf" : "TecWisper")
    }
}
