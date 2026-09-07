import Foundation

public enum SpeechEngine: String { case whisper, transcribe
    public var executable: String { self == .whisper ? "whisper-cli" : "transcribe-cli" }
    public var label: String { self == .whisper ? "whisper.cpp" : "transcribe.cpp · Metal" }
}

public struct DownloadableModel: Hashable {
    public let id, title, detail, parameters, upstreamID, license, family, filename: String
    public let bytes: Int64
    public let sha256, repository, revision: String
    public var size: String { bytes < 1_073_741_824 ? "\(bytes / 1_048_576) MiB" : String(format: "%.2f GiB", Double(bytes) / 1_073_741_824) }
    public var url: URL { URL(string: "https://huggingface.co/\(repository)/resolve/\(revision)/\(filename)")! }
    public static let catalog: [DownloadableModel] = [
        .init(id: "parakeet-tdt-0.6b-v3", title: "NVIDIA Parakeet TDT 0.6B v3", detail: "Fast multilingual dictation · 25 European languages", parameters: "600M", upstreamID: "nvidia/parakeet-tdt-0.6b-v3", license: "CC BY 4.0", family: "parakeet", filename: "parakeet-tdt-0.6b-v3-Q8_0.gguf", bytes: 739508576, sha256: "5859f77944efcd8eafa23a6350731960b2b55b2203df51f319665c807d802cc7", repository: "handy-computer/parakeet-tdt-0.6b-v3-gguf", revision: "85ac09ea12fc4b1112fa76810059364bc6adc9de"),
        .init(id: "qwen3-asr-0.6b", title: "Qwen3-ASR 0.6B", detail: "Smaller multilingual option · 30 languages", parameters: "600M", upstreamID: "Qwen/Qwen3-ASR-0.6B", license: "Apache 2.0", family: "qwen", filename: "Qwen3-ASR-0.6B-Q8_0.gguf", bytes: 850423456, sha256: "f081b2d5e23bd669d92cc331d722a8a0681943b8e6f34b48996fd5c319b5acd8", repository: "handy-computer/qwen3-asr-0.6b-gguf", revision: "e4e16599b900eb0cb36e524514756bb92eb092b7"),
        .init(id: "qwen3-asr-1.7b", title: "Qwen3-ASR 1.7B", detail: "Larger multilingual option · 30 languages", parameters: "1.7B", upstreamID: "Qwen/Qwen3-ASR-1.7B", license: "Apache 2.0", family: "qwen", filename: "Qwen3-ASR-1.7B-Q8_0.gguf", bytes: 2185030624, sha256: "9a0d81792dfea2d5f278b8a63deb3ea6e02139ce42c2301f32ea19c4f77526b7", repository: "handy-computer/qwen3-asr-1.7b-gguf", revision: "92282af1610a2db19d66f2bef1e260f5deca782d"),
        .init(id: "cohere-transcribe-03-2026", title: "Cohere Transcribe 03-2026", detail: "Multilingual dictation · 14 languages", parameters: "2B", upstreamID: "CohereLabs/cohere-transcribe-03-2026", license: "Apache 2.0", family: "cohere", filename: "cohere-transcribe-03-2026-Q8_0.gguf", bytes: 2410655232, sha256: "931916663432fd895423a4291a8400221802b288967ca2d435fc5e3141c9e71e", repository: "handy-computer/cohere-transcribe-03-2026-gguf", revision: "dfa4adebb64f3076b7b6b90b721275cc069cb421"),
        .init(id: "canary-qwen-2.5b", title: "NVIDIA Canary-Qwen 2.5B", detail: "English dictation · Punctuation and capitalization", parameters: "2.5B", upstreamID: "nvidia/canary-qwen-2.5b", license: "CC BY 4.0", family: "canary", filename: "canary-qwen-2.5b-Q8_0.gguf", bytes: 2797548928, sha256: "d89aad1285d5bd5aa441c464d3a4cf37bd5474f70705408e71558d8627415b34", repository: "handy-computer/canary-qwen-2.5b-gguf", revision: "3370d4e2f28cc70eea79dfc9f2f43fb91eef3163"),
        .init(id: "voxtral-mini-4b-realtime-2602", title: "Mistral Voxtral Mini 4B Realtime 2602", detail: "13 languages · Compact 4-bit download", parameters: "4B", upstreamID: "mistralai/Voxtral-Mini-4B-Realtime-2602", license: "Apache 2.0", family: "voxtral", filename: "Voxtral-Mini-4B-Realtime-2602-Q4_K_M.gguf", bytes: 2830493984, sha256: "39dc1f65539373a406edea7490505822d77c12edff521744678717eef4da4723", repository: "handy-computer/voxtral-mini-4b-realtime-2602-gguf", revision: "b3e1c979e3775cbd0a49a65878a0ec7f06789ed7"),
    ]
}

public enum SpeechLanguage {
    public static let choices: [(code: String, name: String)] = [
        ("en", "English"), ("ru", "Russian"), ("es", "Spanish"), ("fr", "French"), ("de", "German"),
        ("zh", "Chinese"), ("yue", "Cantonese"), ("ja", "Japanese"), ("ko", "Korean"), ("pt", "Portuguese"),
        ("it", "Italian"), ("ar", "Arabic"), ("hi", "Hindi"), ("nl", "Dutch"), ("pl", "Polish"),
        ("uk", "Ukrainian"), ("vi", "Vietnamese"), ("th", "Thai"), ("tr", "Turkish"), ("id", "Indonesian"),
        ("ms", "Malay"), ("fil", "Filipino"), ("fa", "Persian"), ("sv", "Swedish"), ("da", "Danish"),
        ("fi", "Finnish"), ("el", "Greek"), ("cs", "Czech"), ("hu", "Hungarian"), ("ro", "Romanian"),
        ("bg", "Bulgarian"), ("hr", "Croatian"), ("et", "Estonian"), ("lv", "Latvian"), ("lt", "Lithuanian"),
        ("mt", "Maltese"), ("sk", "Slovak"), ("sl", "Slovenian"), ("mk", "Macedonian")
    ]
}
