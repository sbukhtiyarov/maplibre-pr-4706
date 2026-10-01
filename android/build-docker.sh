#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
version=11.11.0
aar=
while (($#)); do
    case "$1" in
        --version) version="${2:?Missing SDK version}"; shift 2 ;;
        --aar) aar="$(realpath -- "${2:?Missing AAR path}")"; shift 2 ;;
        -h|--help) echo "Usage: $0 [--version VERSION] [--aar FILE]"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
if [[ -n $aar && ! -f $aar ]]; then echo "AAR not found: $aar" >&2; exit 2; fi
image=maplibre-pr-4706-android
docker build --platform linux/amd64 --build-arg "BASE_IMAGE=${BASE_IMAGE:-cimg/android:2026.07.1}" -t "$image" "$root"
mkdir -p "$root/build/docker"
args=(run --rm --platform linux/amd64
    --mount "type=volume,source=${GRADLE_CACHE_VOLUME:-maplibre-4706-gradle},target=/gradle-cache"
    --mount type=volume,source=maplibre-4706-signing,target=/root/.android
    --mount "type=bind,source=$root/build/docker,target=/output"
    -e "HOST_UID=$(id -u)" -e "HOST_GID=$(id -g)")
if [[ -n $aar ]]; then args+=(--mount "type=bind,source=$aar,target=/input/maplibre.aar,readonly"); fi
docker "${args[@]}" "$image" "$version"
echo "APK: $root/build/docker/maplibre-repro.apk"
