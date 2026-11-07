param(
    [int]$Patches = 100000,
    [int]$Dates = 4,
    [int]$Years = 2,
    [switch]$SkipTrain,
    [switch]$SkipScene
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$cy = Join-Path $root "century\bin\century.exe"
New-Item -ItemType Directory -Force out, out\maps, out\cork | Out-Null
$t = Get-Date
if (-not $SkipTrain) {
    & $cy src\agri\train.cy --jit main --arg $Patches --arg $Dates --arg $Years | Tee-Object out\train_log.txt | Select-String -NotMatch "^pass 2: patch"
    & $cy src\agri\stage2.cy --jit main --arg $Patches --arg $Dates --arg $Years | Select-String -NotMatch "^stage 2 pass"
}
& $cy src\agri\predict.cy --jit main --arg 1 --arg $Patches | Select-String -NotMatch "^predict:"
& $cy src\agri\predict.cy --jit main --arg 0 --arg $Patches | Select-String -NotMatch "^predict:"
if (-not $SkipScene) {
    & $cy src\agri\calibrate.cy --jit main --arg 542080 --arg 5767280 --arg 48
    & $cy src\agri\scene.cy --jit main --arg 550720 --arg 5758640 --arg 12
    & $cy src\agri\fastrun.cy --jit main --arg 550720 --arg 5758640 --arg 2 --arg 288 --arg 0
    & $cy src\agri\fastrun.cy --jit main --arg 550720 --arg 5758640 --arg 1 --arg 32 --arg 1
}
"pipeline finished in {0:N1} minutes" -f ((Get-Date) - $t).TotalMinutes
