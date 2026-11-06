import AppKit
import SwiftUI

private final class DictationPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class OverlayController {
    private let panel: NSPanel
    private var hideTask: Task<Void, Never>?
    init(state: AppState) {
        panel = DictationPanel(contentRect: NSRect(x: 0, y: 0, width: 350, height: 140), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: OverlayView(state: state))
    }
    func show() {
        hideTask?.cancel()
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2, y: frame.minY + 36))
        }
        panel.orderFrontRegardless()
    }
    func showResult() {
        show()
        hideTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 12_000_000_000) } catch { return }
            self?.panel.orderOut(nil)
        }
    }
    func hide() { hideTask?.cancel(); panel.orderOut(nil) }
}

private struct OverlayView: View {
    @ObservedObject var state: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                BrandMark(size: 24)
                Text(state.phase.title).font(.system(.headline, design: .rounded))
                Spacer()
                Button {
                    if state.phase.busy { state.cancel() }
                    else { state.dismissOverlay() }
                } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .help(state.phase.busy ? "Abbrechen (Escape)" : "Anzeige schließen")
                    .accessibilityLabel(state.phase.busy ? "Diktat abbrechen" : "Anzeige schließen")
            }
            if state.phase == .recording {
                HStack(spacing: 4) {
                    ForEach(0..<26) { index in
                        Capsule().fill(index < Int(state.level * 26) ? Theme.accent : Theme.accent.opacity(0.15)).frame(height: CGFloat(8 + (index % 5) * 4))
                    }
                    Button("Fertig") { state.stop() }.buttonStyle(.borderedProminent).controlSize(.small)
                }.frame(height: 26).accessibilityLabel("Mikrofonpegel")
            } else if state.phase.busy {
                ProgressView().progressViewStyle(.linear).tint(Theme.accent)
                Text("Escape zum Abbrechen").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(state.message).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack {
                    if !state.result.isEmpty { Button("Text kopieren") { state.copyResult() }.controlSize(.small) }
                    Button("Details öffnen") { NSApp.sendAction(#selector(AppDelegate.openSystemCheck), to: nil, from: nil) }.controlSize(.small)
                }
            }
        }.padding(18).frame(width: 350, height: 140, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
            .preferredColorScheme(.dark).tint(Theme.accent)
    }
}
