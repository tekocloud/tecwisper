import AppKit
import SwiftUI

/// VS Code Dark Modern: editor, sidebar, widget, border, foreground and button tokens.
enum Theme {
    static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    static let background = color(0x1F1F1F)
    static let sidebar = color(0x181818)
    static let panel = color(0x252526)
    static let border = color(0x333333)
    static let ink = color(0xCCCCCC)
    static let muted = color(0x9D9D9D)
    static let accent = color(0x0078D4)
    static let link = color(0x4DAAFC)
    static let mint = color(0x4EC9B0)
    static let selected = color(0x04395E)
    static let warning = color(0xD7BA7D)
}
struct DesktopGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
            configuration.content.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(16).background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }
}
enum BrandAssets {
    static let logo = load("AppLogo")
    static let menuBar = load("MenuBarLogo")
    private static func load(_ name: String) -> NSImage {
        if let image = NSImage(named: NSImage.Name(name)) { return image }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"), let image = NSImage(contentsOf: url) { return image }
        // Keep the branded bundle icon as fallback; never substitute the previous waveform.
        if let url = Bundle.main.url(forResource: "TecWisperIcon", withExtension: "icns"), let image = NSImage(contentsOf: url) { return image }
        return NSImage(size: NSSize(width: 32, height: 32))
    }
}
struct BrandMark: View {
    var size: CGFloat = 34
    var body: some View {
        Image(nsImage: BrandAssets.logo).resizable().interpolation(.high).renderingMode(.original)
            .aspectRatio(contentMode: .fit).frame(width: size, height: size)
            .accessibilityLabel("TecWisper")
    }
}
struct EngineBadge: View {
    @ObservedObject var state: AppState
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(state.allReady ? Theme.mint : Theme.warning).frame(width: 6, height: 6)
            Text(state.phase.busy ? (state.phase == .recording ? "Aufnahme" : "Verarbeitet") : state.allReady ? "Bereit" : "Prüfen")
                .font(.system(size: 11, weight: .medium))
        }.foregroundStyle(state.allReady ? Theme.mint : Theme.warning)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background((state.allReady ? Theme.mint : Theme.warning).opacity(0.10), in: Capsule())
    }
}
