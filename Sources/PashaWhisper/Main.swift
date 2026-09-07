import AppKit
import SwiftUI
import Carbon
import WhisperCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    private var window: NSWindow?
    private var overlay: NSPanel?
    private var statusItem: NSStatusItem?
    private let shortcutController = ShortcutController()
    private let shortcutRecorder = ShortcutRecorder()
    private let shortcutCaptureMonitor = ShortcutCaptureMonitor()
    private let anchor = FocusedTextAnchor()
    private let delivery = TextDelivery()
    private var overlayTimer: Timer?
    private var previewEnd: DispatchWorkItem?
    private var recordMenuItem: NSMenuItem?
    private var localMonitor: Any?
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let menu = NSMenu()
        let show = NSMenuItem(title: "Open PashaWhisper", action: #selector(showWindow), keyEquivalent: "")
        show.target = self; menu.addItem(show)
        let record = NSMenuItem(title: "Start / Stop Dictation    \(model.shortcut.display)", action: #selector(toggle), keyEquivalent: "")
        record.target = self; menu.addItem(record); recordMenuItem = record
        let cancel = NSMenuItem(title: "Cancel Dictation", action: #selector(cancelRecording), keyEquivalent: "")
        cancel.target = self; menu.addItem(cancel)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit PashaWhisper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem = NSStatusBar.system.statusItem(withLength: 27)
        statusItem?.menu = menu
        if let button = statusItem?.button {
            let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
                NSColor.black.setFill()
                let shape = NSBezierPath()
                shape.move(to: NSPoint(x: 2, y: 18)); shape.line(to: NSPoint(x: 7, y: 14))
                shape.line(to: NSPoint(x: 13, y: 14)); shape.line(to: NSPoint(x: 18, y: 18))
                shape.line(to: NSPoint(x: 18, y: 6)); shape.line(to: NSPoint(x: 13, y: 2))
                shape.line(to: NSPoint(x: 7, y: 2)); shape.line(to: NSPoint(x: 2, y: 6)); shape.close(); shape.fill()
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: NSRect(x: 5, y: 8, width: 3, height: 3)).fill()
                NSBezierPath(ovalIn: NSRect(x: 12, y: 8, width: 3, height: 3)).fill()
                return true
            }
            image.isTemplate = true; button.image = image; button.toolTip = "PashaWhisper · \(model.shortcut.display) to dictate"
            button.setAccessibilityLabel("PashaWhisper")
        }
        shortcutController.onAvailability = { [weak self] in self?.model.shortcutNotice = $0 }
        shortcutController.onPress = { [weak self] in self?.model.receivedShortcut() }
        do { try shortcutController.install(model.shortcut) } catch { model.error = error.localizedDescription }
        model.onShortcutRequest = { [weak self] shortcut in
            guard let self else { return }
            self.shortcutCaptureMonitor.stop()
            try self.shortcutController.install(shortcut)
            self.recordMenuItem?.title = "Start / Stop Dictation    \(shortcut.display)"
            self.statusItem?.button?.toolTip = "PashaWhisper · \(shortcut.display) to dictate"
        }
        model.onShortcutCapture = { [weak self] capturing in
            guard let self else { return }
            if capturing {
                self.shortcutController.suspend(); self.shortcutRecorder.reset()
                self.model.shortcutDraft = self.shortcutRecorder.preview
                let direct = self.shortcutCaptureMonitor.start { [weak self] event in self?.captureShortcut(event) }
                self.model.shortcutCaptureHint = direct ? "Listening to keyboard and native shortcut events. Press and release your shortcut." : "Listening to native shortcuts and keys in this window. Accessibility enables additional key combinations."
            } else {
                self.shortcutCaptureMonitor.stop()
                do { try self.shortcutController.install(self.model.shortcut) } catch { self.model.error = error.localizedDescription }
            }
        }
        model.onWillRecord = { [weak self] in self?.anchor.capture(); self?.delivery.capture() }
        model.onDeliver = { [weak self] transcript in
            guard let self else { return "Automatic delivery is unavailable. Copy your transcript." }
            // The assigned shortcut itself may be Command-V. Let the destination
            // receive our Paste instead of intercepting it as a new recording.
            self.shortcutController.suspend()
            let result = self.delivery.deliver(transcript.text, session: transcript.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self, !self.model.capturingShortcut else { return }
                do { try self.shortcutController.install(self.model.shortcut) }
                catch { self.model.error = error.localizedDescription }
            }
            return result
        }
        model.onNeedsAttention = { [weak self] in self?.showWindow() }
        model.onOverlayChange = { [weak self] delay in
            guard let self else { return }
            if delay == 0 { self.previewEnd?.cancel(); self.hideOverlay(); return }
            self.showOverlay()
            if let delay {
                let work = DispatchWorkItem { [weak self] in self?.hideOverlay() }
                self.previewEnd = work; DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
            }
        }
        model.onPreviewOverlay = { [weak self] in self?.previewOverlay() }
        model.onRecordingChange = { [weak self] active in
            guard let self else { return }
            self.statusItem?.button?.contentTintColor = active ? .systemRed : nil
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self else { return event }
            if [.leftMouseDown, .rightMouseDown, .otherMouseDown].contains(event.type) {
                self.model.keyboardNavigation = false
                return event
            }
            if event.type == .keyDown, event.keyCode == 48, !self.model.capturingShortcut {
                self.model.keyboardNavigation = true
            }
            if self.model.capturingShortcut {
                self.captureShortcut(event)
                return nil
            }
            if event.type == .keyDown, event.keyCode == 53, !self.model.shortcut.keys.contains(53), self.model.busy { self.model.cancel(); return nil }
            return event
        }
        if let index = CommandLine.arguments.firstIndex(of: "--section"), CommandLine.arguments.count > index + 1 {
            let section = CommandLine.arguments[index + 1]
            if ["Dictation", "Models", "Providers", "Shortcuts", "Privacy"].contains(section) { model.section = section }
        }
        if CommandLine.arguments.contains("--test-shortcut") { model.section = "Shortcuts"; model.beginShortcutTest() }
        model.refreshPermissions()
        if model.needsSetup { model.section = "Setup" }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.model.refreshPermissions(); self.shortcutController.refreshPermission()
            }
        }
        showWindow()
    }
    private func captureShortcut(_ event: NSEvent) {
        guard model.capturingShortcut else { return }
        if let candidate = shortcutRecorder.observe(event) { model.setShortcut(candidate) }
        else { model.shortcutDraft = shortcutRecorder.preview }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    @objc func toggle() { model.toggleRecording() }
    @objc func cancelRecording() { model.cancel() }
    @objc func showWindow() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "PashaWhisper"
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(red: 0.95, green: 0.92, blue: 0.87, alpha: 1)
            window.minSize = NSSize(width: 940, height: 700)
            window.contentView = NSHostingView(rootView: MainView().environmentObject(model))
            window.isReleasedWhenClosed = false; window.delegate = self
            window.center(); self.window = window
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
    private func showOverlay(preview: Bool = false) {
        previewEnd?.cancel(); overlayTimer?.invalidate()
        let size = NSSize(width: 292, height: 64)
        if overlay == nil {
            let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.hasShadow = true; panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            overlay = panel
        }
        overlay?.contentView = NSHostingView(rootView: RecordingOverlay(preview: preview).environmentObject(model))
        overlay?.setContentSize(size)
        positionOverlay(); overlay?.orderFrontRegardless()
        if !preview {
            overlayTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.positionOverlay() }
            }
        }
    }
    private func positionOverlay() {
        let rect = anchor.rect()
        let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY)) }) ?? NSScreen.main
        guard let screen else { return }
        overlay?.setFrameOrigin(OverlayPlacement.origin(anchor: rect, screen: screen.visibleFrame, size: CGSize(width: 292, height: 64)))
    }
    private func hideOverlay() { overlayTimer?.invalidate(); overlayTimer = nil; overlay?.orderOut(nil) }
    private func previewOverlay() {
        guard !model.busy else { return }
        anchor.capture(); showOverlay(preview: true)
        let work = DispatchWorkItem { [weak self] in self?.hideOverlay() }
        previewEnd = work; DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: work)
    }
    func applicationDidResignActive(_ notification: Notification) { model.keyboardNavigation = false; model.cancelShortcutCapture() }
    func applicationDidBecomeActive(_ notification: Notification) { model.refreshPermissions(); shortcutController.refreshPermission() }
    func windowWillClose(_ notification: Notification) { model.testingShortcut = false; if model.capturingShortcut { model.cancelShortcutCapture() } }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.shutdown(); return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate(); permissionTimer = nil
        model.shutdown(); shortcutCaptureMonitor.stop(); shortcutController.shutdown(); hideOverlay()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

}

@main
struct PashaWhisperMain {
    @MainActor static func main() {
        // Exercise exactly the app's transcription service without accessing the microphone.
        if let index = CommandLine.arguments.firstIndex(of: "--self-test-audio"), CommandLine.arguments.count > index + 1 {
            Task { @MainActor in
            do {
                try AppPaths.prepare()
                let model = LocalModel.catalog[0]
                let request = TranscriptionRequest(audio: URL(fileURLWithPath: CommandLine.arguments[index + 1]), model: model,
                    provider: "Offline", endpoint: "", apiModel: "", key: "", language: "en", suppression: .normal)
                let result = try await Transcriber.transcribe(request)
                print(TranscriptFilter.clean(result, mode: .normal))
                exit(0)
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
            }
            dispatchMain()
        }
        let app = NSApplication.shared
        if let existing = NSRunningApplication.runningApplications(withBundleIdentifier: "com.pasha.whisper").first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(); return
        }
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
