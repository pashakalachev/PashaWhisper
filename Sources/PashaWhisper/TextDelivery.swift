import AppKit
import CryptoKit
import WhisperCore

/// Captures a selection, never an entire-field replacement operation.
@MainActor
final class TextDelivery {
    private struct Destination {
        let pid: pid_t
        let element: AXUIElement
        let selection: CFRange
        let valueDigest: SHA256.Digest?
    }
    private var destination: Destination?
    private var unavailable = "Start dictation while a text field in another app is focused."
    private var lastAttempt: UUID?

    func capture() {
        destination = nil
        guard PermissionState.current().autoPasteReady else {
            unavailable = "Complete automatic paste access in Setup. Your transcript is ready to copy."; return
        }
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            unavailable = "Start dictation from a text field in another app to paste automatically."; return
        }
        guard let element = Self.focusedElement(front.processIdentifier), Self.isTextField(element),
              let range = Self.selection(element) else {
            unavailable = "The original field does not expose an editable text selection. Copy the transcript below."; return
        }
        destination = Destination(pid: front.processIdentifier, element: element, selection: range, valueDigest: Self.digest(element))
    }

    func deliver(_ text: String, session: UUID) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "No text to insert." }
        guard lastAttempt != session else { return "Delivery was already attempted. Check the field before pasting again." }
        lastAttempt = session
        guard PermissionState.current().autoPasteReady else { return "Complete automatic paste access in Setup. Your transcript is ready to copy." }
        guard let destination else { return unavailable }
        guard contextMatches(destination) else { return "The destination or selection changed. Your transcript is ready to copy." }
        // Build both events before changing the clipboard. Never post Paste unless
        // the exact current transcript was written and still owns the clipboard.
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) else {
            return "Could not create the paste command. Copy the transcript below."
        }
        let clipboard = NSPasteboard.general
        return VerifiedPaste.perform(text: text, write: {
            clipboard.clearContents()
            guard clipboard.setString(text, forType: .string) else { return nil }
            return clipboard.changeCount
        }, unchanged: { count in clipboard.changeCount == count && clipboard.string(forType: .string) == text },
            destinationMatches: { self.contextMatches(destination) }, paste: {
                down.flags = .maskCommand; up.flags = .maskCommand
                // Post through the window server so macOS translates the key normally.
                // Focus was verified above; no application is activated here.
                down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
            })
    }
    private func contextMatches(_ destination: Destination) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == destination.pid,
              let current = Self.focusedElement(destination.pid), CFEqual(current, destination.element),
              Self.isTextField(current), let selection = Self.selection(current),
              selection.location == destination.selection.location, selection.length == destination.selection.length else { return false }
        if let digest = destination.valueDigest { return Self.digest(current).map { Array($0) == Array(digest) } ?? false }
        return true
    }
    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    private static func focusedElement(_ pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(app, 0.15)
        guard let value = attribute(app, kAXFocusedUIElementAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let element = value as! AXUIElement; AXUIElementSetMessagingTimeout(element, 0.15)
        return element
    }
    private static func isTextField(_ element: AXUIElement) -> Bool {
        guard let role = attribute(element, kAXRoleAttribute) as? String,
              [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role),
              (attribute(element, kAXSubroleAttribute) as? String) != kAXSecureTextFieldSubrole,
              (attribute(element, kAXEnabledAttribute) as? Bool) != false else { return false }
        for attribute in [kAXSelectedTextAttribute, kAXValueAttribute] {
            var settable = DarwinBoolean(false)
            if AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success && settable.boolValue { return true }
        }
        return false
    }
    private static func selection(_ element: AXUIElement) -> CFRange? {
        guard let value = attribute(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange(); return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
    }
    private static func digest(_ element: AXUIElement) -> SHA256.Digest? {
        (attribute(element, kAXValueAttribute) as? String).map { SHA256.hash(data: Data($0.utf8)) }
    }
}

/// The delivery invariant is independently testable without touching a real clipboard.
enum VerifiedPaste {
    static func perform(text: String, write: () -> Int?, unchanged: (Int) -> Bool,
                        destinationMatches: () -> Bool, paste: () -> Void) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "No text to insert." }
        guard destinationMatches() else { return "The destination changed. Copy the transcript below." }
        guard let revision = write(), unchanged(revision) else { return "The clipboard changed or could not be updated. Copy the transcript below." }
        guard destinationMatches(), unchanged(revision) else { return "The destination or clipboard changed. Copy the transcript below." }
        paste()
        return nil
    }
}
