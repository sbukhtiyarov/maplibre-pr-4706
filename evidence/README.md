# Recorded results

## Standalone GLES

The files in `gles-emulator/` and `gles-samsung/` are recorded results from the standalone executable, not from the Android SDK sample.

| Environment | stale | fixed |
| --- | --- | --- |
| Android 17 API 37, x86_64 16 KiB emulator; Android Emulator OpenGL ES Translator, Intel Graphics, host driver 32.0.101.8826 | SIGSEGV, exit 139 | Green pixel, exit 0 |
| Samsung SM-S921B, Android 16, arm64; ANGLE / Xclipse 940 / Vulkan 1.3.279 | Green pixel, exit 0 | Green pixel, exit 0 |

`exit-codes.json` records device build fingerprints and the hashes of the tested binaries. The compiler output is not committed. `gles-emulator/crash-excerpt.txt` records the relevant emulator stack frame from the original investigation.

## Android SDK

Tested on 2026-10-01 using this repository's Android application, public
OpenFreeMap Bright style, and the same Android 17 x86_64 / Intel emulator
configuration listed above. Both Gradle builds succeeded (JDK 21, Gradle 8.13,
AGP 8.13.2, compile SDK 36).

| SDK | Result |
| --- | --- |
| Published `org.maplibre.gl:android-sdk:11.11.0` | Three frames completed; request 4 crashed on the Snapshotter thread: SIGSEGV at `0x30`, `GL2Encoder::s_glDrawElements` in `libGLESv2_enc.so` |
| Locally rebuilt 11.11.0 AAR with the index-buffer binding fix | All 120 snapshots completed; no crash observed |

See [unpatched progress](android-sdk/unpatched-log.txt),
[crash report](android-sdk/unpatched-crash.txt),
[patched progress](android-sdk/patched-log.txt), and
[artifact hashes and environment](android-sdk/results.json).
The [exact patch embedded in the control AAR](android-sdk/sdk-11.11.0-fix.patch)
is included for provenance. The control uses SDK 11.11.0, not a binary from
current upstream main. This is an observed before/after result, not a claim
that the full SDK test suite or all drivers have been validated.

The application has no connection to the original application's server or
Yamaha. An initial attempt encountered an unavailable proxy configured on
the emulator; the recorded runs used direct network access. That failed
network attempt is excluded from the crash comparison. The original proxy
settings were restored after testing. Public style/tile content can change.
