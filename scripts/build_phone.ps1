param(
    [string]$Century = $env:CENTURY_ARM64,
    [string]$Ndk = $env:ANDROID_NDK_HOME,
    [string]$Heap = "1G",
    [switch]$Fixtures
)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $Century -or -not (Test-Path $Century)) {
    throw "Pass -Century (or set CENTURY_ARM64) to a Century compiler built with the arm64 back end. See android/README.md."
}
if (-not $Ndk) { $Ndk = "C:\Program Files (x86)\Android\AndroidNDK\android-ndk-r23c" }
$clang = Join-Path $Ndk "toolchains\llvm\prebuilt\windows-x86_64\bin\clang.exe"
if (-not (Test-Path $clang)) { throw "Android NDK clang not found under $Ndk. Pass -Ndk or set ANDROID_NDK_HOME." }

$env:PATH = "$root\century\bin;$env:PATH"
$assets = "android\app\src\main\assets\agri"
$jni = "android\app\src\main\jniLibs\arm64-v8a"
New-Item -ItemType Directory -Force $assets, $jni | Out-Null

$report = & $Century src\agri\phone.cy --target arm64 --flat "$assets\agri_arm64.bin" --entry agri_run --heap $Heap | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) { throw "ARM64 model build failed: $report" }
"bss $(($report -split ' ')[-1])" | Set-Content -Encoding ascii "$assets\agri_arm64.txt"
"ARM64 model image: $report"

& $clang --target=aarch64-linux-android26 -shared -fPIC -O2 -Wall "-Wl,-soname,libagri.so" "-Wl,-z,max-page-size=16384" `
    -o "$jni\libagri.so" android\app\src\main\cpp\agri_loader.c
if ($LASTEXITCODE -ne 0) { throw "JNI loader build failed" }
Copy-Item models\agri.bin "$assets\agri.bin" -Force
Copy-Item models\cork_soil_heads.bin "$assets\cork_soil_heads.bin" -Force
"JNI loader and model weights copied"

if ($Fixtures) {
    $cy = "century\bin\century.exe"
    & $cy src\agri\fastrun.cy --jit main --arg 550720 --arg 5758640 --arg 4 --arg 144 --arg 2 | Out-Null
    Copy-Item out\phone\cork_cube.u16, out\phone\cork_cube.json $assets -Force
    & $cy src\agri\fastrun.cy --jit main --arg 552960 --arg 5756400 --arg 1 --arg 128 --arg 1 | Out-Null
    & $cy tests\agri\phone_core_test.cy --jit main --arg 176 --arg 1 --arg 150 | Out-Null
    Copy-Item out\golden\input_refl.f32 "$assets\cork128_in.f32" -Force
    Copy-Item out\golden\phone_out.f32 "$assets\cork128_expected.f32" -Force
    & $cy src\agri\fastrun.cy --jit main --arg 550720 --arg 5758640 --arg 1 --arg 32 --arg 1 | Out-Null
    Copy-Item out\golden\input_refl.f32 "$assets\golden32_in.f32" -Force
    Copy-Item out\golden\expected_out.f32 "$assets\golden32_expected.f32" -Force
    New-Item -ItemType Directory -Force "$assets\weather" | Out-Null
    foreach ($layer in "temperature_c", "humidity_pct", "soil_moisture_m3m3", "water_balance_30d_mm") {
        Copy-Item "out\cork\layers\$layer.f32" "$assets\weather\" -Force
    }
    "Test fixtures regenerated"
}
"Done. Build the app with: cd android; .\gradlew assembleDebug"
