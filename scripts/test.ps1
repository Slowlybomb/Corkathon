param([switch]$SkipModel)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$failed = 0

"== Dashboard unit tests (Node)"
node --test "dashboard/*.test.mjs"
if ($LASTEXITCODE -ne 0) { $failed++ }

"== Android unit checks (JVM)"
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "C:\Program Files (x86)\Android\android-sdk" }
$jar = Get-ChildItem "$sdk\platforms\android-*\android.jar" |
    Sort-Object { [int]($_.Directory.Name -replace 'android-', '') } | Select-Object -Last 1
if (-not $jar) { throw "No Android platform found under $sdk. Set ANDROID_HOME." }
$classes = Join-Path ([IO.Path]::GetTempPath()) "corkathon-java-checks"
if (Test-Path $classes) { Remove-Item -Recurse -Force $classes }
$sources = (Get-ChildItem android\app\src\main\java, android\app\src\test\java -Recurse -Filter *.java).FullName
javac -encoding UTF-8 -nowarn --release 17 -cp $jar.FullName -d $classes @sources
if ($LASTEXITCODE -ne 0) { $failed++ }
foreach ($check in Get-ChildItem android\app\src\test\java -Recurse -Filter *Check.java) {
    java -cp "$classes;$($jar.FullName)" "ie.corkathon.phone.$($check.BaseName)"
    if ($LASTEXITCODE -ne 0) { $failed++ }
}

if (-not $SkipModel) {
    "== Model consistency: phone code path against the laptop GPU engine (Century)"
    & century\bin\century.exe src\agri\fastrun.cy --jit main --arg 550720 --arg 5758640 --arg 1 --arg 32 --arg 1 | Out-Null
    $line = & century\bin\century.exe tests\agri\phone_core_test.cy --no-gpu --jit main --arg 80 --arg 0 --arg 150 |
        Select-String "phone core"
    "$line"
    if ("$line" -notmatch "boundary max diff 0, soil 0, weather 0, class mismatches 0") { $failed++ }
}

if ($failed) { "$failed test group(s) failed"; exit 1 }
"All tests passed"
