#!/usr/bin/env bash
set -euo pipefail
# Build inside the container; only the resulting APK is written to the host.
cp -a /opt/repro /tmp/repro
cd /tmp/repro
args=(--no-daemon :app:assembleDebug "-PmaplibreVersion=${1:-11.11.0}")
if [[ -f /input/maplibre.aar ]]; then
    args+=(-PmaplibreAar=/input/maplibre.aar)
fi
bash gradlew "${args[@]}"
cp app/build/outputs/apk/debug/app-debug.apk /output/maplibre-repro.apk
if [[ -n ${HOST_UID:-} && -n ${HOST_GID:-} ]]; then
    chown "$HOST_UID:$HOST_GID" /output/maplibre-repro.apk
fi
