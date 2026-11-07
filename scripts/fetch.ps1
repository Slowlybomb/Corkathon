param(
    [string]$Region = "bavaria",
    [double]$LatMin = 47.8,
    [double]$LatMax = 48.9,
    [double]$LonMin = 10.5,
    [double]$LonMax = 12.8,
    [string]$Years = "2016,2017",
    [string]$SeasonStart = "03-01",
    [string]$SeasonEnd = "10-31",
    [double]$Step = 0.25,
    [switch]$Kaggle,
    [switch]$NoWeather
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$inv = [Globalization.CultureInfo]::InvariantCulture

if ($Kaggle) {
    $token = [IO.File]::ReadAllText("$env:USERPROFILE\.kaggle\access_token").Trim()
    $kd = Join-Path $root "data\kaggle"
    New-Item -ItemType Directory -Force $kd | Out-Null
    & curl.exe -sS -L --fail -H "Authorization: Bearer $token" -o "$kd\munich480.zip" "https://www.kaggle.com/api/v1/datasets/download/artelabsuper/sentinel2-munich480"
    & tar.exe -xf "$kd\munich480.zip" -C $kd
}

$sd = Join-Path $root "data\$Region\soil"
New-Item -ItemType Directory -Force $sd | Out-Null
$lon = "long({0},{1})" -f $LonMin.ToString($inv), $LonMax.ToString($inv)
$lat = "lat({0},{1})" -f $LatMin.ToString($inv), $LatMax.ToString($inv)
$crs = "http://www.opengis.net/def/crs/EPSG/0/4326"
$depths = "0-5cm", "5-15cm", "15-30cm", "30-60cm", "60-100cm", "100-200cm"
foreach ($p in "phh2o", "soc", "clay", "sand") {
    foreach ($d in $depths) {
        $out = Join-Path $sd "${p}_$d.tif"
        if (-not (Test-Path $out)) {
            $url = "https://maps.isric.org/mapserv?map=/map/$p.map&SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCoverage&COVERAGEID=${p}_${d}_mean&FORMAT=GEOTIFF_INT16&SUBSET=$lon&SUBSET=$lat&SUBSETTINGCRS=$crs&OUTPUTCRS=$crs"
            & curl.exe -sS --fail --retry 3 -o $out $url
        }
    }
}
$wrb = Join-Path $sd "wrb.tif"
if (-not (Test-Path $wrb)) {
    $url = "https://maps.isric.org/mapserv?map=/map/wrb.map&SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCoverage&COVERAGEID=MostProbable&FORMAT=GEOTIFF_INT16&SUBSET=$lon&SUBSET=$lat&SUBSETTINGCRS=$crs&OUTPUTCRS=$crs"
    & curl.exe -sS --fail --retry 3 -o $wrb $url
}

if ($NoWeather) { "$Region ready: $((Get-ChildItem $sd).Count) soil rasters"; return }
$wd = Join-Path $root "data\$Region\weather"
New-Item -ItemType Directory -Force $wd | Out-Null
$lats = @(); $lons = @()
for ($a = $LatMin; $a -le $LatMax + 1e-9; $a += $Step) {
    for ($o = $LonMin; $o -le $LonMax + 1e-9; $o += $Step) {
        $lats += [math]::Round($a, 3).ToString($inv)
        $lons += [math]::Round($o, 3).ToString($inv)
    }
}
$vars = "temperature_2m_mean,relative_humidity_2m_mean,soil_moisture_0_to_7cm_mean,precipitation_sum,et0_fao_evapotranspiration"
$chunk = 15
foreach ($y in $Years.Split(",")) {
    for ($i = 0; $i -lt $lats.Count; $i += $chunk) {
        $out = Join-Path $wd ("om_{0}_{1:D3}.csv" -f $y, ($i / $chunk))
        if (-not (Test-Path $out)) {
            $la = ($lats[$i..([math]::Min($i + $chunk, $lats.Count) - 1)]) -join ","
            $lo = ($lons[$i..([math]::Min($i + $chunk, $lons.Count) - 1)]) -join ","
            $url = "https://archive-api.open-meteo.com/v1/archive?latitude=$la&longitude=$lo&start_date=$y-$SeasonStart&end_date=$y-$SeasonEnd&daily=$vars&timezone=UTC&format=csv"
            & curl.exe -sS --fail --retry 5 --retry-delay 30 -o $out $url
            Start-Sleep -Seconds 40
        }
    }
}
"$Region ready: $((Get-ChildItem $sd).Count) soil rasters, $((Get-ChildItem $wd).Count) weather files, $($lats.Count) weather points"
