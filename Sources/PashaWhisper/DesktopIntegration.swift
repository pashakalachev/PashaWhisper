import AppKit
import Carbon
import WhisperCore

@MainActor
final class ShortcutController {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onPress: (() -> Void)?
    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<ShortcutController>.fromOpaque(context).takeUnretainedValue()
            Task { @MainActor in owner.onPress?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func suspend() { if let reference { UnregisterEventHotKey(reference) }; reference = nil }
    func install(_ shortcut: KeyboardShortcut) throws {
        guard shortcut.isValid else { throw AppFailure.message("Choose a key with Command, Option, or Control.") }
        // Do not lose the current registration when a new combination is already occupied.
        var newReference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: 0x50534841, id: 1), GetApplicationEventTarget(), 0, &newReference)
        guard status == noErr else { throw AppFailure.message("That shortcut is already in use or unavailable. Choose another combination.") }
        suspend(); reference = newReference
    }
    func shutdown() { suspend(); if let handler { RemoveEventHandler(handler) }; handler = nil }
    static func candidate(from event: NSEvent) -> KeyboardShortcut {
        let flags = event.modifierFlags
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let specials: [UInt16: String] = [49:"Space",36:"Return",48:"Tab",51:"Delete",117:"Forward Delete",123:"←",124:"→",125:"↓",126:"↑",122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",101:"F9",109:"F10",103:"F11",111:"F12"]
        let label = specials[event.keyCode] ?? event.characters(byApplyingModifiers: [])?.uppercased() ?? "Key \(event.keyCode)"
        return KeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
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
