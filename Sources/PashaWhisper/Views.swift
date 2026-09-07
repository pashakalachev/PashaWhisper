import SwiftUI
import AppKit
import WhisperCore

struct MainView: View {
    @EnvironmentObject var model: AppModel
    private let sections = [("Dictation", "waveform"), ("Models", "square.stack.3d.up"), ("Providers", "network"), ("Shortcuts", "keyboard"), ("Privacy", "lock")]
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    CatMark().frame(width: 37, height: 37)
                    Text("PASHA\nWHISPER").font(Theme.title(21)).lineSpacing(-3)
                }.padding(.bottom, 27)
                SmallLabel(text: "Speech department / 01").padding(.bottom, 24)
                ForEach(sections, id: \.0) { item in
                    Button { model.cancelShortcutCapture(); model.testingShortcut = false; model.section = item.0 } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.1).frame(width: 18)
                            Text(item.0).font(.system(size: 14, weight: .semibold))
                            Spacer()
                            if model.section == item.0 { Text("↗").font(.system(size: 17, weight: .bold)) }
                        }.padding(.horizontal, 12).padding(.vertical, 13)
                            .foregroundStyle(model.section == item.0 ? Theme.paper : Theme.ink)
                            .background(model.section == item.0 ? Theme.ink : .clear)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .focusEffectDisabled(!model.keyboardNavigation)
                        .padding(.bottom, 5)
                }
                Spacer()
                Rule().padding(.bottom, 15)
                HStack(spacing: 7) {
                    Circle().fill(model.provider == "Offline" ? Theme.ink : Theme.red).frame(width: 6, height: 6)
                    Text(model.provider == "Offline" ? "LOCAL BY DEFAULT" : "CLOUD SELECTED").font(Theme.mono(10))
                }
                Text("Small app. Big ears.").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(.top, 8)
                Text("EARLY BUILD  /  0.2.3").font(Theme.mono(9)).foregroundStyle(Theme.muted).padding(.top, 20)
            }.padding(22).frame(width: 230).background(Theme.paper)
            Rectangle().fill(Theme.ink).frame(width: 2)
            VStack(spacing: 0) {
                if let error = model.error {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                        Button { model.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Dismiss error")
                    }.padding(14).foregroundStyle(Theme.paper).background(Theme.red)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        switch model.section {
                        case "Models": ModelsView()
                        case "Providers": ProvidersView()
                        case "Shortcuts": ShortcutsView()
                        case "Privacy": PrivacyView()
                        default: DictationView()
                        }
                    }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.background(Theme.paper)
        }.foregroundStyle(Theme.ink).frame(minWidth: 900, minHeight: 650)
            .preferredColorScheme(.light).tint(Theme.red).accentColor(Theme.red)
    }
}

struct PageHeading: View {
    let number: String, title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SmallLabel(text: "PashaWhisper  /  \(number)")
            Text(title).font(Theme.title())
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
        }
    }
}

struct DictationView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeading(number: "01 — Dictation", title: "LESS TYPING.\nMORE MEOW.", subtitle: "A little cat with a very good ear.")
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Text(model.recording ? "● ON AIR" : model.transcribing ? "◌ PROCESSING" : "● STANDING BY")
                        .font(Theme.mono(10)).tracking(1).foregroundStyle(Theme.red)
                    Spacer()
                    Text(time(model.elapsed)).font(Theme.mono(13))
                }
                Text(model.status).font(.system(size: 24, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                Text(model.detail).font(.system(size: 12)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
                if model.recording {
                    GeometryReader { geo in
                        Rectangle().fill(Theme.ink.opacity(0.12))
                        Rectangle().fill(Theme.red).frame(width: max(3, geo.size.width * CGFloat(model.level)))
                    }.frame(height: 8).accessibilityLabel("Microphone level")
                }
                HStack(spacing: 12) {
                    Button { model.toggleRecording() } label: {
                        Label(model.recording ? "STOP & TRANSCRIBE" : "START DICTATION", systemImage: model.recording ? "stop.fill" : "mic.fill")
                    }.buttonStyle(BlockButton(primary: true)).disabled(model.transcribing || model.preparing)
                    if model.busy { Button("CANCEL") { model.cancel() }.buttonStyle(BlockButton()) }
                }
                Text("\(model.shortcut.display.uppercased())  TO START / STOP").font(Theme.mono(10)).foregroundStyle(Theme.muted)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(nsImage: NSImage(contentsOf: Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/cat-emblem.png")) ?? NSImage()).resizable().scaledToFit().frame(width: 160, height: 180)
                .accessibilityLabel("Cute geometric cat with red star and microphone")
        }.padding(22).background(Theme.sheet).overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
        HStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                SmallLabel(text: "Engine")
                Picker("Engine", selection: $model.provider) {
                    Text("Offline").tag("Offline"); Text("OpenAI").tag("OpenAI"); Text("Custom API").tag("Custom API")
                }.labelsHidden().frame(width: 145)
            }
            VStack(alignment: .leading, spacing: 8) {
                SmallLabel(text: "Speech filtering")
                Picker("Speech filtering", selection: $model.suppression) {
                    ForEach(Suppression.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.labelsHidden().frame(width: 125)
            }
            VStack(alignment: .leading, spacing: 8) {
                SmallLabel(text: "Language")
                Picker("Language", selection: $model.language) {
                    Text("Automatic").tag("auto"); Text("English").tag("en"); Text("Russian").tag("ru")
                    Text("Spanish").tag("es"); Text("French").tag("fr"); Text("German").tag("de")
                }.labelsHidden().frame(width: 130)
            }
        }.disabled(model.busy)
        if model.suppression == .strong {
            Text("Strong filtering can miss quiet speech. Use Normal if words are being dropped.").font(.system(size: 12)).foregroundStyle(Theme.red)
        }
        if model.retryAvailable {
            HStack {
                Text("This recording can be retried until you quit or start another.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                Spacer()
                Button("RETRY") { model.retryCurrent() }.buttonStyle(BlockButton()).disabled(model.busy)
                Button("DISCARD") { model.clearCurrent() }.buttonStyle(BlockButton()).disabled(model.busy)
            }
        }
        Rule()
        HStack {
            SmallLabel(text: "Current result · session only")
            Spacer()
            if let latest = model.latest { Button("COPY TRANSCRIPT") { model.copy(latest) }.buttonStyle(BlockButton()) }
        }
        if let latest = model.latest {
            Text(latest.text).font(.system(size: 16)).lineSpacing(5).textSelection(.enabled)
            SmallLabel(text: "In memory · \(latest.provider) · \(latest.createdAt.formatted(date: .omitted, time: .shortened))")
        } else {
            Text("Your first words belong here.").font(.system(size: 17, weight: .medium))
            Text("Record, transcribe, then copy into any app. This early build keeps delivery manual while automatic insertion is being built.")
                .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4)
        }
    }
    private func time(_ value: TimeInterval) -> String { String(format: "%02d:%02d", Int(value) / 60, Int(value) % 60) }
}

struct ModelsView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    var filtered: [LocalModel] {
        LocalModel.catalog.filter { query.isEmpty || "\($0.title) \($0.id) \($0.precision)".localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        PageHeading(number: "02 — Models", title: "KNOW YOUR EARS.", subtitle: "Exact models. Exact versions. No mystery presets.")
        PosterCard {
            VStack(alignment: .leading, spacing: 8) {
                SmallLabel(text: "Selected offline model")
                Text(model.model.title).font(.system(size: 19, weight: .bold))
                Text("\(model.model.precision) · \(model.model.parameters) parameters · \(model.model.size)").font(Theme.mono(11))
                Text(model.model.filename).font(Theme.mono(11)).textSelection(.enabled)
            }
        }
        HStack {
            Text("\(LocalModel.catalog.count) Whisper variants · whisper.cpp 1.8.6").font(Theme.mono(11))
            Spacer()
        }
        TextField("Search a model, version, or precision…", text: $query).textFieldStyle(.roundedBorder)
        Text("F16 is the original inference precision. Q8 and Q5 reduce download size and memory, with a possible accuracy tradeoff. All models below are OpenAI Whisper, converted for whisper.cpp.")
            .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
        VStack(spacing: 0) {
            ForEach(filtered) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.title).font(.system(size: 17, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                            Text("\(item.precision) · \(item.parameters) parameters · \(item.size)").font(Theme.mono(10)).foregroundStyle(Theme.red)
                            Text(item.detail).font(.system(size: 11)).foregroundStyle(Theme.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if model.installed.contains(item.id) {
                            VStack(alignment: .trailing, spacing: 10) {
                                Button(item.id == model.selectedModel ? "SELECTED" : "USE MODEL") { model.selectedModel = item.id }
                                    .buttonStyle(BlockButton(primary: item.id == model.selectedModel)).disabled(model.busy || item.id == model.selectedModel)
                                if item.id != model.selectedModel {
                                    Button("Delete download") { model.deleteModel(item) }.buttonStyle(.plain).font(.system(size: 11)).disabled(model.busy)
                                }
                            }
                        } else if model.downloading == item.id {
                            Button("CANCEL") { model.cancelDownload() }.buttonStyle(BlockButton())
                        } else {
                            Button("DOWNLOAD ↓") { model.download(item) }.buttonStyle(BlockButton()).disabled(model.downloading != nil || model.busy)
                        }
                    }
                    Text(item.filename).font(Theme.mono(10)).textSelection(.enabled).foregroundStyle(Theme.muted)
                    HStack {
                        Link("Model card ↗", destination: item.modelCard)
                        Spacer()
                        Text(item.upstreamID).textSelection(.enabled)
                    }.font(Theme.mono(10))
                    if model.downloading == item.id {
                        ProgressView(value: model.downloadProgress).tint(Theme.red)
                        Text("\(model.downloadStatus)  \(Int(model.downloadProgress * 100))%").font(Theme.mono(10))
                    }
                }.padding(16).background(item.id == model.selectedModel ? Theme.sheet : Theme.paper)
                Rule()
            }
        }.overlay(Rectangle().stroke(Theme.ink, lineWidth: 2))
        if filtered.isEmpty { Text("No matching model. Try Whisper, Turbo, Q5, Q8, or F16.").font(.system(size: 13)) }
        SmallLabel(text: "Next engines · not available in this build")
        Text("NVIDIA Parakeet TDT 0.6B v3\nQwen3-ASR 0.6B / 1.7B").font(.system(size: 15, weight: .semibold)).lineSpacing(6)
        Text("These are separate model families, not other Whisper sizes. They need their own native adapters and evaluation before we can offer downloads.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
        HStack {
            Link("Whisper artifacts ↗", destination: URL(string: "https://huggingface.co/ggerganov/whisper.cpp")!)
            Spacer()
            Link("Parakeet ↗", destination: URL(string: "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3")!)
            Link("Qwen3-ASR ↗", destination: URL(string: "https://github.com/QwenLM/Qwen3-ASR")!)
        }.font(Theme.mono(11))
    }
}

struct ProvidersView: View {
    @EnvironmentObject var model: AppModel
    @State private var key = ""
    @State private var saved = false
    var body: some View {
        PageHeading(number: "03 — Providers", title: "YOUR KEY. YOUR CALL.", subtitle: "Local by default. Cloud only when you choose it.")
        Picker("Transcription provider", selection: $model.provider) {
            Text("Offline").tag("Offline"); Text("OpenAI").tag("OpenAI"); Text("Custom API").tag("Custom API")
        }.pickerStyle(.segmented).disabled(model.busy)
        PosterCard {
            VStack(alignment: .leading, spacing: 18) {
                if model.provider == "Offline" {
                    CatMark().frame(width: 55, height: 55)
                    Text("This cat stays home.").font(Theme.title(26))
                    Text("Audio is transcribed on your Mac using your selected Whisper model. No API key or internet connection is needed.").font(.system(size: 14)).lineSpacing(5)
                    Button("CHOOSE A LOCAL MODEL") { model.section = "Models" }.buttonStyle(BlockButton())
                } else {
                    SmallLabel(text: "Transcription endpoint")
                    if model.provider == "OpenAI" {
                        Text(model.actualEndpoint).font(Theme.mono(11)).textSelection(.enabled)
                        Text("Model: gpt-transcribe").font(Theme.mono(12))
                    } else {
                        TextField("https://provider.example/v1/audio/transcriptions", text: $model.endpoint).textFieldStyle(.roundedBorder)
                        TextField("Model ID", text: $model.apiModel).textFieldStyle(.roundedBorder)
                    }
                    SmallLabel(text: "API key · stored in macOS Keychain")
                    SecureField("Paste your API key here", text: $key).textFieldStyle(.roundedBorder)
                    if !Keychain.load(account: model.keyAccount).isEmpty {
                        Text("A key is already saved for this endpoint.").font(Theme.mono(10)).foregroundStyle(Theme.muted)
                    }
                    HStack {
                        Button("SAVE KEY") {
                            do { _ = try EndpointPolicy.validate(model.actualEndpoint); try Keychain.save(key.trimmingCharacters(in: .whitespacesAndNewlines), account: model.keyAccount); saved = true }
                            catch { model.error = error.localizedDescription }
                        }.buttonStyle(BlockButton(primary: true))
                        if saved { Text("Saved in Keychain.").font(Theme.mono(11)) }
                    }
                    Text("Audio goes directly to this provider after you stop recording. Provider charges and data policies apply. An empty key removes the saved key; local custom servers may not need one.")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
                }
            }.disabled(model.busy)
                .onChange(of: model.provider) { _, _ in key = ""; saved = false }
                .onChange(of: model.endpoint) { _, _ in key = ""; saved = false }
        }
        Text("Custom providers must accept multipart audio uploads and return JSON with a text field. This build never silently falls back from offline to cloud.")
            .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
    }
}

struct ShortcutsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeading(number: "04 — Shortcuts", title: "YOUR KEYS. YOUR RHYTHM.", subtitle: "Choose the combination you reach for without thinking.")
        PosterCard {
            VStack(alignment: .leading, spacing: 18) {
                SmallLabel(text: "Start / stop dictation")
                Text(model.capturingShortcut ? model.shortcutDraft : model.shortcut.display).font(Theme.title(30))
                Text("Press and release any key or combination: Space, Escape, F-keys, Shift, right Option, Fn / Globe, or several keys together. Use Cancel to leave the picker.")
                    .font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4)
                HStack {
                    if model.capturingShortcut {
                        Button("CANCEL") { model.cancelShortcutCapture() }.buttonStyle(BlockButton())
                    } else {
                        Button("CHANGE SHORTCUT") { model.beginShortcutCapture() }.buttonStyle(BlockButton(primary: true))
                        Button("RESET TO ⌥SPACE") { model.beginShortcutCapture(); model.setShortcut(.standard) }.buttonStyle(BlockButton())
                    }
                }.disabled(model.busy)
                if model.capturingShortcut {
                    Text(model.shortcutCaptureHint).font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                HStack {
                    Button("USE F18 PEDAL") { model.cancelShortcutCapture(); model.setShortcut(.f18Pedal) }.buttonStyle(BlockButton()).disabled(model.busy)
                    Text("Assign F18 directly without listening. macOS may label F18 as Fn+F18; the function-key flag alone does not require a physical Fn press.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                HStack {
                    if model.testingShortcut {
                        Button("FINISH TEST") { model.testingShortcut = false }.buttonStyle(BlockButton())
                        Text(model.shortcutTestCount == 0 ? "Testing: press your pedal. No audio will be recorded." : "Received \(model.shortcut.display) · \(model.shortcutTestCount) press(es). No audio recorded.")
                            .font(.system(size: 12)).foregroundStyle(Theme.ink)
                    } else {
                        Button("TEST SHORTCUT") { model.beginShortcutTest() }.buttonStyle(BlockButton()).disabled(model.busy || model.capturingShortcut || model.shortcutNotice != nil)
                    }
                }
                Text("Single-key shortcuts take over that key. Modifier-only shortcuts trigger on release, so using the modifier to type does not start dictation. Multi-key chords can type their first keys before the chord completes.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                if let notice = model.shortcutNotice {
                    Text(notice).font(.system(size: 12)).foregroundStyle(Theme.red)
                    Button("ENABLE SHORTCUT ACCESS") { model.requestAccessibility() }.buttonStyle(BlockButton())
                }
                Text("macOS may reserve hardware or system shortcuts; keys must reach the app to be captured. Set the keyboard's top row to standard function keys when using F1–F12.").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
        }
        Rule()
        SmallLabel(text: "Recording indicator")
        Text("A little cat, right where you write.").font(Theme.title(24))
        Text("The floating indicator follows the active text cursor or field and shows your microphone's live waveform. It never takes keyboard focus.").font(.system(size: 13)).lineSpacing(4)
        HStack {
            Button("PREVIEW INDICATOR") { model.onPreviewOverlay?() }.buttonStyle(BlockButton()).disabled(model.busy)
            if !model.accessibilityGranted {
                Button("ENABLE FIELD POSITIONING") { model.requestAccessibility() }.buttonStyle(BlockButton(primary: true))
            }
        }
        Text(model.accessibilityGranted ? "Accessibility is enabled. Fields that don't expose their position use the pointer as a fallback." : "Allow Accessibility in System Settings to position the indicator at a text field. Until then, it appears near the pointer.")
            .font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
    }
}

struct PrivacyView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        PageHeading(number: "05 — Privacy", title: "NO ARCHIVE. JUST WORDS.", subtitle: "No transcript history. No account. No analytics.")
        PosterCard {
            VStack(alignment: .leading, spacing: 18) {
                CatMark().frame(width: 55, height: 55)
                Text("A short memory. By design.").font(Theme.title(26))
                Text("Only the current result is held in memory for copying. It disappears when you begin another dictation, clear it, or quit. Transcripts are never written to a history file.").font(.system(size: 13)).lineSpacing(4)
                Rule()
                Text("Recording uses a temporary audio file. It is deleted after success, silence, cancellation, or quitting. If transcription fails, you can retry it during this session. Temporary leftovers from a crash are removed on the next launch.").font(.system(size: 13)).lineSpacing(4)
                Text("Copied text remains on your clipboard until you replace it. API mode sends audio directly to the provider you selected.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
                Button("CLEAR CURRENT RESULT") { model.clearCurrent() }.buttonStyle(BlockButton()).disabled(model.busy || (model.latest == nil && !model.retryAvailable))
            }
        }
    }
}

struct RecordingOverlay: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var preview = false
    private var amplitudes: [Float] {
        preview ? [0.12,0.2,0.4,0.7,0.9,0.5,0.3,0.6,1,0.8,0.4,0.2,0.15,0.45,0.75,0.95,0.6,0.3,0.5,0.8,0.35,0.1] : model.levels
    }
    var body: some View {
        HStack(spacing: 12) {
            CatMark(color: Theme.paper, eyeColor: Theme.ink).frame(width: 31, height: 31)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Circle().fill(Theme.red).frame(width: 5, height: 5)
                    Text(preview ? "PREVIEW" : "RECORDING").font(Theme.mono(8)).tracking(1.3)
                }
                HStack(alignment: .center, spacing: 3) {
                    ForEach(Array(amplitudes.enumerated()), id: \.offset) { _, amplitude in
                        RoundedRectangle(cornerRadius: 1).fill(Theme.paper)
                            .frame(width: 3, height: max(3, CGFloat(amplitude) * 24))
                    }
                }.frame(height: 24).animation(reduceMotion || preview ? nil : .linear(duration: 0.08), value: amplitudes)
                    .accessibilityLabel(preview ? "Sample waveform" : "Live microphone waveform")
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Text(String(format: "%02d:%02d", Int(model.elapsed) / 60, Int(model.elapsed) % 60)).font(Theme.mono(13))
                Text(model.shortcut.display).font(Theme.mono(9)).opacity(0.7)
            }
        }.padding(.horizontal, 14).foregroundStyle(Theme.paper).frame(width: 292, height: 64)
            .background(Theme.ink).overlay(Rectangle().stroke(Theme.red, lineWidth: 1.5))
    }
}
