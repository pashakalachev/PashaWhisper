# PashaWhisper

**Small app. Big ears.** Native Mac dictation with a brutalist Soviet cute cat identity.

![Cat emblem](assets/cat-emblem.png)

An early working build of the [PRD](PRD.md). See [build status](docs/BUILD_STATUS.md) for implemented features and limitations.

## Run

This repository contains the source; build the app using the **Develop** instructions below. Then open `dist/PashaWhisper.app`. A small English Whisper model is included in the generated app bundle. No Python, Homebrew, or account is needed to run the packaged app.

1. Open the app. **Setup** is the first screen: allow automatic paste in macOS Accessibility, then allow the microphone. Click **Finish Setup** when both permissions are verified.
2. Focus a text field in another app and press **Option-Space** (customizable in **Shortcuts**).
3. Speak, then press your shortcut again.
4. Offline recognition works in the background while you speak. After Stop, a small ring around the cat indicates any unfinished audio; then the completed text is pasted into the original field. **Copy Transcript** remains available if delivery is blocked.

Automatic paste is the default workflow, not an opt-in feature. The app checks field access and permission to post paste commands separately and refreshes the setup screen while Settings is open. If Accessibility is allowed but paste-command access still reports denied, Setup offers **Restart PashaWhisper** to clear the stale process state. Restart is disabled during active work or while a current result or retry audio would be lost. If field access itself is still denied despite an enabled entry, remove the old entry with **−**, then use **+** to add the exact app shown by **Show This App in Finder**, enable it, and return to Setup. Quit/reopen that copy if needed. This one-time migration may be needed when moving from an old ad-hoc build to certificate signing.

Shortcuts accept single keys (including Space, Escape, and F-keys), modifier-only taps, Fn/Globe, and multi-key chords. Press and release the combination to save it. Some bindings require Accessibility; use **Enable Shortcut Access** when shown. Modifier-only shortcuts trigger on release, and using a modifier to type or click does not trigger dictation. macOS may reserve some hardware/system combinations.

Use **Shortcuts → Change Shortcut** to record your own key or combination, then **Test Shortcut** to check it without recording audio. The picker accepts both normal keyboard events and native macOS hotkey notifications, including input from remappers. Temporary registrations stop on cancellation, completion, window close, or deactivation. Held keys trigger once until released.

Closing the window leaves the app in the menu bar. Use the cat menu to reopen it or quit. Automatic paste checks that the original application, field, selection, and readable field value are unchanged. It writes and verifies the new transcript on the clipboard before sending Paste once; uncertain delivery stays available for manual recovery.

Download a larger or multilingual model from Models. Choose OpenAI or Custom API under Providers to use your own key. Keys are stored in macOS Keychain. Cloud recording is always an explicit choice. API integration has not been tested against a paid live account.

No transcript history is stored. Only the current result stays in memory until cleared, replaced by another recording, or Quit. Temporary audio is deleted after success, silence, cancellation, and Quit. A failed recording can be retried during the session; crash leftovers are deleted next launch. Upgrading removes the old history and recording archive. Copied or automatically pasted text remains on the clipboard.

The floating indicator is a 144 × 46 point capsule: a cat with five waveform bars on either side, a finishing ring, and small success/error indicators. It contains no timer, model name, shortcut, or recording label. Detailed errors open the main app. Missing models, API keys, or bundled engines are reported before microphone capture begins. Enable Accessibility under **Shortcuts → Enable Field Positioning** to follow the active cursor or text field. It falls back to the pointer for unavailable fields or permission. Preview the indicator without recording from the same page.

The catalog includes NVIDIA Parakeet TDT v3, Qwen3-ASR 0.6B/1.7B, Cohere Transcribe 03-2026, NVIDIA Canary-Qwen 2.5B, Mistral Voxtral Mini 4B Realtime 2602, and 13 Whisper variants. Each entry names its exact quantization, download size, original publisher, and license. See the [model inventory](docs/MODELS.md).

Offline background recognition submits phrase-sized audio after pauses, with an 18-second maximum chunk and a one-second overlap at forced boundaries. Completed phrases are retained only in memory; Stop waits for outstanding work and the final tail, then pastes once. This is incremental chunked recognition, not token-by-token native streaming. Large models or sustained speech may still require a finishing delay. API mode continues to upload after Stop. Models are loaded per chunk; a persistent warm engine is future optimization.

## Develop

Requires Xcode and Swift 5.9+ on Apple Silicon. Deployment target is macOS 14, but this build has only been exercised on the development Mac. CMake is a build-time dependency for preparing the bundled native engine.

```sh
bash scripts/prepare-runtime.sh
bash scripts/build-app.sh
swift test
open dist/PashaWhisper.app
```

Set `CMAKE_BIN` if CMake is installed outside PATH. Runtime sources are pinned to whisper.cpp v1.8.6 and transcribe.cpp revision e2f82cb6702315a1194f3bf1a6fee67cd2678447, statically linked with Metal shaders embedded. The additional engine is prepared by `scripts/prepare-extra-runtime.sh`, which the main preparation script invokes. No machine-specific Homebrew library paths are packaged. Downloads and native build products are excluded from Git; the bootstrap script reproduces them.

The build script uses a stable signing certificate: it prefers a unique Developer ID Application identity, otherwise a unique Apple Development identity. Set `CODE_SIGN_IDENTITY` explicitly when there are multiple certificates. The current local build uses Apple Development signing. Developer ID signing and notarization are still required for a public production release. Ad-hoc signing is available only by explicitly setting `CODE_SIGN_IDENTITY=-` for disposable builds; changing those binaries can invalidate existing macOS permissions.

## Structure

- `Sources/WhisperCore`: data, filtering, request formatting, and model catalog.
- `Sources/PashaWhisper`: native UI, audio, engine execution, model downloads, Keychain, and application lifecycle.
- `Tests/WhisperCoreTests`: regression checks for shortcut validation, display-edge placement, filtering, and API request formatting.
- `docs/BRAND.md`: visual direction, generated logo provenance, and exact prompt.
- `docs/THIRD_PARTY_NOTICES.md`: runtime and model attribution.
