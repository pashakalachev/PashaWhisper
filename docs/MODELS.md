# Model inventory — September 7, 2026

PashaWhisper 0.3.0 offers 19 downloads across six families. Only Whisper Tiny.en Q5_1 ships in the app. All other weights are optional downloads. The two bundled native engines are whisper.cpp v1.8.6 and transcribe.cpp revision `e2f82cb6702315a1194f3bf1a6fee67cd2678447`; they do not need Python, a server, or an API key.

## Additional downloadable families

| Model | Artifact precision | Download | Languages | License |
|---|---|---|---|---|
| [NVIDIA Parakeet TDT 0.6B v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) | Q8_0 | 705 MiB | 25 European languages; includes English, Russian, Ukrainian | CC BY 4.0 |
| [Qwen3-ASR 0.6B](https://huggingface.co/Qwen/Qwen3-ASR-0.6B) | Q8_0 | 811 MiB | 30 languages, automatic detection | Apache 2.0 |
| [Qwen3-ASR 1.7B](https://huggingface.co/Qwen/Qwen3-ASR-1.7B) | Q8_0 | 2.04 GiB | Same language coverage, larger model | Apache 2.0 |
| [Cohere Transcribe 03-2026](https://huggingface.co/CohereLabs/cohere-transcribe-03-2026) | Q8_0 | 2.25 GiB | 14 languages; select the language explicitly | Apache 2.0 |
| [NVIDIA Canary-Qwen 2.5B](https://huggingface.co/nvidia/canary-qwen-2.5b) | Q8_0 | 2.61 GiB | English | CC BY 4.0 |
| [Mistral Voxtral Mini 4B Realtime 2602](https://huggingface.co/mistralai/Voxtral-Mini-4B-Realtime-2602) | Q4_K_M | 2.64 GiB | 13 languages, automatic detection | Apache 2.0 |

These are a practical shortlist of current public speech-recognition models with a native Mac runtime. There is no universal quality ranking: language, accent, noise, hardware, and quantization affect results. Publisher benchmark results are not app-level guarantees.

GGUF conversions are published by [handy-computer/transcribe.cpp](https://github.com/handy-computer/transcribe.cpp). New downloads are pinned to immutable Hugging Face commits and validated against exact byte counts and SHA-256 hashes. The catalog in `Sources/WhisperCore/DownloadableModels.swift` records each artifact filename, revision, repository, and checksum. Failed or canceled downloads are never installed.

Cohere requires an explicit language; the app refuses to silently treat Automatic as English. Unsupported selected languages are reported before recording. All offline families use ordered background chunks, speech filtering, and the same verified delivery path. The Voxtral model name includes Realtime, but this app currently uses the common chunked background path rather than its native token stream.

## Whisper artifacts

Whisper weights retain the upstream SHA-1 verification used by the original download catalog. A quantized artifact is not a separate model family.

| Model | Precision | Language | Approximate download | Exact artifact |
|---|---|---|---|---|
| OpenAI Whisper Tiny.en | Q5_1 | English | 31 MiB | `ggml-tiny.en-q5_1.bin` |
| OpenAI Whisper Base | F16 | Multilingual | 142 MiB | `ggml-base.bin` |
| OpenAI Whisper Small | F16 | Multilingual | 466 MiB | `ggml-small.bin` |
| OpenAI Whisper Medium | Q5_0 | Multilingual | 514 MiB | `ggml-medium-q5_0.bin` |
| OpenAI Whisper Large v3 Turbo | Q5_0 | Multilingual | 547 MiB | `ggml-large-v3-turbo-q5_0.bin` |
| OpenAI Whisper Large v3 | Q5_0 | Multilingual | 1.1 GiB | `ggml-large-v3-q5_0.bin` |
| OpenAI Whisper Tiny | F16 | Multilingual | 75 MiB | `ggml-tiny.bin` |
| OpenAI Whisper Base.en | F16 | English | 142 MiB | `ggml-base.en.bin` |
| OpenAI Whisper Small.en | F16 | English | 466 MiB | `ggml-small.en.bin` |
| OpenAI Whisper Medium | F16 | Multilingual | 1.5 GiB | `ggml-medium.bin` |
| OpenAI Whisper Large v3 Turbo | F16 | Multilingual | 1.5 GiB | `ggml-large-v3-turbo.bin` |
| OpenAI Whisper Large v3 Turbo | Q8_0 | Multilingual | 834 MiB | `ggml-large-v3-turbo-q8_0.bin` |
| OpenAI Whisper Large v3 | F16 | Multilingual | 2.9 GiB | `ggml-large-v3.bin` |

Whisper parameter counts: Tiny 39M, Base 74M, Small 244M, Medium 769M, Large v3 1.55B, Large v3 Turbo 809M. English-specific models use `.en`. F16 indicates the unquantized whisper.cpp artifact; Q5/Q8 reduce weight precision and download size. Download size is not a working-memory estimate. [OpenAI Whisper models](https://github.com/openai/whisper#available-models-and-languages), [whisper.cpp artifact manifest](https://huggingface.co/ggerganov/whisper.cpp/blob/main/README.md)

## Validation and latency

See [VERIFICATION.md](VERIFICATION.md) for the exact artifacts and recordings tested on this Mac. Recognition begins during capture at phrase pauses, with an 18-second ceiling per chunk and overlap at forced boundaries. Stop finalizes outstanding work and the audio tail before one paste. Runtime/model startup, workload, and final utterance length still affect latency; persistent model reuse and native streaming are separate future optimizations.
