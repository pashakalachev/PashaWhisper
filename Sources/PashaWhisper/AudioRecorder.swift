import AVFoundation
import Foundation
import WhisperCore

/// Converts once: exactly the saved recovery samples also feed background ASR.
final class AudioCaptureSink: @unchecked Sendable {
    private let lock = NSLock()
    private var writer: AVAudioFile?
    private let converter: AVAudioConverter
    private let target: AVAudioFormat
    private let onSamples: (([Float]) -> Void)?
    private var sampleCount = 0
    private var meter: Float = 0
    private var failure: String?
    private var accepting = true
    var duration: TimeInterval { lock.withLock { Double(sampleCount) / 16000 } }
    var level: Float { lock.withLock { meter } }
    var captureFailure: String? { lock.withLock { failure } }

    init(url: URL, inputFormat: AVAudioFormat, onSamples: (([Float]) -> Void)?) throws {
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: target) else {
            throw AppFailure.message("The microphone has no usable input format. Check your input device.")
        }
        self.converter = converter; self.target = target; self.onSamples = onSamples
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false]
        writer = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    }
    func consume(_ input: AVAudioPCMBuffer) {
        lock.withLock {
            guard accepting, failure == nil else { return }
            let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * 16000 / input.format.sampleRate)) + 64
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var supplied = false; var error: NSError?
            let status = converter.convert(to: output, error: &error) { _, state in
                if supplied { state.pointee = .noDataNow; return nil }
                supplied = true; state.pointee = .haveData; return input
            }
            guard status != .error, error == nil else {
                failure = "Microphone conversion failed. The recording was kept for recovery."; return
            }
            persist(output)
        }
    }
    private func persist(_ output: AVAudioPCMBuffer) {
        guard let writer, output.frameLength > 0, let channel = output.floatChannelData?[0] else { return }
        do {
            try writer.write(from: output)
            let samples = Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
            sampleCount += samples.count
            meter = min(1, sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)) * 5)
            onSamples?(samples)
        } catch { failure = "Could not save microphone audio: \(error.localizedDescription)" }
    }
    func finish() {
        lock.withLock {
            guard accepting else { return }; accepting = false
            // Flush resampler latency so the final samples are saved and decoded.
            if failure == nil, let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: 1024) {
                while true {
                    var error: NSError?
                    let status = converter.convert(to: output, error: &error) { _, state in state.pointee = .endOfStream; return nil }
                    if status == .error || error != nil { failure = "Could not finish converting microphone audio."; break }
                    persist(output)
                    if status == .endOfStream || output.frameLength == 0 { break }
                }
            }
            writer = nil; meter = 0
        }
    }
}

final class AudioRecorder {
    private var engine: AVAudioEngine?
    private var sink: AudioCaptureSink?
    var onSamples: (([Float]) -> Void)?
    var duration: TimeInterval { sink?.duration ?? 0 }
    var level: Float { sink?.level ?? 0 }
    var captureFailure: String? { sink?.captureFailure }
    func start(url: URL) throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let sink = try AudioCaptureSink(url: url, inputFormat: format, onSamples: onSamples)
        self.sink = sink; self.engine = engine
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in sink.consume(buffer) }
        do { engine.prepare(); try engine.start() }
        catch { stop(); throw AppFailure.message("The microphone could not start: \(error.localizedDescription)") }
    }
    func stop() {
        if let engine { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        sink?.finish(); engine = nil
    }
}
