# PashaWhisper — product requirements

Draft v5 · September 6, 2026 · Product requirements; implementation status tracked in docs/BUILD_STATUS.md

**Product promise:** Press a shortcut, speak, and get your words into the intended text field. Work offline with downloadable models or use your own transcription API key. If delivery fails, the current result remains available until cleared, replaced by another recording, or the app quits. No transcript history is stored.

## 1. Problem and product direction

The initial user wants the familiar transcription quality of MacWhisper, control over non-speech output, and more dependable text delivery than they have experienced with Handy. Their reported problems are unwanted sound descriptions and occasions when old clipboard contents appear instead of the new transcript. This document treats those as user experiences, not independently verified findings about either product's implementation or business decisions.

Build a small, native Mac menu-bar utility. Reuse existing speech recognition engines; invest engineering effort in recording, silence handling, recovery, and insertion. No account, subscription, or application backend is needed for the core workflow.

Open-source speech models are still AI. Whisper's own documentation describes hallucinated text as a known limitation. Speech detection and output handling can reduce these errors, but cannot guarantee perfect recognition in arbitrary audio. [Whisper model card](https://github.com/openai/whisper/blob/main/model-card.md)

**Primary user:** Someone who dictates messages, documents, and prompts throughout the day, including uninterrupted five-minute passages.

**Proposed platform:** Apple Silicon Macs, macOS 14 or later, subject to dependency compatibility checks. Validate on an M1 with 8 GB and an M2 with 16 GB. Intel support is a later decision, not a launch dependency.

## 2. Core experience

1. Install a signed, notarized app and open it from the menu bar.
2. On first launch, show Setup with automatic paste enabled as the default behavior. Request Accessibility first, verify both field access and permission to post paste commands, then request microphone access. Do not begin dictation until the permissions are ready; existing transcripts remain available for manual Copy. Refresh live when Settings changes, and explain how to replace an enabled entry belonging to an older app identity.
3. Choose offline transcription and download a recommended model, or select an API provider and enter a key.
4. Pick a global shortcut. Support both hold-to-record and press-to-start/press-to-stop.
5. Focus a text field, activate the shortcut, and speak. A small nonactivating overlay follows the caret or active text field, with the cat logo, live microphone waveform, elapsed time, and current shortcut. Without Accessibility permission or a supported field, anchor near the pointer. Clamp to the visible display and flip below when there is no room above.
6. Stop recording. Hold the current result in memory before attempting insertion.
7. Insert once if the destination remains suitable. Otherwise show “Transcript ready — copy or insert when ready.”

Silence produces “No speech detected,” leaves the clipboard untouched, and inserts nothing. A pause does not end a recording unless the user explicitly enables an automatic stop option in a later release.

The overlay must not steal keyboard focus. Escape cancels in the app unless assigned as the dictation shortcut. Show “Preparing model” separately from “Recording”; never imply that audio is being captured before capture has actually started.

## 3. Required capabilities

| Capability | Requirement for the first release |
|---|---|
| Global dictation | Configurable shortcuts, microphone selection, visible recording state, cancel, and at least 30-minute sessions without an artificial usage limit. |
| Offline recognition | Download, select, and delete supported local models; transcribe with networking disabled after installation. |
| Non-speech handling | Speech detection enabled by default; avoid inserting silence, instrumental music, breaths, sighs, and sound annotations. |
| API transcription | OpenAI plus an advanced endpoint compatible with the supported audio-transcription request format; keys stored in macOS Keychain. |
| Reliable delivery | Keep the current result available, validate destination and transcript, attempt insertion once, and provide explicit recovery if uncertain. |
| No history | No archive or persisted transcripts. Keep only the current result in memory; offer retry for the current failed recording during the session. |
| Long dictation | Incremental audio persistence, bounded processing chunks, stable ordering, and no repeated text at chunk boundaries. |
| Language | Automatic detection where supported; manual language preference; preserve the spoken language by default. |
| Clear failures | Explain permission, microphone, disk, model, and API errors with an actionable retry path. |

## 4. Model catalog and provider support

“Top models” means a maintained catalog of strong, tested choices, not a promise to execute every downloadable model file. Different families require different inference runtimes. Recommendations must reflect language, hardware, memory, and measured dictation quality rather than a universal ranking.

| Model family | Proposed role | Delivery plan |
|---|---|---|
| Whisper large-v3-turbo | Initial balanced-quality candidate; retain the Whisper behavior the user knows. | First working version, via whisper.cpp. |
| Whisper large-v3 | Optional larger model for users prioritizing accuracy; benchmark against Turbo on their language. | First working version, same runtime. |
| Whisper tiny/base/small/medium, including relevant English-only variants | Smaller downloads and alternatives for limited memory or quicker startup. | Catalog entries using the same runtime; test every shipped variant. |
| NVIDIA Parakeet TDT 0.6B v3 | Additional everyday dictation candidate covering 25 European languages. | First stable release, using a validated native runtime such as FluidAudio. |
| Qwen3-ASR 0.6B / 1.7B | Broader model choice for multilingual users. | Next catalog expansion after a Mac runtime, packaging, and quality evaluation. |

Whisper.cpp documents Metal acceleration, quantized models, VAD, and support for the listed Whisper sizes. Parakeet's model card lists its language coverage, and FluidAudio provides a Swift/Core ML integration path. Qwen publishes the two ASR sizes above; their presence here is not a claim that native Mac integration has already been validated. [Whisper.cpp](https://github.com/ggml-org/whisper.cpp), [Parakeet model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3), [FluidAudio](https://github.com/FluidInference/FluidAudio), [Qwen3-ASR](https://github.com/QwenLM/Qwen3-ASR)

Each model entry must identify the upstream model, exact version, parameter count, language coverage, quantization, artifact filename, download size, runtime, and source link. The v0.2 catalog contains 13 explicit Whisper variants; see [model inventory](docs/MODELS.md). Working-memory estimates and performance results must be marked unmeasured until benchmarked on a named Mac; never invent competitive rankings. Show quantized variants explicitly. Download with progress, cancellation, resumability where available, disk-space checks, and checksum verification. Install atomically and keep the prior working model until the new one validates.

Load only the selected model. Offer “Keep model ready” for faster repeated dictation and automatic unloading after inactivity for lower memory use. A small application shell does not imply small model downloads or low memory consumption during inference.

Allow local import only for formats supported by installed adapters. Model catalogs can add compatible weights; new architectures require a runtime update. Do not download and execute arbitrary repository code to load a model.

For OpenAI, use the audio transcription endpoint. Current official documentation recommends `gpt-transcribe` for completed recordings; keep model identifiers and capabilities configurable as the provider evolves. The documented file limit is 25 MB, so upload handling must enforce byte limits as well as duration limits. [OpenAI file transcription documentation](https://developers.openai.com/api/docs/guides/speech-to-text)

The advanced provider option accepts an endpoint URL, API key, and model ID. Compatibility is limited to the implemented multipart audio request and response contract; an arbitrary chat API is insufficient. Test connection and show useful errors. Additional providers with different protocols need dedicated adapters.

Cloud mode must be visibly selected. Send audio directly to the chosen provider, without an application-owned relay. Never silently switch an offline session to cloud. Explain that provider charges and data policies apply; do not imply API use is free. Failures retain the recording for retry or an explicitly selected local transcription.

## 5. Non-speech behavior

Use a layered pipeline: capture audio → detect speech intervals → transcribe those intervals → apply conservative non-speech checks → current result → deliver.

- Run local voice activity detection, such as Silero, before recognition. Preserve short leading and trailing margins to avoid clipping words.
- When no speech is detected, produce an empty result and do not touch the destination or clipboard.
- Use model-specific no-speech scores or confidence signals where available. Do not assume all providers expose comparable confidence values.
- Suppress known standalone generated annotations such as `[music]` and `[sigh]` when supported by the model's output conventions. Keep the raw result with the current in-memory transcript when filtering changes it.
- Never blanket-delete bracketed text or words such as “music,” “silence,” and “sigh.” They can be intentional speech.
- Make suppression adjustable with Normal, Strong, and Off settings, all included. Strong mode must disclose its increased risk of dropping quiet speech.
- Flag uncertain results for review instead of silently discarding a substantive transcript. Permit retry with changed settings while a failed recording is temporarily available.

VAD is not a perfect music classifier or speaker separator. Singing, television voices, and nearby conversation can contain genuine speech. Excluding every such source is beyond the initial guarantee. Use a test corpus to balance unwanted insertions against missed soft speech.

## 6. Delivery and recovery: release-critical requirements

The transcript must come from the completed recording session, never from whatever happens to be on the clipboard.

1. Assign each recording a unique session ID and hold its final transcript in memory before delivery. Reject stale callbacks from canceled or superseded sessions.
2. Remember the original destination application and focused field where accessible. Immediately before insertion, verify focus, editability, and selection stability. If the user moved to another destination or changed the insertion context, hold the result for explicit delivery.
3. Use tested Accessibility-based insertion only for controls with dependable selection-aware behavior. Never replace an entire field merely because setting its full value is possible.
4. For clipboard-based insertion, write the exact current transcript, verify the write and current clipboard contents, and check for intervening changes immediately before sending Paste. Abort on any mismatch. Never send Paste after an empty response, failed clipboard write, or canceled session.
5. Serialize insertion attempts. Never automatically retry an uncertain paste: it could duplicate text already inserted.
6. Distinguish “Transcript ready,” “Paste requested,” and “Insertion verified.” A simulated keystroke is not proof the destination accepted it.
7. In clipboard mode, leave the transcript on the clipboard by default for manual recovery. Automatic restoration of older clipboard contents is deferred until an app-specific strategy is validated; a fixed short timer can recreate the stale-content problem.

macOS exposes a pasteboard change counter that can detect intervening ownership changes. This helps detect conflicts but does not make a clipboard write and another app's paste one atomic transaction. [Apple NSPasteboard changeCount](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)

Consequently, the app cannot honestly guarantee automatic insertion into every Mac application under every race condition. On unsupported controls, secure fields, unexpected focus changes, or uncertain delivery, keep the transcript available and offer Copy. Never auto-submit a message or press Return.

Capture to a temporary audio file for processing. No restart recovery archive is required. A sleep event or disconnected microphone must produce a visible interruption. Cancellation deletes that recording; a processing failure may keep the current recording for an explicit retry during the same session.

No transcript history or retention settings. Keep only the current transcript in memory; clear it on the next successful recording start, Clear, or Quit. Delete temporary audio after success, silence, cancellation, or Quit. Failed processing retains only the current audio for Retry until discarded or replaced. Remove crash leftovers on the next launch. Upgrade from v0.1 removes its history file and old recording archive. Model downloads and API keys remain separate. Copied text follows normal clipboard behavior.

## 7. Interface and implementation shape

### Visual direction: brutalist Soviet cute cat

Apply this identity across the app icon, menu-bar mark, recording overlay, settings, model catalog, current-result view, documentation, and future distribution materials.

- **Mascot and logo:** A friendly geometric cat with triangular ears, round eyes, a small nose, and bold whiskers. Soviet constructivist poster composition: a red star, diagonal blocks, heavy silhouettes, and strong negative space. Keep the cat approachable and immediately recognizable at small sizes. Use a simplified monochrome cat for the menu bar.
- **Palette:** Warm paper cream (#F2EBDD), ink charcoal (#22231F), and vermilion red (#C9362B). Red marks the primary action and recording state. Use lighter cream for inset panels. Avoid gradients, glossy effects, glass backgrounds, and pastel interface colors.
- **Typography:** Heavy condensed lettering for short headings; readable system sans serif for transcripts and instructions; monospaced labels for time and metadata. Uppercase is reserved for short labels and headings. Transcripts retain their original case and Unicode characters.
- **Layout:** Rectangular panels, visible black rules, strong alignment, generous space, and restrained constructivist asymmetry. Decoration must not obscure controls.
- **Tone:** Warm, concise, and lightly feline. Examples: “Small app. Big ears.” and “Your words. Your machine.” Functional messages still explain what happened and how to recover.
- **States and accessibility:** Apply the theme to empty, loading, recording, success, failure, and disabled states. State labels accompany colors. Preserve keyboard navigation, visible focus, adequate contrast, readable text, and VoiceOver names. Keep motion minimal and honor Reduce Motion when animation is introduced.
- **Asset delivery:** Include the generated emblem, app icon derived from it, and generation prompt in the repository. Keep lettering separate from the raster logo for sharp, accessible branding.

The first emblem is in assets/cat-emblem.png; its prompt and provenance are in docs/BRAND.md. The interface uses shared native SwiftUI styling.

Use menu-bar controls, a recording overlay, and a dismissible utility window with Dictation, Models, Providers, Shortcuts, and Privacy. No History screen. The Shortcuts page accepts single keys, Shift-only combinations, left/right modifier keys, Fn/Globe, Caps Lock, and simultaneous multi-key chords. Capture finishes on release; Escape is bindable and Cancel is a button. Existing saved shortcuts remain compatible. Use native hotkey registration where supported and a permission-aware event tap for other chords. Save the choice even when Accessibility permission is still needed, show its inactive status, and activate it after permission is granted. Modifier-only taps fire on release and must not fire after typing or clicking with the modifier. System-reserved keys that macOS does not deliver cannot be promised. Provide a generic no-recording shortcut test, without device-specific presets. Capture must accept native hotkey notifications as well as keyboard events; remapped input that works globally must also work in the picker. Suppress repeated key-down notifications until release. The picker should capture ahead of app-level hotkey handling when permission allows, retain its local fallback, and stop on cancellation, successful assignment, window close, or deactivation. Treat the function flag carried by an F-key as separate from a physical Fn press. The default is Option-Space; hold-to-record remains a later addition.

Recommended implementation: Swift and SwiftUI for the interface, AppKit and Accessibility APIs for Mac integration, AVAudioEngine for recording, whisper.cpp for the first local backend, and a second adapter for Parakeet. Use URLSession for providers, Keychain for secrets, and in-memory current-result state plus temporary audio for processing.

Separate recording, transcription, session state, and insertion. Use an explicit session state machine: idle → preparing → recording → transcribing → ready → delivery requested → verified or needs attention. Cancellation and failure must terminate the appropriate session without permitting a late paste.

Latency delivery plan: first make press → record → press → transcribe → paste reliable and expose processing time. Keep the overlay visible until delivery or an actionable result. Local VAD should run once per request. Next, reuse a loaded model and process audio while recording using speech-boundary chunks plus overlap reconciliation; only deliver the finalized text once after Stop. Do not concatenate unstable partial results or promise zero latency. Benchmark repeated words, corrections, pauses, and five-minute sessions before enabling incremental recognition by default. API streaming requires a provider-specific adapter rather than pretending the current file-upload endpoint streams.

Keep inference off the main UI thread. Begin with a single inference worker and one active recording; a new recording replaces the current result, so recordings must not queue invisibly. Process longer audio in overlapping chunks bounded by each engine's limits, preferably near speech boundaries. Reconcile overlap without deleting intentional repeated words.

Sign updates with a stable certificate identity. Ad-hoc signing must be an explicit development-only choice because a changed binary has a changed identity; the UI must never treat a previous visible permission checkbox as proof this running process is authorized. Developer ID signing/notarization remains required for public distribution.

Ship a native application with prebuilt dependencies; users should not need Python, Homebrew, a terminal, or a running local server. Use signed direct distribution initially. No analytics by default; diagnostic exports omit recordings, transcript text, and API keys unless the user explicitly includes content.

## 8. Performance targets and acceptance criteria

These are proposed engineering targets, not measured performance claims. Benchmark with the exact OS, hardware, model, quantization, language, and warm/cold status recorded.

| Area | Target / acceptance criterion |
|---|---|
| Start responsiveness | Recording acknowledgement within 150 ms at the 95th percentile when ready; actual capture onset measured separately. |
| Everyday latency | On M2/16 GB with the selected fast model already loaded, 30 seconds of dictation ready within 3 seconds after Stop at the 95th percentile. Select the default model using this test. |
| Long-session latency | Five-minute recordings processed during capture should finish within 5 seconds after Stop on the same reference setup; show progress if inference falls behind. |
| Idle resources | With models unloaded: under 150 MB resident memory and under 1% average CPU over ten idle minutes; microphone inactive. |
| App footprint | Target under 100 MB download excluding model assets; revisit after measuring both native runtimes. |
| Correct delivery | At least 99.5% successful insertion over 1,000 trials in the supported app matrix; zero stale-clipboard or wrong-destination insertions in that suite. Remaining failures must offer recovery. |
| Session privacy | No transcript archive is created. Temporary audio is deleted on success/cancel/quit, and crash leftovers are removed next launch. Current failed audio can be retried before quitting. |
| Non-speech | No insertions on a fixed suite of at least 200 silence, instrumental music, breathing, sighing, and environmental-noise clips. This is a release test, not a universal accuracy claim. |
| Speech preservation | Filtering increases word error rate by no more than one absolute percentage point against the same engine without filtering on a paired speech corpus; review every lost short utterance. |
| Offline | Recording, recognition, and copying work with all networking disabled after model download. |

The app matrix includes TextEdit, Notes, Safari and Chrome text areas, Slack, VS Code, and the user's actual daily destinations. Test emoji and Unicode, selected text replacement, large transcripts, clipboard managers, clipboard changes during inference, rapid shortcuts, focus switches within the same app, permission denial, and attempted insertion into secure fields.

Failure tests include microphone removal, Bluetooth input changes, sleep/wake, full disk, interrupted downloads, corrupt models, API timeout, expired keys, rate limits, and app termination during capture and insertion. A failure must explain the current result or recording state and never trigger an unrelated paste.

## 9. Scope boundaries and delivery sequence

**First working version:** Native recording, one Whisper runtime with downloadable variants, VAD, an in-memory current result, temporary audio, conservative insertion, and an OpenAI provider. Prove the five-minute dictation workflow early.

**Initial implementation slice:** Build a runnable native early version before calling the first working version complete. Include the brand, menu-bar toggle shortcut, recording overlay, local Whisper with speech detection, model downloads, API settings, explicit verified copying, configurable toggle shortcuts, caret-aware cat/waveform overlay, and no history. The 0.2.4 slice adds automatic paste with destination/selection/clipboard validation, model/engine preflight, and visible processing/failure states. Configurable hold shortcuts, streaming chunks, and broad compatibility testing remain required follow-up work. Bundle a small starter model for immediate offline use; larger models remain optional downloads.

**First stable release:** Add Parakeet, the compatible-endpoint option, robust downloads, app compatibility testing, packaging, and session cleanup tests. Basic dictation, filtering, model selection, and recovery remain available without an upgrade gate.

**Subsequent additions:** Qwen and other qualified model families, audio-file import, optional live preview, custom vocabulary hints, and validated per-app delivery preferences. Vocabulary hints must be tested for introducing words that were never spoken.

**Outside the first release:** Meeting bots, speaker identification, system-audio capture, summaries, translation UI, rewriting, cloud sync, team accounts, mobile apps, and billing. Transcription preserves what the user says; generative cleanup is not part of the default pipeline.

Planning estimate for one experienced macOS engineer: roughly 2–4 weeks for a usable narrow build and 6–10 weeks total for a tested release with two local runtimes. These are judgment estimates, not commitments; runtime packaging and insertion compatibility are the largest uncertainties. Supporting more model families expands ongoing maintenance.

The fastest personal workaround could be investigating Handy's existing delivery code, since Handy is open source. This PRD recommends a native app when the objective is an independently controlled, minimal Mac utility; it does not assume a rewrite is required to fix the reported bug. [Handy repository](https://github.com/cjpais/Handy)

**Definition of done:** The user can dictate for five minutes, pause naturally, obtain a clean transcript with a chosen offline model or API, and recover the result immediately if insertion fails—without repeating the dictation.

### Permission refresh recovery

When Accessibility is approved but the running process still reports paste-command access denied, Setup must acknowledge the grant and offer a restart to recheck access. Do not send users through repeated Accessibility approval. Restart must preserve active recording, processing, downloads, current results, and retry audio by requiring those to be completed or explicitly cleared first.
