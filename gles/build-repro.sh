#!/usr/bin/env bash
set -euo pipefail
ndk="${ANDROID_NDK_HOME:-$ANDROID_HOME/ndk/28.1.13356709}"
repro_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
abi="${ANDROID_ABI:-x86_64}"
case "$abi" in
  x86_64) target=x86_64-linux-android21 ;;
  arm64-v8a) target=aarch64-linux-android21 ;;
  *) echo "Unsupported ANDROID_ABI: $abi" >&2; exit 2 ;;
esac
"$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/${target}-clang++" \
  -std=c++17 -O1 -g -Wall -Wextra -Werror -static-libstdc++ \
  -Wl,-z,max-page-size=16384 "$repro_dir/vao-repro.cpp" \
  -lEGL -lGLESv3 -o "$repro_dir/vao-repro"
