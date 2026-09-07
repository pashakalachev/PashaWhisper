import AppKit
import AVFoundation
import Combine
import WhisperCore

@MainActor
final class AppModel: ObservableObject {
    @Published var section = "Dictation"
    @Published var keyboardNavigation = false
    @Published var status = "Ready when you are."
    @Published var detail = "Your words. Your machine."
    @Published var recording = false
    @Published var preparing = false
    @Published var transcribing = false
    @Published var elapsed: TimeInterval = 0
    @Published var level: Float = 0
    @Published var levels = Array(repeating: Float(0), count: 22)
    @Published var latest: Transcript?
    @Published var retryAvailable = false
    @Published var overlayTitle = "PREPARING"
    @Published var overlayDetail = ""
    @Published var processingSeconds: TimeInterval?
    @Published var shortcut: KeyboardShortcut
    @Published var capturingShortcut = false
    @Published var shortcutDraft = "Press and release your shortcut…"
    @Published var shortcutNotice: String?
    @Published var shortcutCaptureHint = ""
    @Published var testingShortcut = false
    @Published var shortcutTestCount = 0
    @Published var permissions = PermissionState.current()
    @Published var setupCompleted = UserDefaults.standard.bool(forKey: "setupCompleted")
    @Published var permissionRequested = false
    var accessibilityGranted: Bool { permissions.accessibility }
    var autoPasteReady: Bool { permissions.autoPasteReady }
    var needsSetup: Bool { !setupCompleted || !permissions.ready }
    var appLocation: String { Bundle.main.bundleURL.path }
    @Published var installed: Set<String> = []
    @Published var downloading: String?
    @Published var downloadProgress = 0.0
    @Published var downloadStatus = ""
    @Published var error: String?
    @Published var selectedModel: String { didSet { UserDefaults.standard.set(selectedModel, forKey: "model") } }
    @Published var provider: String { didSet { UserDefaults.standard.set(provider, forKey: "provider") } }
    @Published var language: String { didSet { UserDefaults.standard.set(language, forKey: "language") } }
    @Published var suppression: Suppression { didSet { UserDefaults.standard.set(suppression.rawValue, forKey: "suppression") } }
    @Published var endpoint: String { didSet { UserDefaults.standard.set(endpoint, forKey: "endpoint") } }
    @Published var apiModel: String { didSet { UserDefaults.standard.set(apiModel, forKey: "apiModel") } }
    private let permissionReader: () -> PermissionState
    private let recorder = AudioRecorder()
    private var timer: Timer?
    private var sessionID: UUID?
    private var currentAudio: URL?
    private var operation: Task<Void, Never>?
    private var downloadOperation: Task<Void, Never>?
    private var storageFailed = false
    var onRecordingChange: ((Bool) -> Void)?
    var onOverlayChange: ((TimeInterval?) -> Void)?
    var onNeedsAttention: (() -> Void)?
    var onDeliver: ((Transcript) -> String?)?
    var onWillRecord: (() -> Void)?
    var onShortcutRequest: ((KeyboardShortcut) throws -> Void)?
    var onShortcutCapture: ((Bool) -> Void)?
    var onPreviewOverlay: (() -> Void)?
    var busy: Bool { recording || transcribing || preparing }
    var model: LocalModel { LocalModel.catalog.first(where: { $0.id == selectedModel }) ?? LocalModel.catalog[0] }
    var providerLabel: String { provider == "Offline" ? "\(model.title) · \(model.precision)" : provider }
    var actualEndpoint: String { provider == "OpenAI" ? "https://api.openai.com/v1/audio/transcriptions" : endpoint }
    var actualAPIModel: String { provider == "OpenAI" ? "gpt-transcribe" : apiModel }
    var keyAccount: String { "api:\(actualEndpoint)" }
    var readinessIssue: String? {
        if storageFailed { return "Recording storage is unavailable. Restart the app after checking free disk space." }
        if provider == "Offline" {
            guard LocalModel.catalog.contains(where: { $0.id == selectedModel }), installed.contains(selectedModel) else {
                return "Download or select an installed model in Models before recording."
            }
        }
        return nil
    }
    func showOverlay(_ title: String, _ message: String, dismissAfter: TimeInterval? = nil) {
        overlayTitle = title; overlayDetail = message; onOverlayChange?(dismissAfter)
    }
    private func needsAttention(_ message: String, section: String, title: String = "SETUP NEEDED") {
        self.section = section; error = message; status = "Dictation needs attention."; detail = message
        showOverlay(title, message, dismissAfter: 8); onNeedsAttention?()
    }

    init(permissionReader: @escaping () -> PermissionState = PermissionState.current) {
        self.permissionReader = permissionReader
        let defaults = UserDefaults.standard
        selectedModel = defaults.string(forKey: "model") ?? "tiny.en-q5_1"
        provider = defaults.string(forKey: "provider") ?? "Offline"
        language = defaults.string(forKey: "language") ?? "auto"
        suppression = Suppression(rawValue: defaults.string(forKey: "suppression") ?? "Normal") ?? .normal
        endpoint = defaults.string(forKey: "endpoint") ?? "http://localhost:8080/v1/audio/transcriptions"
        apiModel = defaults.string(forKey: "apiModel") ?? "whisper-1"
        let saved = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(KeyboardShortcut.self, from: $0) }
        shortcut = saved?.isValid == true ? saved! : .standard
        permissions = permissionReader()
        do {
            try AppPaths.prepare()
            try AppPaths.removeLegacyHistory()
            try AppPaths.clearTransientAudio()
            let seed = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/ggml-tiny.en-q5_1.bin")
            let target = AppPaths.models.appendingPathComponent(LocalModel.catalog[0].filename)
            if !FileManager.default.fileExists(atPath: target.path), FileManager.default.fileExists(atPath: seed.path) {
                try ModelDownload.verify(seed, expected: LocalModel.catalog[0].sha1)
                try FileManager.default.copyItem(at: seed, to: target)
            }
        } catch { self.error = "Storage could not be prepared: \(error.localizedDescription)"; storageFailed = true }
        refreshModels()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.interruptRecording() }
        }
    }
    func refreshModels() { installed = Set(LocalModel.catalog.filter { FileManager.default.fileExists(atPath: AppPaths.models.appendingPathComponent($0.filename).path) }.map(\.id)) }
    func beginShortcutCapture() { guard !busy else { return }; testingShortcut = false; error = nil; capturingShortcut = true; onShortcutCapture?(true) }
    func cancelShortcutCapture() { guard capturingShortcut else { return }; capturingShortcut = false; onShortcutCapture?(false) }
    func setShortcut(_ candidate: KeyboardShortcut) {
        testingShortcut = false; shortcutTestCount = 0
        guard candidate.isValid else { error = "Press a key or combination of keys."; return }
        do {
            try onShortcutRequest?(candidate)
            shortcut = candidate; UserDefaults.standard.set(try JSONEncoder().encode(candidate), forKey: "shortcut")
            capturingShortcut = false; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func refreshPermissions() {
        let current = permissionReader()
        if permissions != current { permissions = current }
    }
    func requestAccessibility() {
        refreshPermissions()
        guard !autoPasteReady else { return }
        permissionRequested = true
        if !permissions.accessibility {
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        } else if !permissions.eventPosting { _ = CGRequestPostEventAccess() }
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        refreshPermissions()
    }
    func requestMicrophone() {
        refreshPermissions()
        guard autoPasteReady else { return }
        if permissions.microphone == .notDetermined {
            Task { _ = await AVCaptureDevice.requestAccess(for: .audio); refreshPermissions() }
        } else if permissions.microphone != .authorized {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }
    func finishSetup() {
        refreshPermissions()
        guard permissions.ready else { return }
        setupCompleted = true; UserDefaults.standard.set(true, forKey: "setupCompleted")
        section = "Dictation"; error = nil
    }
    func revealRunningApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    func receivedShortcut() {
        if testingShortcut { shortcutTestCount += 1; return }
        toggleRecording()
    }
    func beginShortcutTest() {
        guard !busy, !capturingShortcut else { return }
        shortcutTestCount = 0; testingShortcut = true
    }
    func toggleRecording() {
        testingShortcut = false
        guard !capturingShortcut else { return }
        if recording { stopAndTranscribe() }
        else if !busy {
            refreshPermissions()
            guard permissions.ready else {
                needsAttention(autoPasteReady ? "Allow microphone access in Setup before dictating." : "Allow automatic paste in Setup before dictating.", section: "Setup")
                return
            }
            onWillRecord?()
            processingSeconds = nil
            let id = UUID(); sessionID = id; preparing = true
            operation = Task { await startRecording(id: id) }
        }
    }
    private func startRecording(id: UUID) async {
        defer { if sessionID == id { preparing = false } }
        guard !recording, !transcribing, sessionID == id else { return }
        error = nil
        refreshModels()
        if let issue = readinessIssue { needsAttention(issue, section: storageFailed ? "Privacy" : "Models"); return }
        if provider == "OpenAI" && Keychain.load(account: keyAccount).isEmpty {
            needsAttention("Save your OpenAI API key before recording.", section: "Providers"); return
        }
        do { try Transcriber.validate(makeRequest(audio: AppPaths.recordings.appendingPathComponent("preflight.wav"))) }
        catch { needsAttention(error.localizedDescription, section: provider == "Offline" ? "Models" : "Providers"); return }
        status = "Checking microphone…"
        showOverlay("PREPARING", "Checking microphone access…")
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard !Task.isCancelled, sessionID == id else { return }
        guard allowed else { needsAttention("Allow PashaWhisper in System Settings → Privacy & Security → Microphone.", section: "Privacy"); return }
        discardAudio(); latest = nil
        let audio = AppPaths.recordings.appendingPathComponent("\(id.uuidString).wav")
        do {
            try recorder.start(url: audio)
            currentAudio = audio; recording = true; elapsed = 0; levels = Array(repeating: 0, count: 22)
            status = "Listening. Take your time."
            detail = provider == "Offline" ? providerLabel : "Will send audio to \(provider) when you stop."
            timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.recording else { return }
                    self.elapsed = self.recorder.duration; self.level = self.recorder.level
                    self.levels.removeFirst(); self.levels.append(self.level)
                }
            }
            onRecordingChange?(true)
            showOverlay("RECORDING", providerLabel)
        } catch { needsAttention(error.localizedDescription, section: "Privacy", title: "MICROPHONE ERROR"); try? FileManager.default.removeItem(at: audio) }
    }
    func stopAndTranscribe() {
        guard recording, let audio = currentAudio, let id = sessionID else { return }
        elapsed = recorder.duration; recorder.stop(); timer?.invalidate(); timer = nil
        recording = false; transcribing = true; level = 0; onRecordingChange?(false)
        operation = Task { await process(audio, id: id, duration: elapsed) }
    }
    func retryCurrent() {
        guard !busy, let audio = currentAudio, retryAvailable else { return }
        if provider == "Offline" && !installed.contains(selectedModel) { section = "Models"; error = "Select an installed model first."; return }
        let id = UUID(); sessionID = id; transcribing = true
        operation = Task { await process(audio, id: id, duration: elapsed) }
    }
    private func makeRequest(audio: URL) -> TranscriptionRequest {
        TranscriptionRequest(audio: audio, model: model, provider: provider, endpoint: actualEndpoint,
            apiModel: actualAPIModel, key: provider == "Offline" ? "" : Keychain.load(account: keyAccount), language: language, suppression: suppression)
    }
    private func process(_ audio: URL, id: UUID, duration: TimeInterval) async {
        guard !storageFailed, !Task.isCancelled, sessionID == id else { return }
        transcribing = true; retryAvailable = false; error = nil
        status = "Turning sound into words…"; detail = "Processing with \(providerLabel)."
        let providerName = providerLabel
        let request = makeRequest(audio: audio)
        let started = Date()
        showOverlay("TRANSCRIBING", providerName)
        defer {
            if sessionID == id {
                transcribing = false
                if !retryAvailable { discardAudio() }
            } else { try? FileManager.default.removeItem(at: audio) }
        }
        do {
            let raw = try await Transcriber.transcribe(request)
            try Task.checkCancellation(); guard sessionID == id else { return }
            processingSeconds = Date().timeIntervalSince(started)
            let text = TranscriptFilter.clean(raw, mode: request.suppression)
            guard !text.isEmpty else {
                status = "No speech detected."; detail = "Nothing pasted. Check your microphone or speech filtering if you spoke."
                showOverlay("NO SPEECH DETECTED", "Check microphone and speech filtering.", dismissAfter: 6); return
            }
            let transcript = Transcript(id: id, text: text, rawText: raw, provider: providerName, duration: duration)
            latest = transcript
            showOverlay("PASTING", "Sending your transcript…")
            let deliveryProblem: String?
            if let onDeliver { deliveryProblem = onDeliver(transcript) }
            else { deliveryProblem = "Automatic delivery is unavailable. Copy the transcript below." }
            if let problem = deliveryProblem {
                status = "Transcript ready to copy."; detail = problem; section = "Dictation"
                showOverlay("TRANSCRIPT READY", "Open PashaWhisper to copy.", dismissAfter: 7)
                onNeedsAttention?()
            } else {
                status = "Paste sent to your text field."
                detail = "The transcript is also available below and on the clipboard."
                showOverlay("PASTE SENT", "Transcript kept for recovery.", dismissAfter: 2)
            }
        } catch is CancellationError {
            if sessionID == id { status = "Transcription canceled."; detail = "Nothing copied." }
        } catch {
            if sessionID == id { self.error = error.localizedDescription; status = "Transcription needs another try."; detail = "Retry this recording below before you quit or start another."; retryAvailable = true
                section = "Dictation"; showOverlay("TRANSCRIPTION FAILED", "Open PashaWhisper to retry.", dismissAfter: 8); onNeedsAttention?() }
        }
    }
    func discardAudio() {
        if let audio = currentAudio { try? FileManager.default.removeItem(at: audio) }
        currentAudio = nil; retryAvailable = false
    }
    func clearCurrent() { guard !busy else { return }; latest = nil; discardAudio(); status = "Ready when you are."; detail = "Current result cleared." }
    func cancel() {
        operation?.cancel(); recorder.stop(); timer?.invalidate(); timer = nil
        sessionID = nil; recording = false; preparing = false; transcribing = false; level = 0
        onRecordingChange?(false); discardAudio()
        status = "Canceled."; detail = "Recording deleted. Nothing copied."
        showOverlay("CANCELED", "Recording deleted.", dismissAfter: 0)
    }
    func shutdown() { cancel(); latest = nil; try? AppPaths.clearTransientAudio() }
    func interruptRecording() { guard recording else { return }; cancel(); status = "Recording stopped by sleep." }
    func copy(_ transcript: Transcript) {
        guard !transcript.text.isEmpty else { return }
        let clipboard = NSPasteboard.general; clipboard.clearContents()
        guard clipboard.setString(transcript.text, forType: .string), clipboard.string(forType: .string) == transcript.text else {
            error = "The clipboard could not be updated. The current result is still available below."; return
        }
        status = "Copied. Ready to paste."; detail = "The clipboard contains this transcript."
    }
    func download(_ model: LocalModel) {
        guard downloading == nil else { return }
        downloading = model.id; downloadProgress = 0; downloadStatus = "Downloading…"; error = nil
        downloadOperation = Task {
            defer { downloading = nil; refreshModels() }
            do {
                let downloader = ModelDownload()
                let url = try await downloader.download(model.url) { [weak self] progress in
                    Task { @MainActor in self?.downloadProgress = progress }
                }
                defer { try? FileManager.default.removeItem(at: url) }
                downloadStatus = "Checking integrity…"
                try await Task.detached { try ModelDownload.verify(url, expected: model.sha1) }.value
                try Task.checkCancellation()
                let destination = AppPaths.models.appendingPathComponent(model.filename)
                if !FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.moveItem(at: url, to: destination) }
                downloadStatus = "Installed"; selectedModel = model.id
            } catch is CancellationError { downloadStatus = "Canceled" }
            catch let error as URLError where error.code == .cancelled { downloadStatus = "Canceled" }
            catch { self.error = error.localizedDescription; downloadStatus = "Download failed" }
        }
    }
    func cancelDownload() { downloadOperation?.cancel() }
    func deleteModel(_ model: LocalModel) {
        guard !busy, model.id != selectedModel else { return }
        do { try FileManager.default.removeItem(at: AppPaths.models.appendingPathComponent(model.filename)); refreshModels() }
        catch { self.error = error.localizedDescription }
    }
}
