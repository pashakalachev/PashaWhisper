import AppKit
import Carbon
import WhisperCore

@MainActor
final class ShortcutController {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var source: CFRunLoopSource?
    private var configured: KeyboardShortcut?
    private var matcher: ShortcutMatcher?
    private var physicalModifiers: Set<UInt32> = []
    private var hotkeyHeld = false
    var onPress: (() -> Void)?
    var onAvailability: ((String?) -> Void)?
    init() {
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var hotkey = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                MemoryLayout<EventHotKeyID>.size, nil, &hotkey) == noErr,
                hotkey.signature == 0x50534841, hotkey.id == 1 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<ShortcutController>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                guard owner.configured != nil else { return }
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) { owner.hotkeyHeld = false }
                else if !owner.hotkeyHeld { owner.hotkeyHeld = true; owner.onPress?() }
            }
            return noErr
        }, specs.count, &specs, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func suspend() {
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false); CFMachPortInvalidate(eventTap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        eventTap = nil; source = nil; configured = nil; matcher = nil; physicalModifiers = []; hotkeyHeld = false
    }
    func install(_ shortcut: KeyboardShortcut) throws {
        guard shortcut.isValid else { throw AppFailure.message("Press a key or combination of keys.") }
        if configured == shortcut, reference != nil || eventTap != nil { return }
        if !shortcut.needsEventTap {
            var next: EventHotKeyRef?
            let result = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                EventHotKeyID(signature: 0x50534841, id: 1), GetApplicationEventTarget(), 0, &next)
            if result == noErr { suspend(); reference = next; configured = shortcut; onAvailability?(nil); return }
        }
        suspend(); configured = shortcut; matcher = ShortcutMatcher(shortcut: shortcut)
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<ShortcutController>.fromOpaque(context).takeUnretainedValue()
                return MainActor.assumeIsolated { owner.handle(type, event) ? nil : Unmanaged.passUnretained(event) }
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap else {
            onAvailability?("Shortcut saved. Enable Accessibility to use this key or chord globally.")
            return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        onAvailability?(nil)
    }
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let configured { matcher = ShortcutMatcher(shortcut: configured) }; physicalModifiers = []
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }; return false
        }
        if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(type) { matcher?.usedWithMouse(); return false }
        guard let native = NSEvent(cgEvent: event), let input = ShortcutKeys.input(native, held: physicalModifiers) else { return false }
        if KeyboardShortcut.modifierKeys.contains(input.key), !input.pulse {
            if input.down { physicalModifiers.insert(input.key) } else { physicalModifiers.remove(input.key) }
        }
        var outcome = matcher?.update(key: input.key, down: input.down, modifiers: input.modifiers, repeatKey: input.repeating)
        if input.pulse { outcome = matcher?.update(key: input.key, down: false, modifiers: input.modifiers) }
        if outcome?.trigger == true { Task { @MainActor [weak self] in self?.onPress?() } }
        return outcome?.suppress == true
    }
    func refreshPermission() {
        guard let configured, reference == nil, eventTap == nil, AXIsProcessTrusted() else { return }
        try? install(configured)
    }
    func shutdown() { suspend(); if let handler { RemoveEventHandler(handler) }; handler = nil }
}

@MainActor
enum ShortcutKeys {
    static func input(_ event: NSEvent, held: Set<UInt32> = []) -> (key: UInt32, down: Bool, modifiers: UInt32, repeating: Bool, pulse: Bool)? {
        guard [.keyDown, .keyUp, .flagsChanged].contains(event.type) else { return nil }
        let key = UInt32(event.keyCode)
        var mods: UInt32 = 0
        if event.modifierFlags.contains(.command) { mods |= 256 }
        if event.modifierFlags.contains(.shift) { mods |= 512 }
        if event.modifierFlags.contains(.option) { mods |= 2048 }
        if event.modifierFlags.contains(.control) { mods |= 4096 }
        // Use the event's own state: querying live keyboard state can miss a fast tap
        // when both press and release have happened before this event is processed.
        let implicitFunctionKeys: Set<UInt32> = [64,79,80,90,96,97,98,99,100,101,103,105,106,107,109,111,113,115,116,117,118,119,120,121,122,123,124,125,126]
        if event.modifierFlags.contains(.function), held.contains(63) || !implicitFunctionKeys.contains(key) { mods |= KeyboardShortcut.fnModifier }
        let pulse = event.type == .flagsChanged && key == 57
        var down = event.type == .keyDown
        if event.type == .flagsChanged {
            let masks: [UInt32:UInt] = [54:UInt(NX_DEVICERCMDKEYMASK),55:UInt(NX_DEVICELCMDKEYMASK),56:UInt(NX_DEVICELSHIFTKEYMASK),60:UInt(NX_DEVICERSHIFTKEYMASK),58:UInt(NX_DEVICELALTKEYMASK),61:UInt(NX_DEVICERALTKEYMASK),59:UInt(NX_DEVICELCTLKEYMASK),62:UInt(NX_DEVICERCTLKEYMASK)]
            let raw = event.modifierFlags.rawValue
            let deviceMask = masks.values.reduce(UInt(0), |)
            if pulse { down = true }
            else if key == 63 { down = event.modifierFlags.contains(.function) }
            else if let mask = masks[key], raw & deviceMask != 0 { down = raw & mask != 0 }
            else {
                // Synthetic/accessibility events can omit physical left/right bits.
                let groups: [UInt32:NSEvent.ModifierFlags] = [54:.command,55:.command,56:.shift,60:.shift,58:.option,61:.option,59:.control,62:.control]
                down = groups[key].map { event.modifierFlags.contains($0) && !held.contains(key) } ?? false
            }
        }
        return (key, down, mods, event.type == .keyDown && event.isARepeat, pulse)
    }
    static func label(_ key: UInt32, event: NSEvent? = nil) -> String {
        let special: [UInt32:String] = [49:"Space",36:"Return",48:"Tab",51:"Delete",53:"Escape",57:"Caps Lock",63:"Fn / Globe",54:"Right Command",55:"Left Command",56:"Left Shift",60:"Right Shift",58:"Left Option",61:"Right Option",59:"Left Control",62:"Right Control",117:"Forward Delete",123:"←",124:"→",125:"↓",126:"↑",115:"Home",119:"End",116:"Page Up",121:"Page Down",76:"Keypad Enter",122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12",105:"F13",107:"F14",113:"F15",106:"F16",64:"F17",79:"F18",80:"F19",90:"F20"]
        return special[key] ?? event?.characters(byApplyingModifiers: [])?.uppercased() ?? "Key \(key)"
    }
}

/// The picker accepts both keyboard events and native hotkey notifications.
/// Remappers can deliver hotkeys without sending AppKit key events. All temporary
/// registrations are removed when the picker closes or the app deactivates.
@MainActor
final class ShortcutCaptureMonitor {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var generation = UUID()
    private var hotkeyHandler: EventHandlerRef?
    private var hotkeys: [EventHotKeyRef] = []
    private var bindings: [UInt32: (key: UInt32, modifiers: UInt32)] = [:]
    private var onEvent: ((NSEvent) -> Void)?
    @discardableResult func start(useEventTap: Bool = true, onEvent: @escaping (NSEvent) -> Void) -> Bool {
        stop(); self.onEvent = onEvent
        startHotkeyCapture()
        guard useEventTap else { return false }
        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<ShortcutCaptureMonitor>.fromOpaque(context).takeUnretainedValue()
                return MainActor.assumeIsolated { owner.receive(type, event) ? nil : Unmanaged.passUnretained(event) }
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return false }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
    private func enqueue(_ native: NSEvent) {
        let current = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.generation == current, NSApp.isActive else { return }
            self.onEvent?(native)
        }
    }
    private func receive(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }; return false
        }
        guard NSApp.isActive, let native = NSEvent(cgEvent: event), onEvent != nil else { return false }
        enqueue(native)
        return true
    }
    private func startHotkeyCapture() {
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<ShortcutCaptureMonitor>.fromOpaque(context).takeUnretainedValue()
            return MainActor.assumeIsolated { owner.receiveHotkey(event) }
        }, specs.count, &specs, Unmanaged.passUnretained(self).toOpaque(), &hotkeyHandler)
        // Standard modifiers and every supported virtual key, with no device-specific preset.
        for combination in UInt32(0)..<16 {
            let bits: [UInt32] = [256, 512, 2048, 4096]
            let modifiers = bits.enumerated().reduce(UInt32(0)) { $0 | (combination & (1 << $1.offset) != 0 ? $1.element : 0) }
            for key in UInt32(0)..<128 where !KeyboardShortcut.modifierKeys.contains(key) {
                let id = combination * 128 + key + 1
                var ref: EventHotKeyRef?
                if RegisterEventHotKey(key, modifiers, EventHotKeyID(signature: 0x50534350, id: id),
                    GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                    hotkeys.append(ref); bindings[id] = (key, modifiers)
                }
            }
        }
    }
    private func receiveHotkey(_ event: EventRef) -> OSStatus {
        var hotkey = EventHotKeyID()
        guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
            MemoryLayout<EventHotKeyID>.size, nil, &hotkey) == noErr, hotkey.signature == 0x50534350,
            let binding = bindings[hotkey.id], NSApp.isActive, onEvent != nil else { return OSStatus(eventNotHandledErr) }
        if let native = Self.keyEvent(key: binding.key, modifiers: binding.modifiers, down: GetEventKind(event) == UInt32(kEventHotKeyPressed)) {
            enqueue(native)
        }
        return noErr
    }
    static func keyEvent(key: UInt32, modifiers: UInt32, down: Bool) -> NSEvent? {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(key), keyDown: down) else { return nil }
        var flags: CGEventFlags = []
        if modifiers & 256 != 0 { flags.insert(.maskCommand) }
        if modifiers & 512 != 0 { flags.insert(.maskShift) }
        if modifiers & 2048 != 0 { flags.insert(.maskAlternate) }
        if modifiers & 4096 != 0 { flags.insert(.maskControl) }
        event.flags = flags
        return NSEvent(cgEvent: event)
    }
    func stop() {
        generation = UUID(); onEvent = nil
        for hotkey in hotkeys { UnregisterEventHotKey(hotkey) }
        hotkeys = []; bindings = [:]
        if let hotkeyHandler { RemoveEventHandler(hotkeyHandler) }; hotkeyHandler = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }
}

@MainActor
final class ShortcutRecorder {
    private var gesture = ShortcutGesture()
    private var labels: [UInt32:String] = [:]
    var preview = "Press and release your shortcut…"
    func reset() { gesture = ShortcutGesture(); labels = [:]; preview = "Press and release your shortcut…" }
    func observe(_ event: NSEvent) -> KeyboardShortcut? {
        guard let input = ShortcutKeys.input(event, held: gesture.held), !input.repeating else { return nil }
        labels[input.key] = ShortcutKeys.label(input.key, event: event)
        var completed = gesture.update(key: input.key, down: input.down, modifiers: input.modifiers)
        if input.pulse { completed = gesture.update(key: input.key, down: false, modifiers: input.modifiers) }
        if let completed { return candidate(completed.keys, modifiers: completed.modifiers) }
        if !gesture.peak.isEmpty { preview = candidate(gesture.peak, modifiers: gesture.peakModifiers).display }
        return nil
    }
    private func candidate(_ keys: Set<UInt32>, modifiers: UInt32) -> KeyboardShortcut {
        let regular = keys.subtracting(KeyboardShortcut.modifierKeys)
        let chosen = (regular.isEmpty ? keys : regular).sorted()
        return KeyboardShortcut(keyCode: chosen[0], modifiers: regular.isEmpty ? 0 : modifiers,
            keyLabel: chosen.map { labels[$0] ?? ShortcutKeys.label($0) }.joined(separator: " + "),
            additionalKeys: chosen.count > 1 ? Array(chosen.dropFirst()) : nil)
    }
}

@MainActor
final class FocusedTextAnchor {
    private var fallback = CGRect.zero
    func capture() { fallback = CGRect(origin: NSEvent.mouseLocation, size: CGSize(width: 1, height: 1)) }
    func rect() -> CGRect {
        guard AXIsProcessTrusted(), let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return fallback }
        let app = AXUIElementCreateApplication(front.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.08)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue, CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return fallback }
        let element = focusedValue as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.08)
        var range: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success, let range {
            var result: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &result) == .success,
               let result, CFGetTypeID(result) == AXValueGetTypeID() {
                var rect = CGRect.zero
                if AXValueGetValue(result as! AXValue, .cgRect, &rect), rect.height > 0, rect.width < 1000 { return cocoa(rect) }
            }
        }
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        guard let role = roleValue as? String, [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role) else { return fallback }
        var positionValue: CFTypeRef?, sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue, let sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return fallback }
        var point = CGPoint.zero; var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point), AXValueGetValue(sizeValue as! AXValue, .cgSize, &size), size.height > 0 else { return fallback }
        return cocoa(CGRect(origin: point, size: size))
    }
    private func cocoa(_ rect: CGRect) -> CGRect {
        // Accessibility coordinates use the primary display's top-left, not the current display's origin.
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: rect.minX, y: top - rect.maxY, width: rect.width, height: rect.height)
    }
}
