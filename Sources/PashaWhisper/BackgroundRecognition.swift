import Foundation
import AVFoundation
import WhisperCore

/// One recognition job at a time. Capture never waits for the speech engine.
final class BackgroundRecognition: @unchecked Sendable {
    typealias Recognize = @Sendable ([Float]) async throws -> String
    private let lock = NSLock()
    private var chunker = SpeechChunker()
    private var jobs: [Task<Void, Error>] = []
    private var text = ""
    private var ended = false
    private var canceled = false
    private let recognize: Recognize
    init(recognize: @escaping Recognize) { self.recognize = recognize }

    static func forRequest(_ request: TranscriptionRequest) -> BackgroundRecognition {
        BackgroundRecognition { samples in
            // Digital silence cannot contain speech. Avoid starting a VAD
            // process solely to finalize an empty tail after the last phrase.
            if samples.allSatisfy({ abs($0) < 0.0000001 }) { return "" }
            let clip = AppPaths.recordings.appendingPathComponent("chunk-\(UUID().uuidString).wav")
            defer { try? FileManager.default.removeItem(at: clip) }
            try PCMFile.wav(samples: samples).write(to: clip, options: .atomic)
            let chunk = TranscriptionRequest(audio: clip, model: request.model, provider: request.provider,
                endpoint: request.endpoint, apiModel: request.apiModel, key: request.key,
                language: request.language, suppression: request.suppression)
            return TranscriptFilter.clean(try await Transcriber.transcribe(chunk), mode: request.suppression)
        }
    }
    static func transcribeFile(_ request: TranscriptionRequest) async throws -> String {
        let recognition = forRequest(request)
        do {
            let input = try AVAudioFile(forReading: request.audio)
            guard input.processingFormat.sampleRate == 16000, input.processingFormat.channelCount == 1,
                  let buffer = AVAudioPCMBuffer(pcmFormat: input.processingFormat, frameCapacity: 32000) else {
                throw AppFailure.message("The recording is not 16 kHz mono audio.")
            }
            while input.framePosition < input.length {
                try Task.checkCancellation()
                try input.read(into: buffer)
                guard buffer.frameLength > 0, let channel = buffer.floatChannelData?[0] else { break }
                recognition.append(Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
            }
            return try await recognition.finish()
        } catch { recognition.cancel(); throw error }
    }

    func append(_ samples: [Float]) {
        lock.withLock {
            guard !ended else { return }
            for chunk in chunker.append(samples) { enqueue(chunk) }
        }
    }
    private func enqueue(_ chunk: SpeechChunk) {
        let previous = jobs.last
        let job = Task { [self] in
            try await previous?.value
            try Task.checkCancellation()
            let result = try await recognize(chunk.samples)
            try Task.checkCancellation()
            lock.withLock { text = TranscriptJoiner.append(result, to: text, overlapping: chunk.overlapsPrevious) }
        }
        jobs.append(job)
    }
    func finish() async throws -> String {
        let last = lock.withLock {
            if !ended { ended = true; if let chunk = chunker.finish() { enqueue(chunk) } }
            return jobs.last
        }
        return try await withTaskCancellationHandler {
            try await last?.value
            try Task.checkCancellation()
            return try lock.withLock {
                if canceled { throw CancellationError() }
                return text
            }
        } onCancel: { self.cancel() }
    }
    func cancel() {
        lock.withLock { canceled = true; ended = true; jobs.forEach { $0.cancel() } }
    }
}
