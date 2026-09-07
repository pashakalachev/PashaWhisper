import Foundation
import CoreGraphics

public enum Suppression: String, CaseIterable, Codable {
    case normal = "Normal", strong = "Strong", off = "Off"
}

public enum TranscriptFilter {
    // Remove only full-line known annotations. Never remove arbitrary bracketed speech.
    static let annotations: Set<String> = ["[music]", "(music)", "[silence]", "(silence)", "[sigh]", "[sighs]", "(sighs)", "[breathing]", "[applause]", "(applause)", "[blank_audio]", "[blank audio]", "[no speech]", "[inaudible]"]
    public static func clean(_ raw: String, mode: Suppression) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard mode != .off else { return text }
        return text.components(separatedBy: .newlines)
            .filter { !annotations.contains($0.trimmingCharacters(in: .whitespaces).lowercased()) }
            .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct Transcript: Identifiable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public var text: String
    public var rawText: String
    public var provider: String
    public var duration: TimeInterval
    public init(id: UUID = UUID(), text: String, rawText: String, provider: String, duration: TimeInterval, createdAt: Date = Date()) {
        self.id = id; self.text = text; self.rawText = rawText; self.provider = provider
        self.duration = duration; self.createdAt = createdAt
    }
}

public struct LocalModel: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let detail: String
    public let size: String
    public let sha1: String
    public var precision: String {
        if id.hasSuffix("q5_0") { return "Q5_0 · 5-bit" }
        if id.hasSuffix("q5_1") { return "Q5_1 · 5-bit" }
        if id.hasSuffix("q8_0") { return "Q8_0 · 8-bit" }
        return "F16 · 16-bit"
    }
    public var upstreamID: String {
        "openai/whisper-" + id.replacingOccurrences(of: "-q5_0", with: "").replacingOccurrences(of: "-q5_1", with: "").replacingOccurrences(of: "-q8_0", with: "")
    }
    public var parameters: String {
        if id.hasPrefix("tiny") { return "39M" }
        if id.hasPrefix("base") { return "74M" }
        if id.hasPrefix("small") { return "244M" }
        if id.hasPrefix("medium") { return "769M" }
        return id.contains("turbo") ? "809M" : "1.55B"
    }
    public var modelCard: URL { URL(string: "https://huggingface.co/" + upstreamID)! }
    public var filename: String { "ggml-\(id).bin" }
    public var url: URL { URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(filename)")! }
    public static let catalog: [LocalModel] = [
        .init(id: "tiny.en-q5_1", title: "OpenAI Whisper Tiny.en", detail: "Quick start · English · Q5", size: "31 MiB", sha1: "3fb92ec865cbbc769f08137f22470d6b66e071b6"),
        .init(id: "base", title: "OpenAI Whisper Base", detail: "Lightweight · Multilingual", size: "142 MiB", sha1: "465707469ff3a37a2b9b8d8f89f2f99de7299dac"),
        .init(id: "small", title: "OpenAI Whisper Small", detail: "Everyday · Multilingual", size: "466 MiB", sha1: "55356645c2b361a969dfd0ef2c5a50d530afd8d5"),
        .init(id: "medium-q5_0", title: "OpenAI Whisper Medium", detail: "Multilingual · Q5", size: "514 MiB", sha1: "7718d4c1ec62ca96998f058114db98236937490e"),
        .init(id: "large-v3-turbo-q5_0", title: "OpenAI Whisper Large v3 Turbo", detail: "Quality + speed · Multilingual · Q5", size: "547 MiB", sha1: "e050f7970618a659205450ad97eb95a18d69c9ee"),
        .init(id: "large-v3-q5_0", title: "OpenAI Whisper Large v3", detail: "Multilingual · Compact download", size: "1.1 GiB", sha1: "e6e2ed78495d403bef4b7cff42ef4aaadcfea8de"),
        .init(id: "tiny", title: "OpenAI Whisper Tiny", detail: "Multilingual · Smallest full-precision model", size: "75 MiB", sha1: "bd577a113a864445d4c299885e0cb97d4ba92b5f"),
        .init(id: "base.en", title: "OpenAI Whisper Base.en", detail: "English only", size: "142 MiB", sha1: "137c40403d78fd54d454da0f9bd998f78703390c"),
        .init(id: "small.en", title: "OpenAI Whisper Small.en", detail: "English only", size: "466 MiB", sha1: "db8a495a91d927739e50b3fc1cc4c6b8f6c2d022"),
        .init(id: "medium", title: "OpenAI Whisper Medium", detail: "Multilingual · Full precision", size: "1.5 GiB", sha1: "fd9727b6e1217c2f614f9b698455c4ffd82463b4"),
        .init(id: "large-v3-turbo", title: "OpenAI Whisper Large v3 Turbo", detail: "Multilingual · Full precision", size: "1.5 GiB", sha1: "4af2b29d7ec73d781377bfd1758ca957a807e941"),
        .init(id: "large-v3-turbo-q8_0", title: "OpenAI Whisper Large v3 Turbo", detail: "Multilingual · Intermediate download size", size: "834 MiB", sha1: "01bf15bedffe9f39d65c1b6ff9b687ea91f59e0e"),
        .init(id: "large-v3", title: "OpenAI Whisper Large v3", detail: "Multilingual · Full precision", size: "2.9 GiB", sha1: "ad82bf6a9043ceed055076d0fd39f5f186ff8062")
    ]
}

public enum AppFailure: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

public enum EndpointPolicy {
    public static func validate(_ value: String) throws -> URL {
        guard let url = URL(string: value), let host = url.host, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "[::1]"].contains(host))
        else { throw AppFailure.message("Use an HTTPS transcription endpoint, or HTTP on localhost.") }
        return url
    }
}

public enum Multipart {
    public static func audio(data: Data, model: String, language: String, openAI: Bool, boundary: String) -> Data {
        var result = Data()
        func append(_ text: String) { result.append(Data(text.utf8)) }
        func field(_ name: String, _ value: String) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        field("model", model)
        if language != "auto" && !language.isEmpty {
            field(openAI && model == "gpt-transcribe" ? "languages[]" : "language", language)
        }
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"dictation.wav\"\r\nContent-Type: audio/wav\r\n\r\n")
        result.append(data)
        append("\r\n--\(boundary)--\r\n")
        return result
    }
}

public struct KeyboardShortcut: Codable, Equatable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let keyLabel: String
    public let additionalKeys: [UInt32]?
    public init(keyCode: UInt32, modifiers: UInt32, keyLabel: String, additionalKeys: [UInt32]? = nil) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.keyLabel = keyLabel; self.additionalKeys = additionalKeys
    }
    public static let fnModifier: UInt32 = 131072
    public static let modifierKeys: Set<UInt32> = [54,55,56,57,58,59,60,61,62,63]
    public static let f18Pedal = KeyboardShortcut(keyCode: 79, modifiers: 0, keyLabel: "F18")
    public static let standard = KeyboardShortcut(keyCode: 49, modifiers: 2048, keyLabel: "Space")
    public var keys: Set<UInt32> { Set([keyCode] + (additionalKeys ?? [])) }
    public var modifierOnly: Bool { keys.isSubset(of: Self.modifierKeys) }
    public var needsEventTap: Bool { modifierOnly || keys.count > 1 || modifiers & Self.fnModifier != 0 }
    public var isValid: Bool { keys.allSatisfy { $0 < 128 } && !keyLabel.isEmpty && modifiers & ~(256 | 512 | 2048 | 4096 | Self.fnModifier) == 0 }
    public var display: String {
        [(4096, "⌃"), (2048, "⌥"), (512, "⇧"), (256, "⌘"), (Int(Self.fnModifier), "Fn+")].filter { modifiers & UInt32($0.0) != 0 }.map { $0.1 }.joined() + keyLabel
    }
}

/// Tracks physical keys only; never receives or stores typed text.
public struct ShortcutGesture {
    public private(set) var held: Set<UInt32> = []
    public private(set) var peak: Set<UInt32> = []
    public private(set) var peakModifiers: UInt32 = 0
    public init() {}
    public mutating func update(key: UInt32, down: Bool, modifiers: UInt32) -> (keys: Set<UInt32>, modifiers: UInt32)? {
        if down {
            held.insert(key)
            if held.count >= peak.count { peak = held; peakModifiers = modifiers }
        } else { held.remove(key) }
        if held.isEmpty, !peak.isEmpty {
            let result = (peak, peakModifiers); peak = []; peakModifiers = 0; return result
        }
        return nil
    }
}

public struct ShortcutMatcher {
    public let shortcut: KeyboardShortcut
    private var held: Set<UInt32> = []
    private var latched = false
    private var modifierArmed = false
    private var modifierUsed = false
    private var swallowed: Set<UInt32> = []
    public init(shortcut: KeyboardShortcut) { self.shortcut = shortcut }
    public mutating func usedWithMouse() { if !held.isEmpty { modifierUsed = true } }
    public mutating func update(key: UInt32, down: Bool, modifiers: UInt32, repeatKey: Bool = false) -> (trigger: Bool, suppress: Bool) {
        if repeatKey { return (false, swallowed.contains(key)) }
        let before = held
        if down { held.insert(key) } else { held.remove(key) }
        if shortcut.modifierOnly {
            if down, !held.isSubset(of: shortcut.keys) { modifierUsed = true }
            if held == shortcut.keys { modifierArmed = true }
            if held.isEmpty {
                let fire = modifierArmed && !modifierUsed && !before.isEmpty
                modifierArmed = false; modifierUsed = false
                return (fire, false)
            }
            return (false, false)
        }
        let regular = held.subtracting(KeyboardShortcut.modifierKeys)
        let matches = regular == shortcut.keys && modifiers == shortcut.modifiers
        var suppress = swallowed.contains(key)
        if !down { swallowed.remove(key) }
        if down, matches, !latched {
            latched = true
            if !KeyboardShortcut.modifierKeys.contains(key) { swallowed.insert(key); suppress = true }
            return (true, suppress)
        }
        if !matches { latched = false }
        return (false, suppress)
    }
}

public enum OverlayPlacement {
    // AppKit coordinates: Y increases upward. Place above the caret/field, flip below near the top.
    public static func origin(anchor: CGRect, screen: CGRect, size: CGSize) -> CGPoint {
        let margin: CGFloat = 10
        let x = max(screen.minX + margin, min(anchor.midX - size.width / 2, screen.maxX - size.width - margin))
        let above = anchor.maxY + 10
        let y = above + size.height <= screen.maxY - margin ? above : anchor.minY - size.height - 10
        return CGPoint(x: x, y: max(screen.minY + margin, min(y, screen.maxY - size.height - margin)))
    }
}
