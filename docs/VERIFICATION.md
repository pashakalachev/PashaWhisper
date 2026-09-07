# Verification — 0.2.4 — September 6, 2026

- All 24 automated tests pass. New cases cover native shortcut conversion for multiple keys/modifiers, empty text, failed clipboard writes, clipboard races, focus changes, once-only Paste dispatch, and missing-model preflight without microphone capture.
- An isolated native app exercised Carbon hotkey notifications for F18, F17, Option-Space, and Shift-Command-A; the picker captured each and the normal dictation callback remained at zero. A separate OS keyboard-event test captured F18, F17, and Option-Space. F-key test events need macOS's function flag; an initial incorrectly flagged injection did not trigger the hotkey. The OS-routed Shift-Command-A case timed out and is not claimed verified. No confirmation was received from the user's physical pedal during the separate bounded hands-on check.
- Automatic paste passed an isolated two-process AppKit test: it replaced a selected substring once and preserved surrounding text. The test restored the previous clipboard only when its own test text still owned it. Direct-to-process event posting failed the initial fixture; posting through the window server passed. Production delivery checks focus/selection/readable field value and verifies the exact transcript on the clipboard immediately before dispatch. UI reports “Paste sent,” not a universal verified-insertion claim.
- The user's existing app had a successful four-second Tiny.en transcript in its Current Result view. Missing automatic delivery, rather than a missing model, explained that observed attempt. The running app was left open to preserve its in-memory result.
- Packaged engine on Apple M1 Pro, macOS 26.5.2: public 11-second upstream JFK sample returned expected text in 1.52 seconds wall time; five seconds of synthetic silence returned no text in 0.62 seconds. A prior 0.2.3 sample run took 2.67 seconds. These are single-run measurements with uncontrolled cache warmth, not a rigorous speedup claim or percentile benchmark. Offline VAD now runs once inside whisper.cpp; cloud mode still checks locally before upload.
- Generic shortcut controls, missing-model readiness notice, and floating transcription status were rendered and inspected in an isolated SwiftUI preview. No pedal-specific preset is present. Model/engine/API setup failures open the relevant page; failed delivery opens the current transcript for Copy.
- Debug/release builds and ad-hoc signing pass. Automatic paste requires Accessibility permission for the running app; an ad-hoc rebuild may require re-enabling it. The packaged update is ready for a user-controlled quit/reopen.

Not yet verified: the physical Elfkey/PCsensor + BetterTouchTool sequence in the new packaged app, broad app/secure-field compatibility, end-to-end live-microphone automatic paste, paid API requests, long-session latency, and continuous speech transcription while recording. The current engine finalizes after Stop. The PRD records warm-model reuse and incremental recognition as follow-up work, with stable final-text reconciliation required before delivery.

## Previous 0.2.3 verification


- All 17 tests pass, including F18 with no flags, the function flag, and function+numeric-pad flags. These events capture as F18, match repeatedly on separate presses, and do not require physical Fn. A real Fn press followed by F18 remains distinguishable.
- Native F18 registration returned success (OSStatus 0) on the development Mac, then the diagnostic registration was removed. This does not rule out interception by a remapper earlier in the event stream.
- The picker now uses a temporary head-insert session event tap when available, ahead of application hotkey handling. It falls back to window events without permission and stops on assignment, cancel, deactivation, close, or quit. Queued events from an old capture are rejected.
- The actual SwiftUI F18 preset and shortcut test were rendered in an isolated preview. Calling the shortcut callback in test mode incremented its counter without setting recording, preparing, or transcribing. This is an app-state test, not a physical pedal test.
- A 45-second read-only live diagnostic restricted to F18/Fn saw no matching events; no confirmation was received that the pedal was pressed during that window. Physical pedal behavior remains unverified.
- Debug/release builds and ad-hoc signature verification pass. `--test-shortcut` opens the no-audio test screen for hands-on verification.

Apple documents that the function modifier includes F-keys and navigation keys: [NSEvent function flag](https://developer.apple.com/documentation/appkit/nsevent/modifierflags-swift.struct/function). The early capture listener uses [head-insert event tap placement](https://developer.apple.com/documentation/coregraphics/cgeventtapplacement/headinserteventtap).

## Previous 0.2.2 verification

- Debug and packaged release builds succeed; ad-hoc signature verification passes.
- Checked the actual SwiftUI sidebar in an isolated native preview, using temporary app data and no microphone. With Shortcuts selected, pointer mode has no lingering Dictation focus outline. Switching to Models retains only the selected-page background in pointer mode.
- Posting a Tab event to the isolated preview moved keyboard focus to Models and displayed its full-row focus outline. Returning to pointer mode removed that outline. Mouse presses and app deactivation leave keyboard navigation mode; no global accessibility setting is changed.
- Expanded each sidebar label's hit area to the full rectangular row.

## Previous 0.2.1 verification

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
