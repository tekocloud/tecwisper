import AppKit
import ApplicationServices
import Carbon

@MainActor
final class TextInsertion {
    struct Target {
        let application: NSRunningApplication
        var processID: pid_t { application.processIdentifier }
        var name: String { application.localizedName ?? "Ziel-App" }
        let element: AXUIElement
        let window: AXUIElement?
        let selection: CFTypeRef?
        let value: String?
    }
    struct Outcome {
        let attempted: Bool
        let message: String
        var confirmed = false
    }
    private var lastExternalApplication: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?
    private(set) var captureFailure = "Setze den Cursor vor dem Diktat in ein Textfeld einer anderen App."
    init() {
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { lastExternalApplication = app }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.activationPolicy == .regular else { return }
            MainActor.assumeIsolated { self?.lastExternalApplication = app }
        }
    }
    static var isTrusted: Bool { AXIsProcessTrusted() }
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = Self.attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private func focused(in app: NSRunningApplication) -> AXUIElement? {
        guard Self.isTrusted else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        // Some web-backed apps expose focus only through the system-wide tree or
        // their window, rather than AXFocusedUIElement on the application itself.
        AXUIElementSetAttributeValue(application, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(application, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        if let element = elementAttribute(application, kAXFocusedUIElementAttribute) { return element }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
           let element = elementAttribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute) {
            var owner: pid_t = 0
            if AXUIElementGetPid(element, &owner) == .success, owner == app.processIdentifier { return element }
        }
        guard let window = elementAttribute(application, kAXFocusedWindowAttribute) else { return nil }
        if let element = elementAttribute(window, kAXFocusedUIElementAttribute) { return element }
        // Resolve only an explicitly focused editor. Never guess the first text field:
        // a window can contain both a search box and a message composer.
        var queue = [window]
        var index = 0
        while index < queue.count, index < 256 {
            let item = queue[index]; index += 1
            if Self.attribute(item, kAXFocusedAttribute) as? Bool == true, editable(item) { return item }
            if let children = Self.attribute(item, kAXChildrenAttribute) as? [AXUIElement] {
                queue.append(contentsOf: children.prefix(max(0, 256 - queue.count)))
            }
        }
        return nil
    }
    private func textValue(_ element: AXUIElement) -> String? {
        if let value = Self.attribute(element, kAXValueAttribute) as? String { return value }
        if let value = Self.attribute(element, kAXValueAttribute) as? NSAttributedString { return value.string }
        guard let count = Self.attribute(element, kAXNumberOfCharactersAttribute) as? Int,
              count >= 0, count <= 1_000_000 else { return nil }
        var range = CFRange(location: 0, length: count)
        guard let parameter = AXValueCreate(.cfRange, &range) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString,
                                                         parameter, &result) == .success else { return nil }
        return result as? String
    }
    private func secure(_ element: AXUIElement) -> Bool {
        if IsSecureEventInputEnabled() { return true }
        var current: AXUIElement? = element
        for _ in 0..<16 {
            guard let item = current else { break }
            let subrole = Self.attribute(item, kAXSubroleAttribute) as? String ?? ""
            if subrole.lowercased().contains("secure") || subrole.lowercased().contains("password") { return true }
            if Self.attribute(item, "AXProtectedContent") as? Bool == true { return true }
            current = elementAttribute(item, kAXParentAttribute)
        }
        return false
    }
    private func editable(_ element: AXUIElement) -> Bool {
        let role = Self.attribute(element, kAXRoleAttribute) as? String ?? ""
        if [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) { return true }
        // Rich web/Electron editors may expose a generic group rather than AXTextArea.
        if Self.attribute(element, "AXEditable") as? Bool == true { return true }
        return [kAXGroupRole, kAXUnknownRole].contains(role) && Self.attribute(element, kAXSelectedTextRangeAttribute) != nil
    }
    func capture(application explicitApplication: NSRunningApplication? = nil) -> Target? {
        guard Self.isTrusted else { captureFailure = "TecWisper benötigt die macOS-Freigabe zum Einfügen in andere Apps."; return nil }
        let frontmost = NSWorkspace.shared.frontmostApplication
        let app = explicitApplication ?? (frontmost?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? lastExternalApplication : frontmost)
        guard let app, !app.isTerminated, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            captureFailure = "Keine vorherige Ziel-App gefunden. Setze zuerst den Cursor in das gewünschte Textfeld."; return nil
        }
        guard let element = focused(in: app) else {
            captureFailure = "\(app.localizedName ?? "Die Ziel-App") meldet kein aktives Eingabefeld. Klicke vor dem Diktat in das gewünschte Textfeld."; return nil
        }
        guard !secure(element) else { captureFailure = "In ein Passwortfeld oder eine geschützte Eingabe wird nicht eingefügt."; return nil }
        guard editable(element) else { captureFailure = "Das aktive Element in \(app.localizedName ?? "der Ziel-App") ist kein erkanntes Textfeld. Klicke direkt in das Eingabefeld und starte erneut."; return nil }
        lastExternalApplication = app
        return Target(application: app, element: element, window: elementAttribute(element, kAXWindowAttribute),
                      selection: Self.attribute(element, kAXSelectedTextRangeAttribute), value: textValue(element))
    }
    private func rejection(_ target: Target) -> String? {
        guard !target.application.isTerminated else { return "Die Ziel-App wurde beendet. Der Text bleibt zum Kopieren verfügbar." }
        guard let current = focused(in: target.application) else { return "Das ursprüngliche Eingabefeld ist nicht erreichbar. Der Text bleibt zum Kopieren verfügbar." }
        let currentWindow = elementAttribute(current, kAXWindowAttribute)
        let selection = Self.attribute(current, kAXSelectedTextRangeAttribute)
        let value = textValue(current)
        // Unsupported cursor/value attributes are unknown, not evidence of a focus change.
        let sameSelection: Bool? = target.selection.flatMap { original in selection.map { CFEqual(original, $0) } }
        let sameContent: Bool? = target.value.flatMap { original in value.map { original == $0 } }
        let sameWindow: Bool? = target.window.flatMap { original in currentWindow.map { CFEqual(original, $0) } }
        return InsertionPolicy.rejection(.init(
            sameApplication: NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processID,
            sameElement: CFEqual(current, target.element), sameWindow: sameWindow, sameSelection: sameSelection,
            sameContent: sameContent, editable: editable(current), secure: secure(current)))
    }
    func insert(_ text: String, into target: Target?, activateTarget: Bool = false) async -> Outcome {
        guard !text.isEmpty else { return .init(attempted: false, message: "Es liegt kein Text zum Einfügen vor.") }
        guard let target else { return .init(attempted: false, message: captureFailure) }
        // A click in our own settings/overlay may activate TecWisper; return only in that case.
        // Never steal focus from another app the user switched to during processing.
        if activateTarget || NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            guard !target.application.isTerminated else { return .init(attempted: false, message: "Die Ziel-App wurde beendet.") }
            NSApp.yieldActivation(to: target.application)
            target.application.activate(from: .current, options: [])
            // AX-assisted activation also works when an accessibility client invokes our test button
            // without first making our own application frontmost.
            let appElement = AXUIElementCreateApplication(target.processID)
            AXUIElementSetAttributeValue(appElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            for _ in 0..<20 {
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processID { break }
                do { try await Task.sleep(nanoseconds: 25_000_000); try Task.checkCancellation() }
                catch { return .init(attempted: false, message: "Einfügen abgebrochen.") }
            }
        }
        // A fast transcription may finish while the dictation shortcut is still held.
        // Do not deliver Command-V with physical Option/Shift/Control keys pressed.
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        for _ in 0..<100 {
            if CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty { break }
            do { try await Task.sleep(nanoseconds: 20_000_000); try Task.checkCancellation() }
            catch { return .init(attempted: false, message: "Einfügen abgebrochen.") }
        }
        guard CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty else {
            return .init(attempted: false, message: "Die Zusatztasten sind noch gedrückt. Der Text bleibt zum Kopieren verfügbar.")
        }
        // Let activation and the editor's focus settle before checking the original target.
        do { try await Task.sleep(nanoseconds: 100_000_000); try Task.checkCancellation() }
        catch { return .init(attempted: false, message: "Einfügen abgebrochen.") }
        guard !Task.isCancelled else { return .init(attempted: false, message: "Einfügen abgebrochen.") }
        if let reason = rejection(target) { return .init(attempted: false, message: reason) }
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return .init(attempted: false, message: "Der macOS-Einfügebefehl konnte nicht erstellt werden.")
        }
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.pasteboardItems?.map { item in
            item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }; return (type, data)
            }
        } ?? []
        func restore() {
            pasteboard.clearContents()
            let items = saved.map { values in
                let item = NSPasteboardItem(); values.forEach { item.setData($0.1, forType: $0.0) }; return item
            }
            pasteboard.writeObjects(items)
        }
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            restore(); return .init(attempted: false, message: "Der Text konnte nicht in die Zwischenablage geschrieben werden.")
        }
        let pastedCount = pasteboard.changeCount
        // Use the normal macOS keyboard route: process-directed events can bypass
        // the menu/key-equivalent handling of web and Electron editors.
        // Recheck focus immediately before posting; never retry an unacknowledged paste.
        if let reason = rejection(target) {
            if pasteboard.changeCount == pastedCount { restore() }
            return .init(attempted: false, message: reason)
        }
        down.flags = .maskCommand; up.flags = .maskCommand
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        // This independent task survives cancellation of the dictation, so the target has time to read.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if pasteboard.changeCount == pastedCount { restore() }
        }
        var selectedRange: NSRange?
        if let selection = target.selection, CFGetTypeID(selection) == AXValueGetTypeID() {
            let value = selection as! AXValue
            var range = CFRange()
            if AXValueGetType(value) == .cfRange, AXValueGetValue(value, .cfRange, &range) {
                selectedRange = NSRange(location: range.location, length: range.length)
            }
        }
        for _ in 0..<20 {
            do { try await Task.sleep(nanoseconds: 100_000_000); try Task.checkCancellation() }
            catch { break }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processID else { break }
            guard let current = focused(in: target.application), !secure(current), editable(current) else { continue }
            let sameElement = CFEqual(current, target.element)
            let sameWindow = target.window.flatMap { original in
                elementAttribute(current, kAXWindowAttribute).map { CFEqual(original, $0) }
            }
            // Web editors may replace their AX node after a paste. The same window
            // plus an exact text delta still supplies evidence of the insertion.
            guard sameWindow != false, sameElement || sameWindow == true else { break }
            if InsertionPolicy.confirmsInsertion(before: target.value, after: textValue(current), text: text, selection: selectedRange) {
                return .init(attempted: true, message: "Text in \(target.name) eingefügt.", confirmed: true)
            }
        }
        return .init(attempted: true, message: "Die Textübernahme in \(target.name) konnte nicht bestätigt werden. Bei Bedarf kannst du den Text kopieren.")
    }
}
