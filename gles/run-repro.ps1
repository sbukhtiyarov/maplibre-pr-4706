param(
    [string]$Adb = 'adb',
    [string]$Serial = 'emulator-5554',
    [string]$Binary = "$PSScriptRoot/vao-repro",
    [string]$OutputDirectory = $PSScriptRoot,
    [switch]$AllowPhysicalDevice
)
$ErrorActionPreference = 'Stop'
$qemu = (& $Adb -s $Serial shell getprop ro.kernel.qemu) -join ''
if ($LASTEXITCODE -ne 0) { throw 'Device unavailable' }
$isEmulator = $qemu.Trim() -eq '1'
if (!$isEmulator -and !$AllowPhysicalDevice) {
    throw 'Physical devices require explicit -AllowPhysicalDevice.'
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$model = (& $Adb -s $Serial shell getprop ro.product.model) -join ''
$abi = (& $Adb -s $Serial shell getprop ro.product.cpu.abi) -join ''
$fingerprint = (& $Adb -s $Serial shell getprop ro.build.fingerprint) -join ''
& $Adb -s $Serial push $Binary /data/local/tmp/vao-repro
if ($LASTEXITCODE -ne 0) { throw 'adb push failed' }
& $Adb -s $Serial shell chmod 755 /data/local/tmp/vao-repro
if ($LASTEXITCODE -ne 0) { throw 'chmod failed' }
& $Adb -s $Serial shell /data/local/tmp/vao-repro stale 2>&1 | Tee-Object "$OutputDirectory/stale.txt"
$staleExit = $LASTEXITCODE
& $Adb -s $Serial shell /data/local/tmp/vao-repro fixed 2>&1 | Tee-Object "$OutputDirectory/fixed.txt"
$fixedExit = $LASTEXITCODE
[pscustomobject]@{
    staleExit=$staleExit; fixedExit=$fixedExit; model=$model.Trim(); abi=$abi.Trim()
    fingerprint=$fingerprint.Trim(); emulator=$isEmulator
    binarySha256=(Get-FileHash -LiteralPath $Binary -Algorithm SHA256).Hash
} | ConvertTo-Json | Set-Content "$OutputDirectory/exit-codes.json"
if ($fixedExit -ne 0) { throw 'The fixed variant failed.' }
if ($staleExit -eq 139) {
    Write-Output 'Confirmed: stale=SIGSEGV, fixed=PASS with pixel verification.'
} elseif ($staleExit -eq 0) {
    Write-Output 'Both variants PASS. This device did not reproduce the driver crash.'
} else {
    throw "Unexpected stale exit code $staleExit; inspect the logs."
}
