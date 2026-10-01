param(
    [string]$Version = '11.11.0',
    [string]$Aar,
    [string]$BaseImage = 'cimg/android:2026.07.1',
    [string]$GradleCacheVolume = 'maplibre-4706-gradle',
    [switch]$UseWsl,
    [switch]$Pair,
    [switch]$Single
)
$ErrorActionPreference = 'Stop'
$nativeJobs = if ($env:MAPLIBRE_BUILD_JOBS) { $env:MAPLIBRE_BUILD_JOBS } else { '8' }
if ($nativeJobs -notmatch '^[1-9][0-9]*$') { throw 'MAPLIBRE_BUILD_JOBS must be a positive integer.' }
if ($Pair -and $Single) { throw 'Choose either -Pair or -Single.' }
if (!$Single -and !$Aar -and $Version -ne '11.11.0') { throw 'The bundled patch requires SDK 11.11.0; provide -Aar for other versions.' }
if ($Aar) {
    $Aar = (Resolve-Path -LiteralPath $Aar).Path
    if (!(Test-Path -LiteralPath $Aar -PathType Leaf)) { throw "AAR not found: $Aar" }
}
if ($UseWsl -or !(Get-Command docker -ErrorAction SilentlyContinue)) {
    # Also support Windows machines whose Docker CLI is installed only in WSL.
    $linuxRoot = & wsl --exec wslpath -a -u $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the project path in WSL.' }
    $wslArgs = @('--exec', 'env', "BASE_IMAGE=$BaseImage", "GRADLE_CACHE_VOLUME=$GradleCacheVolume", "MAPLIBRE_BUILD_JOBS=$nativeJobs",
        'bash', "$linuxRoot/build-docker.sh", '--version', $Version)
    if ($Single) { $wslArgs += '--single' }
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
$container = 'maplibre-4706-build-' + [guid]::NewGuid().ToString('N')
$dockerArgs = @('run', '--name', $container, '--platform', 'linux/amd64',
    '-e', "MAPLIBRE_BUILD_JOBS=$nativeJobs",
    '--mount', "type=volume,source=$GradleCacheVolume,target=/gradle-cache",
    '--mount', 'type=volume,source=maplibre-4706-signing,target=/root/.android')
if ($Aar) { $dockerArgs += @('--mount', "type=bind,source=$Aar,target=/input/maplibre.aar,readonly") }
$mode = if ($Single) { 'single' } else { 'pair' }
try {
    & docker @dockerArgs $image $Version $mode
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed.' }
    & docker cp "${container}:/output/." $output.FullName
    if ($LASTEXITCODE -ne 0) { throw 'APK export failed.' }
} finally {
    & docker rm -f $container | Out-Null
}
$names = if ($Single) { @('maplibre-repro.apk') } else { @('maplibre-unpatched.apk', 'maplibre-fixed.apk') }
foreach ($name in $names) {
    if (!(Test-Path -LiteralPath "$($output.FullName)/$name" -PathType Leaf)) { throw "Missing output: $name" }
}
if (!$Single) {
    Write-Output "APKs: $($output.FullName)/maplibre-unpatched.apk and maplibre-fixed.apk"
} else {
    Write-Output "APK: $($output.FullName)/maplibre-repro.apk"
}
