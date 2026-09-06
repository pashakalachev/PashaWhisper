# Model inventory — September 6, 2026

The app executes the selected artifact with bundled whisper.cpp v1.8.6. Model names and quantization are visible together; a quantized artifact is not a separate model family. Only Tiny.en Q5_1 ships in the bundle. Other entries are optional downloads, verified against the upstream SHA-1 manifest before installation.

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

The catalog contains compatible artifacts; only the bundled Tiny.en model has an end-to-end speech smoke test on this Mac so far. No cross-model quality or speed ranking has been measured. Benchmark conversational English and the user's other languages, quiet speech, long pauses, and five-minute recordings before choosing a larger default.

## Additional engines

- **NVIDIA Parakeet TDT 0.6B v3:** 25 European languages, candidate for the next native adapter. FluidAudio documents a Swift/Core ML path. Requires packaging, VAD integration, cancellation, language and performance checks before activation. [FluidAudio models](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Models.md), [NVIDIA model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
- **Qwen3-ASR 0.6B / 1.7B:** candidates for broader multilingual coverage. Requires a compatible Mac runtime and separate adapter; cannot be loaded by whisper.cpp. [Official Qwen3-ASR repository](https://github.com/QwenLM/Qwen3-ASR)

These families are clearly marked as future adapters in the app. They are not presented as usable downloads. Provider API model IDs are separate from this local inventory.
