# Build status — 0.2.2

Native macOS development build; the full release requirements remain in [PRD.md](../PRD.md).

Implemented:

- Menu-bar utility and Soviet constructivist cat identity throughout. Sidebar focus rings appear during Tab navigation and clear on mouse use or app deactivation; the full navigation row is clickable.
- Editable global shortcut: single keys, modifier-only taps, Fn/Globe, Shift-only combinations, and multi-key chords. Captures on release, preserves older saved settings, reports permission needs, and offers Cancel and Reset. Default Option-Space.
- Nonactivating floating cat overlay with 22 live microphone meter bars, elapsed time, and current shortcut. Uses Accessibility caret bounds, text-field bounds, or pointer fallback, clamped within the display. Preview requires no recording.
- No History screen or persisted transcripts. Current result only; temporary audio with same-session retry after failure. Clear on success, silence, cancellation, or Quit; remove crash leftovers next launch and migrate away the old archive.
- Real 16 kHz mono microphone recording, local whisper.cpp recognition, Silero speech detection, and conservative annotation filtering.
- 13 explicitly named Whisper variants with upstream IDs, quantization, parameters, artifact names, sizes, and source links; integrity-checked downloads. Tiny.en Q5 is bundled.
- Explicit OpenAI / compatible endpoint selection, multipart audio upload, Keychain storage, and no silent cloud fallback.
- Verified manual clipboard Copy and stale-session cancellation guards.

Remaining work:

- Automatic insertion and per-app delivery validation. This build uses Copy followed by the user's Paste.
- Hold-to-talk, global Escape, microphone selector, input-disconnection handling, streaming chunks, warm model reuse, download resume/free-space preflight.
- Parakeet and Qwen runtime adapters, model import, API connection testing, provider cost estimates, and uploads above 25 MB.
- Broad Accessibility field coverage, live microphone/waveform testing, long recordings, quiet-speech/non-speech corpora, model quality and memory/latency benchmarks.
- Developer ID signing/notarization, minimum-macOS validation, and Intel support. This build is ad-hoc signed.

Cloud VAD checks for speech before upload; it does not strip every silent interval. No guarantee is made against background voices or singing.
