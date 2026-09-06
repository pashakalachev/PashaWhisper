import Foundation
import AVFoundation
import AppKit
import Security
import CryptoKit
import WhisperCore

enum AppPaths {
    static var support: URL {
        if let path = ProcessInfo.processInfo.environment["PASHAWHISPER_DATA_DIR"] { return URL(fileURLWithPath: path) }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PashaWhisper")
    }
    static var recordings: URL { support.appendingPathComponent("Transient") }
    static var models: URL { support.appendingPathComponent("Models") }
    static var runtime: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers") }
    static var vad: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/ggml-silero.bin") }
    static func removeLegacyHistory() throws {
        let history = support.appendingPathComponent("history.json")
        if FileManager.default.fileExists(atPath: history.path) { try FileManager.default.removeItem(at: history) }
        let legacy = support.appendingPathComponent("Recordings")
        if FileManager.default.fileExists(atPath: legacy.path) { try FileManager.default.removeItem(at: legacy) }
        UserDefaults.standard.removeObject(forKey: "retention")
    }
    static func clearTransientAudio() throws {
        for url in try FileManager.default.contentsOfDirectory(at: recordings, includingPropertiesForKeys: nil) where url.pathExtension == "wav" {
            try FileManager.default.removeItem(at: url)
        }
    }
    static func prepare() throws {
        for path in [support, recordings, models] {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            var url = path; var values = URLResourceValues(); values.isExcludedFromBackup = true
            try url.setResourceValues(values)
        }
    }
}

enum Keychain {
    static func load(account: String) -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pasha.whisper", kSecAttrAccount as String: account,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
    static func save(_ value: String, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pasha.whisper", kSecAttrAccount as String: account]
        if value.isEmpty { SecItemDelete(query as CFDictionary); return }
        let data = Data(value.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query; insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(insert as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw AppFailure.message("Could not save the API key in Keychain (\(status)).") }
    }
}

final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    var duration: TimeInterval { recorder?.currentTime ?? 0 }
    var level: Float { recorder?.updateMeters(); return max(0, min(1, pow(10, (recorder?.averagePower(forChannel: 0) ?? -80) / 20) * 5)) }
    func start(url: URL) throws {
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        let value = try AVAudioRecorder(url: url, settings: settings)
        value.isMeteringEnabled = true
        guard value.prepareToRecord(), value.record() else { throw AppFailure.message("The microphone could not start. Check microphone access and your input device.") }
        recorder = value
    }
    func stop() { recorder?.stop(); recorder = nil }
}

// No pipe can fill and deadlock a long transcription. Logs stay in a private temporary directory.
final class ProcessRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var canceled = false
    func cancel() {
        lock.lock(); canceled = true; let current = process; lock.unlock()
        if let current, current.isRunning { current.terminate() }
    }
    func run(_ executable: URL, arguments: [String], log: URL) async throws -> String {
        try await withTaskCancellationHandler(operation: {
            try await Task.detached(priority: .userInitiated) { [self] in
                let proc = Process()
                proc.executableURL = executable; proc.arguments = arguments
                let env = ProcessInfo.processInfo.environment
                proc.environment = env
                FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600])
                let output = try FileHandle(forWritingTo: log)
                defer { try? output.close() }
                proc.standardOutput = output; proc.standardError = output
                try lock.withLock {
                    if canceled { throw CancellationError() }
                    process = proc
                    try proc.run()
                }
                proc.waitUntilExit()
                let wasCanceled = lock.withLock { process = nil; return canceled }
                if wasCanceled { throw CancellationError() }
                guard proc.terminationStatus == 0 else { throw AppFailure.message("The local speech engine stopped (code \(proc.terminationStatus)). Your recording is available to retry.") }
                return (try? String(contentsOf: log, encoding: .utf8)) ?? ""
            }.value
        }, onCancel: { self.cancel() })
    }
}

final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

struct TranscriptionRequest {
    let audio: URL
    let model: LocalModel
    let provider: String
    let endpoint: String
    let apiModel: String
    let key: String
    let language: String
    let suppression: Suppression
}

enum Transcriber {
    static func transcribe(_ request: TranscriptionRequest) async throws -> String {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("pasha-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: temp) }
        let runner = ProcessRunner()
        let threshold = request.suppression == .strong ? "0.65" : "0.5"
        if request.suppression != .off {
            let result = try await runner.run(AppPaths.runtime.appendingPathComponent("whisper-vad-speech-segments"),
                arguments: ["-vm", AppPaths.vad.path, "-f", request.audio.path, "-vt", threshold, "-vp", "200", "-np"],
                log: temp.appendingPathComponent("vad.log"))
            guard result.contains("Detected ") && result.contains("speech segments:") else {
                throw AppFailure.message("Speech detection returned an unexpected result. The recording was kept.")
            }
            if result.contains("Detected 0 speech segments:") { return "" }
        }
        try Task.checkCancellation()
        if request.provider == "Offline" {
            let output = temp.appendingPathComponent("transcript")
            var args = ["-m", AppPaths.models.appendingPathComponent(request.model.filename).path,
                        "-f", request.audio.path, "-otxt", "-of", output.path, "-l", request.model.id.contains(".en") ? "en" : request.language,
                        "-nt", "-np", "-t", "4"]
            if request.suppression != .off {
                args += ["--vad", "-vm", AppPaths.vad.path, "-vt", threshold, "-vp", "200", "-sns"]
            }
            _ = try await runner.run(AppPaths.runtime.appendingPathComponent("whisper-cli"), arguments: args, log: temp.appendingPathComponent("engine.log"))
            return try String(contentsOf: output.appendingPathExtension("txt"), encoding: .utf8)
        }
        let endpoint = try EndpointPolicy.validate(request.endpoint)
        let audio = try Data(contentsOf: request.audio)
        guard audio.count < 25_000_000 else { throw AppFailure.message("This recording exceeds the first build's 25 MB API limit. Retry with an offline model. Automatic cloud chunking is coming later.") }
        let boundary = "Pasha-\(UUID().uuidString)"
        var http = URLRequest(url: endpoint)
        http.httpMethod = "POST"; http.timeoutInterval = 300
        http.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if !request.key.isEmpty { http.setValue("Bearer \(request.key)", forHTTPHeaderField: "Authorization") }
        http.httpBody = Multipart.audio(data: audio, model: request.apiModel, language: request.language, openAI: request.provider == "OpenAI", boundary: boundary)
        let session = URLSession(configuration: .ephemeral, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: http)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw AppFailure.message("The provider did not return an HTTP response.") }
        guard (200..<300).contains(status) else {
            let message: String
            switch status {
            case 401, 403: message = "The provider rejected the API key. Check it in Providers."
            case 429: message = "The provider is rate-limiting requests or has no available credit. Try again later."
            case 300..<400: message = "The endpoint redirects. Enter its final HTTPS transcription URL in Providers."
            default: message = "The transcription provider returned HTTP \(status). Your recording was kept."
            }
            throw AppFailure.message(message)
        }
        struct Response: Decodable { let text: String }
        return try JSONDecoder().decode(Response.self, from: data).text
    }
}

final class ModelDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var progress: ((Double) -> Void)?
    private let lock = NSLock()
    private var canceled = false
    func cancel() { lock.lock(); canceled = true; let task = task; lock.unlock(); task?.cancel() }
    func download(_ url: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock(); defer { lock.unlock() }
                if canceled { continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation; self.progress = progress
                let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
                self.session = session; self.task = session.downloadTask(with: url); self.task?.resume()
            }
        }, onCancel: { self.cancel() })
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 { progress?(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let status = (downloadTask.response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
                throw AppFailure.message("The model server could not provide the download. Try again later.")
            }
            let saved = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.moveItem(at: location, to: saved)
            continuation?.resume(returning: saved); continuation = nil
        } catch { continuation?.resume(throwing: error); continuation = nil }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { continuation?.resume(throwing: error); continuation = nil }
        session.finishTasksAndInvalidate(); self.session = nil
    }
    static func verify(_ url: URL, expected: String) throws {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = Insecure.SHA1()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == expected else {
            throw AppFailure.message("The downloaded model failed its integrity check. It was not installed.")
        }
    }
}
