#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
cmake_bin="${CMAKE_BIN:-cmake}"
command -v "$cmake_bin" >/dev/null || { echo "Install CMake for development, or set CMAKE_BIN to its executable."; exit 1; }
mkdir -p .build/engine vendor/runtime
archive=.build/engine/whisper-1.8.6.tar.gz
curl -fL --retry 2 https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v1.8.6.tar.gz -o "$archive"
echo "f8e632016ceae556f3132a16c7f704be1e7715595041f474fa81a2b64c1abf7c  $archive" | shasum -a 256 -c -
mkdir -p .build/engine/source
tar -xzf "$archive" --strip-components=1 -C .build/engine/source
"$cmake_bin" -S .build/engine/source -B .build/engine/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DBUILD_SHARED_LIBS=OFF -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_NATIVE=OFF -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF
"$cmake_bin" --build .build/engine/build -j 6 --target whisper-cli whisper-vad-speech-segments
cp .build/engine/build/bin/whisper-cli .build/engine/build/bin/whisper-vad-speech-segments vendor/runtime/
curl -fL --retry 2 https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin -o vendor/ggml-silero.bin
echo '2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987  vendor/ggml-silero.bin' | shasum -a 256 -c -
curl -fL --retry 2 https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin -o vendor/ggml-tiny.en-q5_1.bin
echo '3fb92ec865cbbc769f08137f22470d6b66e071b6  vendor/ggml-tiny.en-q5_1.bin' | shasum -a 1 -c -
CMAKE_BIN="$cmake_bin" bash scripts/prepare-extra-runtime.sh
echo 'Runtime and starter model ready. Run bash scripts/build-app.sh.'
