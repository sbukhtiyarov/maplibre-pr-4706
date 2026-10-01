#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
adb_bin="${ADB:-adb}"
serial=emulator-5554
apk="$root/build/docker/maplibre-repro.apk"
logcat=true
while (($#)); do
    case "$1" in
        --serial) serial="${2:?Missing serial}"; shift 2 ;;
        --adb) adb_bin="${2:?Missing adb path}"; shift 2 ;;
        --apk) apk="${2:?Missing APK path}"; shift 2 ;;
        --no-logcat) logcat=false; shift ;;
        -h|--help) echo "Usage: $0 [--serial DEVICE] [--adb PATH] [--apk FILE] [--no-logcat]"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
if [[ ! -f $apk ]]; then echo "APK not found: $apk. Run build-docker.sh first." >&2; exit 2; fi
"$adb_bin" -s "$serial" get-state
if ! "$adb_bin" -s "$serial" install -r "$apk"; then
    echo 'Install failed. If signatures differ, uninstall org.example.maplibrerepro explicitly, then retry.' >&2
    exit 1
fi
"$adb_bin" -s "$serial" shell am force-stop org.example.maplibrerepro
"$adb_bin" -s "$serial" shell am start -W -n org.example.maplibrerepro/.MainActivity --ez autoStart true
if $logcat; then
    echo 'Streaming logs (Ctrl+C stops logging; the app continues until 120 frames or a crash).'
    "$adb_bin" -s "$serial" logcat -v threadtime -T 1 SnapshotRepro:I AndroidRuntime:E libc:F DEBUG:F '*:S'
fi
