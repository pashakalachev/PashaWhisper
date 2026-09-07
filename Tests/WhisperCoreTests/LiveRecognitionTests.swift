import XCTest
import AVFoundation
import WhisperCore
@testable import PashaWhisper

final class LiveRecognitionTests: XCTestCase {
    func testForcedBoundariesPreserveEverySampleAndOnlyOverlapOnce() {
        let samples = (0..<650_017).map { Float($0 % 1000) / 1000 + 0.02 }
        var chunker = SpeechChunker(); var chunks: [SpeechChunk] = []
        for offset in stride(from: 0, to: samples.count, by: 731) {
            chunks += chunker.append(Array(samples[offset..<min(samples.count, offset + 731)]))
        }
        if let final = chunker.finish() { chunks.append(final) }
        let restored = chunks.flatMap { $0.overlapsPrevious ? Array($0.samples.dropFirst(16000)) : $0.samples }
        XCTAssertEqual(restored, samples)
        XCTAssertGreaterThan(chunks.count, 2)
        XCTAssertNil(chunker.finish())
    }
    func testPauseEmitsDuringRecordingAndTailIsRetained() {
        var chunker = SpeechChunker()
        let speech = Array(repeating: Float(0.2), count: 40_000)
        XCTAssertTrue(chunker.append(speech).isEmpty)
        let chunks = chunker.append(Array(repeating: Float(0), count: 9_600))
        XCTAssertEqual(chunks.count, 1); XCTAssertFalse(chunks[0].overlapsPrevious)
        let tail = chunker.finish()!
        XCTAssertEqual(chunks[0].samples.count + tail.samples.count, 49_600)
    }
    func testJoinOnlyRemovesExplicitOverlap() {
        XCTAssertEqual(TranscriptJoiner.append("hello again today", to: "Well, hello again.", overlapping: true), "Well, hello again. today")
        XCTAssertEqual(TranscriptJoiner.append("hello again today", to: "Well, hello again.", overlapping: false), "Well, hello again. hello again today")
        XCTAssertEqual(TranscriptJoiner.append("yes please", to: "yes", overlapping: true), "yes yes please")
    }
    func testRecognitionBeginsBeforeStopAndResultsRemainOrdered() async throws {
        let began = expectation(description: "Recognized before stop")
        let background = BackgroundRecognition { samples in
            if samples.first == 0.2 { began.fulfill(); return "first phrase" }
            return "last words"
        }
        background.append(Array(repeating: 0.2, count: 40_000) + Array(repeating: 0, count: 9_600))
        await fulfillment(of: [began], timeout: 2)
        background.append(Array(repeating: 0.4, count: 20_000))
        let result = try await background.finish()
        XCTAssertEqual(result, "first phrase last words")
    }
    func testCancellationNeverReturnsPartialText() async throws {
        let background = BackgroundRecognition { _ in try await Task.sleep(nanoseconds: 5_000_000_000); return "must not paste" }
        background.append(Array(repeating: 0.2, count: 40_000))
        let finishing = Task { try await background.finish() }
        finishing.cancel()
        do { _ = try await finishing.value; XCTFail("Canceled result was delivered") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }
    func testCancelAlsoBlocksAnAlreadyCompletedResult() async throws {
        let recognition = BackgroundRecognition { _ in "already done" }
        recognition.append(Array(repeating: 0.2, count: 40000))
        _ = try await recognition.finish()
        recognition.cancel()
        do { _ = try await recognition.finish(); XCTFail("Canceled result was returned") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
    }
    func testDigitalSilenceTailNeedsNoEngineProcess() async throws {
        let request = TranscriptionRequest(audio: URL(fileURLWithPath: "/unused.wav"), model: LocalModel.catalog[0], provider: "Offline", endpoint: "", apiModel: "", key: "", language: "en", suppression: .normal)
        let recognition = BackgroundRecognition.forRequest(request)
        recognition.append(Array(repeating: 0, count: 32001))
        let text = try await recognition.finish()
        XCTAssertTrue(text.isEmpty)
    }
    func testStereo48KConversionAndStopFlushMatchSavedAudio() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)!
        var captured: [Float] = []
        let sink = try AudioCaptureSink(url: url, inputFormat: format) { captured += $0 }
        for offset in stride(from: 0, to: 48000, by: 2048) {
            let count = min(2048, 48000-offset)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(count))!
            buffer.frameLength = UInt32(count)
            for channel in 0..<2 { for i in 0..<count { buffer.floatChannelData![channel][i] = sin(Float(offset+i) * 0.03) * 0.1 } }
            sink.consume(buffer)
        }
        sink.finish(); sink.finish()
        XCTAssertNil(sink.captureFailure)
        let saved = try AVAudioFile(forReading: url)
        XCTAssertEqual(saved.fileFormat.sampleRate, 16000)
        XCTAssertEqual(saved.fileFormat.channelCount, 1)
        XCTAssertEqual(Int(saved.length), captured.count)
        XCTAssertEqual(captured.count, 16000, accuracy: 32)
        XCTAssertEqual(sink.duration, Double(captured.count) / 16000)
        let buffer = AVAudioPCMBuffer(pcmFormat: saved.processingFormat, frameCapacity: UInt32(saved.length))!
        try saved.read(into: buffer)
        for i in captured.indices { XCTAssertEqual(buffer.floatChannelData![0][i], captured[i], accuracy: 0.0001) }
    }
}
