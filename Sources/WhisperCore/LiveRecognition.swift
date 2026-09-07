import Foundation

public struct SpeechChunk {
    public let samples: [Float]
    public let overlapsPrevious: Bool
}

/// Phrase-sized background jobs; retain a short overlap at forced boundaries.
/// Every captured sample is included. Quiet audio is filtered by the existing VAD.
public struct SpeechChunker {
    private var pending: [Float] = []
    private var quietSamples = 0
    private var overlap = false
    private var analysisCount = 0
    private var energy: Float = 0
    public init() {}
    public mutating func append(_ samples: [Float]) -> [SpeechChunk] {
        var chunks: [SpeechChunk] = []
        // Fixed 20ms analysis windows avoid making segmentation depend on tap size.
        for value in samples {
            pending.append(value)
            energy += value * value; analysisCount += 1
            if analysisCount == 320 {
                quietSamples = energy / 320 < 0.000064 ? quietSamples + 320 : 0
                energy = 0; analysisCount = 0
            }
            let pause = quietSamples >= 8_800 && pending.count >= 32_000
            if pause || pending.count >= 288_000 {
                chunks.append(SpeechChunk(samples: pending, overlapsPrevious: overlap))
                pending = pause ? [] : Array(pending.suffix(16_000))
                overlap = !pause; quietSamples = 0
            }
        }
        return chunks
    }
    public mutating func finish() -> SpeechChunk? {
        guard !pending.isEmpty else { return nil }
        // A forced split can leave only already-submitted overlap.
        if overlap && pending.count <= 16_000 { pending = []; return nil }
        let chunk = SpeechChunk(samples: pending, overlapsPrevious: overlap)
        pending = []; quietSamples = 0; overlap = false
        return chunk
    }
}

public enum TranscriptJoiner {
    public static func append(_ next: String, to current: String, overlapping: Bool) -> String {
        let clean = next.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return current }
        guard !current.isEmpty else { return clean }
        var words = clean.split(whereSeparator: \.isWhitespace).map(String.init)
        if overlapping {
            let previous = current.split(whereSeparator: \.isWhitespace).map(String.init)
            let normalize: (String) -> String = { $0.lowercased().filter { $0.isLetter || $0.isNumber } }
            let limit = min(12, previous.count, words.count)
            if limit >= 2 {
                for count in stride(from: limit, through: 2, by: -1) {
                    if previous.suffix(count).map(normalize) == words.prefix(count).map(normalize) {
                        words.removeFirst(count); break
                    }
                }
            }
        }
        return words.isEmpty ? current : current + " " + words.joined(separator: " ")
    }
}

public enum PCMFile {
    /// 16kHz mono PCM16 WAV, the input contract for both bundled runtimes.
    public static func wav(samples: [Float]) -> Data {
        var data = Data()
        func text(_ value: String) { data.append(contentsOf: value.utf8) }
        func u16(_ value: UInt16) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ value: UInt32) { var v = value.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        text("RIFF"); u32(bytes + 36); text("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(16000); u32(32000); u16(2); u16(16); text("data"); u32(bytes)
        for sample in samples {
            let finite = sample.isFinite ? max(-1, min(1, sample)) : 0
            u16(UInt16(bitPattern: Int16(finite * 32767)))
        }
        return data
    }
}
