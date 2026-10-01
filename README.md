# MapLibre Native #4706 reproduction examples

Companion examples for [maplibre/maplibre-native#4706](https://github.com/maplibre/maplibre-native/pull/4706).

* [Android SDK example](android/): a small application that repeatedly renders a moving camera using `MapSnapshotter`. No original application, Yamaha connection, location permission or API key is needed.
* [Standalone GLES example](gles/): isolates the buffer/VAO lifetime sequence without MapLibre. The affected emulator crashes in `stale` mode and passes in `fixed` mode. Other drivers can pass both modes.

The Android sample uses online OpenFreeMap tiles, glyphs and style. Network/style errors are distinct from the native GLES crash. See [validation results](evidence/README.md) for what was actually tested.

## Android SDK example

### Docker build and adb launch

Requires Docker with Linux containers and Android platform-tools (`adb`) on
the host. Start your emulator separately. Docker supplies the JDK and Android
SDK; no host JDK or Gradle installation is needed. Run from the repository root:

Linux:

```sh
./android/build-docker.sh
./android/run-adb.sh --serial emulator-5554
```

Windows PowerShell (Docker Desktop in Linux containers mode, or Docker in WSL):

```powershell
./android/build-docker.ps1
./android/run-adb.ps1 -Serial emulator-5554
```

If the Windows `docker` command is unavailable, the PowerShell build script
automatically uses Docker in the default WSL distribution. `-UseWsl` selects
that mode explicitly. Android platform-tools still run on the Windows host.

The APK is written to `android/build/docker/maplibre-repro.apk`. The adb helper
installs it, restarts the sample, starts the 120-frame run and streams logs.
Use `--no-logcat` / `-NoLogcat` to return immediately after launch. Ctrl+C stops
log streaming, not the app. Stop the app using its Stop button or
`adb -s emulator-5554 shell am force-stop org.example.maplibrerepro`.
Use `--adb /path/to/adb` / `-Adb 'C:\path\to\adb.exe'` if adb is not on PATH,
and `--apk FILE` / `-Apk FILE` to install a different APK.

Optional SDK version and local patched AAR:

```sh
./android/build-docker.sh --version 11.11.0 --aar /path/to/patched.aar
```

```powershell
./android/build-docker.ps1 -Version 11.11.0 -Aar 'C:\path\to\patched.aar'
```

The first build downloads a large Android image and dependencies; allow several
GB of disk space. Subsequent builds reuse the Docker image and the named
`maplibre-4706-gradle` volume. The `maplibre-4706-signing` volume preserves the
debug signing key so APKs built by these scripts can replace one another.
The source tree is copied into the image using an allowlist; local AARs are
mounted read-only for the build and are not included in the image.
The scripts do not uninstall applications or change device proxy settings.

For an existing compatible Android build image/cache, Linux supports
`BASE_IMAGE` and `GRADLE_CACHE_VOLUME` environment variables; PowerShell supports
`-BaseImage` and `-GradleCacheVolume`. The default base is
`cimg/android:2026.07.1` (linux/amd64).

### Build without Docker

Requires JDK 17 or 21, Android SDK platform 36, and an Android device/emulator (API 23+). Set `ANDROID_HOME` to your SDK, or use Android Studio to open `android/`. Use an x86_64 emulator with host GPU acceleration to match the reported crash; software rendering or another driver may not reproduce it.

```sh
cd android
./gradlew :app:assembleDebug
adb -s emulator-5554 install -r app/build/outputs/apk/debug/app-debug.apk
adb -s emulator-5554 shell am start -n org.example.maplibrerepro/.MainActivity --ez autoStart true
adb -s emulator-5554 logcat -v threadtime SnapshotRepro:I AndroidRuntime:E libc:F DEBUG:F '*:S'
```

On Windows use `gradlew.bat` instead of `./gradlew`. Start can also be pressed in the UI. The app stops when backgrounded or after 120 completed snapshots. Before another automated run, force-stop it so launch extras are read by a new activity:

```sh
adb -s emulator-5554 shell am force-stop org.example.maplibrerepro
```

Each snapshot is 480×240, pixel ratio 1, zoom 15, pitch 40, with a rotating/interpolated camera over a synthetic route in Nicosia. One Snapshotter is reused, one request is in flight, and each bitmap is compressed to JPEG quality 50. Requests are approximately one second apart, subject to render time. The default style is `https://tiles.openfreemap.org/styles/bright`; a different style can be supplied with `--es styleUrl URL` when starting the activity.

The default SDK is **11.11.0**, the version used in the original investigation. To test another published version:

```sh
./gradlew :app:assembleDebug -PmaplibreVersion=VERSION
```

To test an AAR built from the corresponding SDK source with/without the patch:

```sh
./gradlew :app:assembleDebug -PmaplibreVersion=VERSION -PmaplibreAar=/absolute/path/to/maplibre.aar
```

Set `VERSION` to match your AAR's Java API and transitive dependencies. No patched binary is bundled. Compare identical app/style/device settings; an AAR from another SDK release is not an isolated test of this patch.

The SDK 11.11.0 patch used for the recorded control is included in
[`evidence/android-sdk/sdk-11.11.0-fix.patch`](evidence/android-sdk/sdk-11.11.0-fix.patch).
It uses the older `mbgl` source paths; PR #4706 targets current main's `mln` paths.
If APKs were signed with different debug keys, uninstall this sample package
before switching builds (`adb -s emulator-5554 uninstall org.example.maplibrerepro`).

`REQUEST`/`FRAME` messages show progress. On the affected driver, look for `SIGSEGV`, fault address `0x30`, and `GL2Encoder::s_glDrawElements` in `libGLESv2_enc.so`. A timeout or HTTP error is not this crash. Completing 120 snapshots means no crash was observed in that run, not proof that all buffer replacements were exercised. Save crash information with:

```sh
adb -s emulator-5554 logcat -d -b crash > crash.txt
adb -s emulator-5554 shell getprop ro.build.fingerprint
adb -s emulator-5554 shell getconf PAGE_SIZE
adb -s emulator-5554 shell dumpsys SurfaceFlinger
```

## Standalone GLES example

Build an **Android executable**, not a host executable or APK. With an existing Linux Android NDK:

```sh
cd gles
export ANDROID_NDK_HOME=/path/to/android-ndk-r28b
bash build-repro.sh
```

Alternatively, Docker downloads the pinned NDK (this needs several GB of disk space):

```sh
cd gles
docker build --platform linux/amd64 --output type=local,dest=build .
```

For Docker output use `build/vao-repro`; for the existing-NDK build use `vao-repro`:

```sh
adb -s emulator-5554 push build/vao-repro /data/local/tmp/vao-repro
adb -s emulator-5554 shell chmod 755 /data/local/tmp/vao-repro
adb -s emulator-5554 shell /data/local/tmp/vao-repro stale
adb -s emulator-5554 shell /data/local/tmp/vao-repro fixed
```

The Windows helper records output and exit codes:

```powershell
./run-repro.ps1 -Serial emulator-5554 -Binary ./build/vao-repro -OutputDirectory ../results/gles
```

For arm64, add `--build-arg ANDROID_ABI=arm64-v8a` to Docker, or `ANDROID_ABI=arm64-v8a` when running `build-repro.sh`. The PowerShell helper requires `-AllowPhysicalDevice` for a physical device.

The sample creates a VAO with an element buffer, unbinds that VAO, creates a replacement element buffer, deletes the old buffer name, then draws with the original VAO. `fixed` explicitly binds the replacement before drawing. Both buffers contain the same indices; a successful draw must produce a green pixel `(0,255,0,255)`.

GL objects can remain alive through VAO references after their names are deleted. Therefore `glIsBuffer(oldName) == false` is not by itself evidence of a GL specification violation, and passing `stale` is valid on unaffected implementations. This example isolates the observed emulator driver crash; the PR's [C++ regression test](https://github.com/maplibre/maplibre-native/pull/4706/files) separately changes index contents and verifies stale geometry through pixel readback.

## Scope and provenance

The original crash occurred during offscreen snapshot rendering in an application prototype, including with Yamaha transmission disabled. The original full application is not required by these examples. These examples and documentation were prepared with AI assistance. The public OpenFreeMap service is used at runtime; map data attribution is displayed by the sample. No tiles, fonts, SDK binaries or original application code are bundled.
