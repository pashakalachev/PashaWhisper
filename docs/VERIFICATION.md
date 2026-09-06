# Verification — 0.2.0 — September 6, 2026

- Debug tests and release build pass with Xcode 26.6 / Swift 6.3.3, targeting macOS 14 on Apple Silicon.
- Six unit tests pass: conservative annotation removal, endpoint policy, multipart formatting, shortcut validation/persistence format, overlay top-edge flipping, and placement on a display left of the primary display.
- Native UI checked for Dictation, Models, and Shortcuts. Exact upstream IDs, filenames, quantization and model parameters are visible in the catalog. Screenshots: models-preview.png and shortcuts-preview.png.
- Tested Change Shortcut in the running app, captured Control-Shift-D, verified its display and persisted settings, then used Reset and verified Option-Space was saved again. No microphone recording was initiated during this test.
- Tested Preview Indicator: actual nonactivating 292×64 window rendered the cat, waveform, elapsed time and shortcut, above the pointer with the expected gap. Screenshot: recording-overlay-preview.png. The preview is explicitly labeled PREVIEW and uses sample meter values.
- Upgrading the previously idle 0.1 build removed history.json and the old Recordings directory. Transient directory was empty and the new current-result view had no previous transcripts.
- Updated app passed deep, strict ad-hoc code-signature verification and was launched successfully. Production signing/notarization remains pending.

Prior engine checks (unchanged recognition implementation): bundled Tiny.en Q5 transcribed the upstream JFK speech sample successfully; five seconds of digital silence returned empty output before ASR. Runtime dependencies were checked for Apple frameworks only, and starter model / VAD / source archive integrity checks passed.

Not yet verified in 0.2: live microphone waveform behavior, field/caret anchoring across other apps (Accessibility is not enabled for the app), global shortcut conflict scenarios, paid API requests, downloads of every catalog artifact, long recordings, performance targets, or minimum-OS compatibility. Automatic insertion remains unimplemented; current delivery uses manual Copy and Paste. See BUILD_STATUS.md for remaining release work.
