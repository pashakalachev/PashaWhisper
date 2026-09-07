# Verification — 0.2.1 — September 6, 2026

- All 15 tests pass: 11 core tests plus 4 tests using native AppKit keyboard events and the app's actual shortcut recorder.
- Native capture tests cover Space, Escape, Shift+A, right Option, Fn/Globe, simultaneous A+B, physical modifier sides, and the implicit function flag on F-keys.
- Matcher tests cover modifier-only taps versus typing/clicking, modifier chords, Caps Lock pulses, exact chord/modifier matching, repeats, matching key-up suppression, and migration from the original saved shortcut format.
- Debug and release builds pass. The packaged app passes deep/strict ad-hoc signature verification and launches with the updated Shortcuts page.
- Global event-tap operation with Accessibility permission and a physical keyboard still needs hands-on testing. Rebuilding this ad-hoc-signed app can require re-enabling its Accessibility permission. Pending bindings remain saved and display a permission notice; they are retried when the app becomes active after permission is granted.
- No microphone recording was initiated during these checks. The original Option-Space setting remains selected.

Native API references: [Apple CGEvent taps](https://developer.apple.com/documentation/coregraphics/cgevent), [Apple NSEvent](https://developer.apple.com/documentation/appkit/nsevent). Modifier handling uses event-time flags and native left/right key masks, avoiding a live-state sampling race on quick taps.

## Previous 0.2.0 verification

- Debug tests and release build pass with Xcode 26.6 / Swift 6.3.3, targeting macOS 14 on Apple Silicon.
- Six unit tests pass: conservative annotation removal, endpoint policy, multipart formatting, shortcut validation/persistence format, overlay top-edge flipping, and placement on a display left of the primary display.
- Native UI checked for Dictation, Models, and Shortcuts. Exact upstream IDs, filenames, quantization and model parameters are visible in the catalog. Screenshots: models-preview.png and shortcuts-preview.png.
- Tested Change Shortcut in the running app, captured Control-Shift-D, verified its display and persisted settings, then used Reset and verified Option-Space was saved again. No microphone recording was initiated during this test.
- Tested Preview Indicator: actual nonactivating 292×64 window rendered the cat, waveform, elapsed time and shortcut, above the pointer with the expected gap. Screenshot: recording-overlay-preview.png. The preview is explicitly labeled PREVIEW and uses sample meter values.
- Upgrading the previously idle 0.1 build removed history.json and the old Recordings directory. Transient directory was empty and the new current-result view had no previous transcripts.
- Updated app passed deep, strict ad-hoc code-signature verification and was launched successfully. Production signing/notarization remains pending.

Prior engine checks (unchanged recognition implementation): bundled Tiny.en Q5 transcribed the upstream JFK speech sample successfully; five seconds of digital silence returned empty output before ASR. Runtime dependencies were checked for Apple frameworks only, and starter model / VAD / source archive integrity checks passed.

Not yet verified in 0.2: live microphone waveform behavior, field/caret anchoring across other apps (Accessibility is not enabled for the app), global shortcut conflict scenarios, paid API requests, downloads of every catalog artifact, long recordings, performance targets, or minimum-OS compatibility. Automatic insertion remains unimplemented; current delivery uses manual Copy and Paste. See BUILD_STATUS.md for remaining release work.
