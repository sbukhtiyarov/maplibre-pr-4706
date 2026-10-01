param(
    [string]$Serial = 'emulator-5554',
    [string]$Adb = 'adb',
    [string]$Apk,
    [ValidateSet('default', 'unpatched', 'fixed')]
    [string]$Variant = 'unpatched',
    [switch]$NoLogcat
)
$ErrorActionPreference = 'Stop'
$package = 'org.example.maplibrerepro'
if ($Variant -ne 'default') { $package += ".$Variant" }
if (!$Apk) {
    $name = if ($Variant -eq 'default') { 'repro' } else { $Variant }
    $Apk = "$PSScriptRoot/build/docker/maplibre-$name.apk"
}
if (!(Test-Path -LiteralPath $Apk -PathType Leaf)) { throw "APK not found: $Apk. Run build-docker.ps1 first." }
function Invoke-Adb {
    & $Adb -s $Serial @args
    if ($LASTEXITCODE -ne 0) { throw "adb failed with exit code $LASTEXITCODE" }
}
Invoke-Adb get-state
& $Adb -s $Serial install -r $Apk
if ($LASTEXITCODE -ne 0) {
    throw "Install failed. If signatures differ, uninstall $package explicitly, then retry."
}
Invoke-Adb shell am force-stop $package
Invoke-Adb shell am start -W -n "$package/org.example.maplibrerepro.MainActivity" --ez autoStart true
if (!$NoLogcat) {
    Write-Output 'Streaming logs (Ctrl+C stops logging; the app continues until 120 frames or a crash).'
    Invoke-Adb logcat -v threadtime -T 1 SnapshotRepro:I AndroidRuntime:E libc:F DEBUG:F '*:S'
}
