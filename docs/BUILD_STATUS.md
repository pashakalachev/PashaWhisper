# Build status — 0.3.0

Native macOS development build; the full release requirements remain in [PRD.md](../PRD.md).

Implemented:

- Permission-first Setup: default automatic paste, verified field access and event posting, then microphone. Explicit restart recovery for stale paste-command checks after Accessibility approval. Live permission refresh and guidance for a stale enabled entry; dictation waits until permission checks pass.
- Certificate-signed builds using an available Developer ID or Apple Development identity. Ad-hoc signing requires explicit opt-in.

- Menu-bar utility and Soviet constructivist cat identity throughout. Sidebar focus rings appear during Tab navigation and clear on mouse use or app deactivation; the full navigation row is clickable.
- Generic no-recording shortcut test; native hotkey capture plus permission-aware event capture and local key events. No device-specific preset. Native shortcut handlers validate their event IDs and suppress repeat presses until release.
- Editable global shortcut: single keys, modifier-only taps, Fn/Globe, Shift-only combinations, and multi-key chords. Captures on release, preserves older saved settings, reports permission needs, and offers Cancel and Reset. Default Option-Space.
- Nonactivating 144 × 46 point capsule with a central cat, five waveform bars on each side, and a finishing ring. No recording text, model name, shortcut, or timer. Uses Accessibility caret bounds, text-field bounds, or pointer fallback, clamped within the display. Preview requires no recording.
- No History screen or persisted transcripts. Current result only; temporary audio with same-session retry after failure. Clear on success, silence, cancellation, or Quit; remove crash leftovers next launch and migrate away the old archive.
- AVAudioEngine microphone capture converted once to 16 kHz mono, saved as PCM16 recovery audio and sent to ordered background recognition jobs. Stop flushes resampler samples and completes only outstanding chunks. Pause boundaries, bounded overlap, cancellation, full-recording retry, Silero speech filtering, and annotation filtering.
- Six additional downloads across Parakeet, Qwen3-ASR, Cohere, Canary-Qwen, and Voxtral, with pinned Hugging Face revisions and SHA-256 checks. Language compatibility is checked before recording. 13 explicitly named Whisper variants with upstream IDs, quantization, parameters, artifact names, sizes, and source links; integrity-checked downloads. Tiny.en Q5 is bundled.
- Explicit OpenAI / compatible endpoint selection, multipart audio upload, Keychain storage, and no silent cloud fallback.
- Automatic paste into the unchanged original text field and selection, with verified clipboard writes, once-per-session delivery, stale-session cancellation guards, and manual Copy recovery.
- Pre-recording checks for model availability, runtime files, provider configuration, and microphone permission. Floating preparation/transcription/success/failure states stay visible outside the main window.
- Transcription latency shown after each session. Offline VAD runs once inside whisper.cpp instead of twice.

Remaining work:

- Broader per-app delivery validation; simulated Paste is reported as requested, not verified. The tested native field received it, but no universal compatibility claim is made.
- Hold-to-talk, global Escape, microphone selector, input-disconnection handling, native token streaming, warm model reuse, download resume/free-space preflight.
- Model import, API connection testing, provider cost estimates, and uploads above 25 MB.
- Broad Accessibility field coverage, live microphone/waveform testing, long recordings, quiet-speech/non-speech corpora, model quality and memory/latency benchmarks.
- Developer ID signing/notarization, minimum-macOS validation, and Intel support. This local build uses Apple Development signing.

Cloud VAD checks for speech before upload; it does not strip every silent interval. No guarantee is made against background voices or singing.
