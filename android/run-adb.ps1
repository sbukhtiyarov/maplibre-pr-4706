param(
    [string]$Serial = 'emulator-5554',
    [string]$Adb = 'adb',
    [string]$Apk = "$PSScriptRoot/build/docker/maplibre-repro.apk",
    [switch]$NoLogcat
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Apk -PathType Leaf)) { throw "APK not found: $Apk. Run build-docker.ps1 first." }
function Invoke-Adb {
    & $Adb -s $Serial @args
    if ($LASTEXITCODE -ne 0) { throw "adb failed with exit code $LASTEXITCODE" }
}
Invoke-Adb get-state
& $Adb -s $Serial install -r $Apk
if ($LASTEXITCODE -ne 0) {
    throw 'Install failed. If signatures differ, uninstall org.example.maplibrerepro explicitly, then retry.'
}
Invoke-Adb shell am force-stop org.example.maplibrerepro
Invoke-Adb shell am start -W -n org.example.maplibrerepro/.MainActivity --ez autoStart true
if (!$NoLogcat) {
    Write-Output 'Streaming logs (Ctrl+C stops logging; the app continues until 120 frames or a crash).'
    Invoke-Adb logcat -v threadtime -T 1 SnapshotRepro:I AndroidRuntime:E libc:F DEBUG:F '*:S'
}
