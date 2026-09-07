#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
cmake_bin="${CMAKE_BIN:-cmake}"
command -v "$cmake_bin" >/dev/null || { echo "Install CMake or set CMAKE_BIN."; exit 1; }
revision=e2f82cb6702315a1194f3bf1a6fee67cd2678447
mkdir -p .build/extra-engine/source vendor/runtime
archive=.build/extra-engine/source.tar.gz
curl -fL --retry 2 "https://github.com/handy-computer/transcribe.cpp/archive/$revision.tar.gz" -o "$archive"
echo "c8abdcda8a6142b769e2fc08423ee0bb27dd065d4436bb01ff1d37859c055cf6  $archive" | shasum -a 256 -c -
tar -xzf "$archive" --strip-components=1 -C .build/extra-engine/source
"$cmake_bin" -S .build/extra-engine/source -B .build/extra-engine/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 -DTRANSCRIBE_BUILD_TESTS=OFF -DTRANSCRIBE_BUILD_SHARED=OFF -DTRANSCRIBE_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DGGML_NATIVE=OFF
"$cmake_bin" --build .build/extra-engine/build -j 6 --target transcribe-cli
cp .build/extra-engine/build/bin/transcribe-cli vendor/runtime/
echo 'Additional native speech engine ready.'
