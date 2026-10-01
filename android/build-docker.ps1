param(
    [string]$Version = '11.11.0',
    [string]$Aar,
    [string]$BaseImage = 'cimg/android:2026.07.1',
    [string]$GradleCacheVolume = 'maplibre-4706-gradle',
    [switch]$UseWsl
)
$ErrorActionPreference = 'Stop'
if ($Aar) {
    $Aar = (Resolve-Path -LiteralPath $Aar).Path
    if (!(Test-Path -LiteralPath $Aar -PathType Leaf)) { throw "AAR not found: $Aar" }
}
if ($UseWsl -or !(Get-Command docker -ErrorAction SilentlyContinue)) {
    # Also support Windows machines whose Docker CLI is installed only in WSL.
    $linuxRoot = & wsl --exec wslpath -a -u $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the project path in WSL.' }
    $wslArgs = @('--exec', 'env', "BASE_IMAGE=$BaseImage", "GRADLE_CACHE_VOLUME=$GradleCacheVolume",
        'bash', "$linuxRoot/build-docker.sh", '--version', $Version)
    if ($Aar) {
        $linuxAar = & wsl --exec wslpath -a -u $Aar
        if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the AAR path in WSL.' }
        $wslArgs += @('--aar', $linuxAar)
    }
    & wsl @wslArgs
    if ($LASTEXITCODE -ne 0) { throw 'WSL Docker build failed.' }
    return
}
$image = 'maplibre-pr-4706-android'
& docker build --platform linux/amd64 --build-arg "BASE_IMAGE=$BaseImage" -t $image $PSScriptRoot
if ($LASTEXITCODE -ne 0) { throw 'Docker image build failed.' }
$output = New-Item -ItemType Directory -Force -Path "$PSScriptRoot/build/docker"
$dockerArgs = @('run', '--rm', '--platform', 'linux/amd64',
    '--mount', "type=volume,source=$GradleCacheVolume,target=/gradle-cache",
    '--mount', 'type=volume,source=maplibre-4706-signing,target=/root/.android',
    '--mount', "type=bind,source=$($output.FullName),target=/output")
if ($Aar) { $dockerArgs += @('--mount', "type=bind,source=$Aar,target=/input/maplibre.aar,readonly") }
& docker @dockerArgs $image $Version
if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
Write-Output "APK: $($output.FullName)/maplibre-repro.apk"
