#!/usr/bin/env bash
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cache="${GRADLE_USER_HOME:-/gradle-cache}/maplibre-4706-native"
commit=753b7ae79563a1d5da27135d0f496fdce6aeb651
ndk=28.1.13356709
cmake_version=3.31.6
mkdir -p "$cache"
exec 9>"$cache/build.lock"
flock 9
key="$(cat "$here/build.sh" "$here/package.py" "$here/fix.patch" "$here/LICENSE" | sha256sum | cut -d' ' -f1)"
work="$(realpath -m "$cache/$key")"
mkdir -p "$work"
if [[ -f "$work/manifest.json" ]] && python3 -c \
    'import json,sys; sys.exit(json.load(open(sys.argv[1]))["recipeSha256"] != sys.argv[2])' "$work/manifest.json" "$key"; then
    python3 "$here/package.py" verify "$work"
else
    sdkmanager "ndk;$ndk" "cmake;$cmake_version"
    export PATH="$ANDROID_HOME/cmake/$cmake_version/bin:$PATH"
    if [[ ! -d "$work/source/.git" ]]; then
        git clone --depth 1 --branch android-v11.11.0 https://github.com/maplibre/maplibre-native.git "$work/source"
    fi
    test "$(git -C "$work/source" rev-parse HEAD)" = "$commit"
    if ! git -C "$work/source" apply --reverse --check "$here/fix.patch" 2>/dev/null; then
        git -C "$work/source" apply --check "$here/fix.patch"
        git -C "$work/source" apply "$here/fix.patch"
    fi
    git -C "$work/source" submodule update --init --recursive --jobs 4 -- vendor
    if [[ ! -f "$work/upstream.aar" ]]; then
        curl -fL --retry 3 https://repo.maven.apache.org/maven2/org/maplibre/gl/android-sdk/11.11.0/android-sdk-11.11.0.aar -o "$work/upstream.aar"
    fi
    echo "2e3c027138158528cbcbf24afc8d1335d0fc2b9c3fa8d1023fe6d53ca269a0b4  $work/upstream.aar" | sha256sum -c -
    for abi in x86_64 arm64-v8a; do
        binary="$work/build-$abi/platform/android/MapLibreAndroid/src/cpp"
        cmake -S "$work/source/platform/android/MapLibreAndroid/src/cpp" -B "$binary" -G Ninja \
            -DCMAKE_TOOLCHAIN_FILE="$ANDROID_HOME/ndk/$ndk/build/cmake/android.toolchain.cmake" \
            -DANDROID_ABI="$abi" -DANDROID_PLATFORM=android-23 -DANDROID_STL=c++_static \
            -DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_SHARED_LINKER_FLAGS="--ld-path=$ANDROID_HOME/ndk/$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/ld.lld" \
            -DMLN_WITH_OPENGL=ON -DMLN_WITH_VULKAN=OFF -DMLN_WITH_WERROR=OFF
        cmake --build "$binary" --target maplibre -j "${MAPLIBRE_BUILD_JOBS:-4}"
        mkdir -p "$work/libs/$abi"
        library="$(find "$work/build-$abi" -name libmaplibre.so -print -quit)"
        test -n "$library"
        "$ANDROID_HOME/ndk/$ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip" --strip-unneeded "$library" -o "$work/libs/$abi/libmaplibre.so"
    done
    python3 "$here/package.py" build "$work" "$here" "$key"
fi
mkdir -p /tmp/patched-sdk
cp "$work/patched.aar" "$work/manifest.json" /tmp/patched-sdk/
