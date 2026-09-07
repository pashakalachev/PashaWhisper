#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export SWIFT_MODULECACHE_PATH="$PWD/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
for required in vendor/runtime/whisper-cli vendor/runtime/whisper-vad-speech-segments vendor/ggml-silero.bin vendor/ggml-tiny.en-q5_1.bin; do
  test -f "$required" || { echo "Missing $required. Run scripts/prepare-runtime.sh first."; exit 1; }
done
swift build -c release --disable-sandbox
bin_dir="$(swift build -c release --show-bin-path --disable-sandbox)"
# A stable certificate identity keeps macOS permissions associated with updates.
# Ad-hoc signing must be explicitly requested for disposable development builds.
signing_identity="${CODE_SIGN_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
  signing_identity=$(security find-identity -v -p codesigning | python3 -c '
import re, sys
entries = re.findall(r"([0-9A-F]{40}) \"([^\"]+)\"", sys.stdin.read())
for prefix in ("Developer ID Application:", "Apple Development:"):
    matches = [key for key, name in entries if name.startswith(prefix)]
    if len(matches) == 1:
        print(matches[0]); break
    if len(matches) > 1:
        sys.exit("Multiple signing identities. Set CODE_SIGN_IDENTITY explicitly.")
else:
    sys.exit("No signing certificate found. Set CODE_SIGN_IDENTITY, or explicitly use CODE_SIGN_IDENTITY=- for a disposable ad-hoc build.")
')
fi
app="$PWD/dist/PashaWhisper.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Helpers"
cp "$bin_dir/PashaWhisper" "$app/Contents/MacOS/"
cp -R "$bin_dir/PashaWhisper_PashaWhisper.bundle" "$app/Contents/Resources/"
cp vendor/runtime/whisper-cli vendor/runtime/whisper-vad-speech-segments "$app/Contents/Helpers/"
cp vendor/ggml-silero.bin vendor/ggml-tiny.en-q5_1.bin "$app/Contents/Resources/"
cp assets/cat-emblem.png "$app/Contents/Resources/"
cp docs/THIRD_PARTY_NOTICES.md "$app/Contents/Resources/"
iconset="$PWD/.build/AppIcon.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" assets/cat-emblem.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" assets/cat-emblem.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PashaWhisper</string>
<key>CFBundleIdentifier</key><string>com.pasha.whisper</string>
<key>CFBundleName</key><string>PashaWhisper</string>
<key>CFBundleDisplayName</key><string>PashaWhisper</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.5</string>
<key>CFBundleVersion</key><string>7</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSMicrophoneUsageDescription</key><string>PashaWhisper records your voice only when you start dictation.</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
codesign --force --sign "$signing_identity" "$app/Contents/Helpers/whisper-cli"
codesign --force --sign "$signing_identity" "$app/Contents/Helpers/whisper-vad-speech-segments"
codesign --force --sign "$signing_identity" "$app"
codesign --verify --deep --strict "$app"
echo "Built: $app"
