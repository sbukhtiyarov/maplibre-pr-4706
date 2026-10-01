#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
version=11.11.0
aar=
mode=pair
[[ ${MAPLIBRE_BUILD_JOBS:-8} =~ ^[1-9][0-9]*$ ]] || { echo 'MAPLIBRE_BUILD_JOBS must be a positive integer.' >&2; exit 2; }
while (($#)); do
    case "$1" in
        --version) version="${2:?Missing SDK version}"; shift 2 ;;
        --aar) aar="$(realpath -- "${2:?Missing AAR path}")"; shift 2 ;;
        --pair) mode=pair; shift ;;
        --single) mode=single; shift ;;
        -h|--help) echo "Usage: $0 [--version VERSION] [--aar FILE] [--single] (default: build both APKs and the patched SDK)"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done
if [[ -n $aar && ! -f $aar ]]; then echo "AAR not found: $aar" >&2; exit 2; fi
if [[ $mode == pair && -z $aar && $version != 11.11.0 ]]; then echo 'The bundled patch requires SDK 11.11.0; provide --aar for other versions.' >&2; exit 2; fi
image=maplibre-pr-4706-android
docker build --platform linux/amd64 --build-arg "BASE_IMAGE=${BASE_IMAGE:-cimg/android:2026.07.1}" -t "$image" "$root"
mkdir -p "$root/build/docker"
container="maplibre-4706-build-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
args=(run --name "$container" --platform linux/amd64
    -e "MAPLIBRE_BUILD_JOBS=${MAPLIBRE_BUILD_JOBS:-8}"
    --mount "type=volume,source=${GRADLE_CACHE_VOLUME:-maplibre-4706-gradle},target=/gradle-cache"
    --mount type=volume,source=maplibre-4706-signing,target=/root/.android)
if [[ -n $aar ]]; then args+=(--mount "type=bind,source=$aar,target=/input/maplibre.aar,readonly"); fi
docker "${args[@]}" "$image" "$version" "$mode"
docker cp "$container:/output/." "$root/build/docker/"
if [[ $mode == pair ]]; then
    test -s "$root/build/docker/maplibre-unpatched.apk"
    test -s "$root/build/docker/maplibre-fixed.apk"
    echo "APKs: $root/build/docker/maplibre-unpatched.apk and maplibre-fixed.apk"
else
    test -s "$root/build/docker/maplibre-repro.apk"
    echo "APK: $root/build/docker/maplibre-repro.apk"
fi
