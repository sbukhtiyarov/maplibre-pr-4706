#!/usr/bin/env bash
set -euo pipefail
# Build inside the container; only the resulting APK is written to the host.
cp -a /opt/repro /tmp/repro
cd /tmp/repro
mkdir -p /output
build_apk() {
    local variant=$1 output=$2
    shift 2
    bash gradlew --no-daemon :app:assembleDebug "-PmaplibreVersion=${1:-11.11.0}" "-PreproVariant=$variant" "${@:2}"
    cp app/build/outputs/apk/debug/app-debug.apk "/output/$output"
    if [[ -n ${HOST_UID:-} && -n ${HOST_GID:-} ]]; then
        chown "$HOST_UID:$HOST_GID" "/output/$output"
    fi
}
if [[ ${2:-pair} == pair ]]; then
    patched=/input/maplibre.aar
    if [[ ! -f $patched ]]; then
        [[ ${1:-11.11.0} == 11.11.0 ]] || { echo 'Bundled patch requires SDK 11.11.0. Supply an AAR for other versions.' >&2; exit 2; }
        bash native/build.sh
        patched=/tmp/patched-sdk/patched.aar
        cp /tmp/patched-sdk/manifest.json /output/patched-sdk-manifest.json
    fi
    build_apk unpatched maplibre-unpatched.apk "${1:-11.11.0}"
    build_apk fixed maplibre-fixed.apk "${1:-11.11.0}" "-PmaplibreAar=$patched"
else
    args=()
    if [[ -f /input/maplibre.aar ]]; then args+=(-PmaplibreAar=/input/maplibre.aar); fi
    build_apk default maplibre-repro.apk "${1:-11.11.0}" "${args[@]}"
fi
