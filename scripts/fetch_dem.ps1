param(
    [string]$Region = "cork",
    [double]$LatMin = 51.92,
    [double]$LatMax = 51.98,
    [double]$LonMin = -8.27,
    [double]$LonMax = -8.17,
    [int]$Zoom = 13
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "data\$Region\dem"
New-Item -ItemType Directory -Force $dir | Out-Null
$n = [math]::Pow(2, $Zoom)
function TileX([double]$lon) { [int][math]::Floor(($lon + 180.0) / 360.0 * $n) }
function TileY([double]$lat) { $r = $lat * [math]::PI / 180.0; [int][math]::Floor((1.0 - [math]::Log([math]::Tan($r) + 1.0 / [math]::Cos($r)) / [math]::PI) / 2.0 * $n) }
$x0 = TileX $LonMin; $x1 = TileX $LonMax
$y0 = TileY $LatMax; $y1 = TileY $LatMin
for ($x = $x0; $x -le $x1; $x++) {
    for ($y = $y0; $y -le $y1; $y++) {
        $out = Join-Path $dir ("t_{0}_{1}.png" -f ($x - $x0), ($y - $y0))
        if (-not (Test-Path $out)) {
            & curl.exe -sS --fail --retry 3 -o $out "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/$Zoom/$x/$y.png"
        }
    }
}
"$Zoom $x0 $y0 $($x1 - $x0 + 1) $($y1 - $y0 + 1)" | Out-File -Encoding ascii -NoNewline (Join-Path $dir "tiles.txt")
"$Region DEM: zoom $Zoom, tiles x $x0..$x1, y $y0..$y1 in $dir"
