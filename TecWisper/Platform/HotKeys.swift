import AppKit
import Carbon

@MainActor
final class HotKeys {
    private var references: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var localEscape: Any?
    private var globalEscape: Any?
    private var heldIDs = Set<UInt32>()
    private(set) var registrationError: String?
    var onHold: ((Bool) -> Void)?
    var onToggle: (() -> Void)?
    var onEscape: (() -> Void)?
    var escapeEnabled = false
    private var lastSettings = Preferences()
    var suspended = false {
        didSet {
            if suspended { references.forEach { UnregisterEventHotKey($0) }; references.removeAll(); heldIDs.removeAll() }
            else { register(lastSettings) }
        }
    }
    init() {
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)), EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<HotKeys>.fromOpaque(context).takeUnretainedValue()
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            MainActor.assumeIsolated { owner.handle(id.id, pressed: pressed) }
            return noErr
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handler)
        localEscape = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, self?.escapeEnabled == true else { return event }
            self?.onEscape?(); return nil
        }
        globalEscape = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53, self?.escapeEnabled == true else { return }
            self?.onEscape?()
        }
    }
    private func handle(_ id: UInt32, pressed: Bool) {
        guard !suspended else { return }
        if pressed {
            guard heldIDs.insert(id).inserted else { return }
            if id == 1 { onHold?(true) } else { onToggle?() }
        } else {
            heldIDs.remove(id)
            if id == 1 { onHold?(false) }
        }
    }
    func register(_ settings: Preferences) {
        lastSettings = settings
        references.forEach { UnregisterEventHotKey($0) }; references.removeAll(); heldIDs.removeAll()
        registrationError = settings.shortcutError
        guard registrationError == nil, !suspended else { return }
        for (id, shortcut) in [(UInt32(1), settings.holdShortcut), (UInt32(2), settings.toggleShortcut)] {
            guard let shortcut else { continue }
            var reference: EventHotKeyRef?
            let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, EventHotKeyID(signature: 0x54435753, id: id), GetApplicationEventTarget(), UInt32(kEventHotKeyExclusive), &reference)
            if status == noErr, let reference { references.append(reference) }
            else { registrationError = "Ein Tastenkürzel konnte nicht registriert werden (\(status)). Wähle eine andere Kombination." }
        }
    }
}

extension Shortcut {
    var label: String {
        var label = ""
        if modifiers & UInt32(controlKey) != 0 { label += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { label += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { label += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { label += "⌘" }
        if keyCode == 49 { return label + " Leertaste" }
        if keyCode == 36 { return label + " ↩" }
        if keyCode == 48 { return label + " ⇥" }
        if keyCode == 51 { return label + " ⌫" }
        // Resolve the physical key in the active keyboard layout.
        if let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) {
            let data = unsafeBitCast(pointer, to: CFData.self)
            let layout = unsafeBitCast(CFDataGetBytePtr(data), to: UnsafePointer<UCKeyboardLayout>.self)
            var dead: UInt32 = 0; var length = 0; var chars = [UniChar](repeating: 0, count: 8)
            let status = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
            if status == noErr && length > 0 { return label + " " + String(utf16CodeUnits: chars, count: length).uppercased() }
        }
        return label + " Taste \(keyCode)"
    }
    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        modifiers = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
    }
}
