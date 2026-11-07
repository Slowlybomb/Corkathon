param(
    [string]$Region = "cork",
    [string]$Item = "S2A_29UNT_20230530_0_L2A",
    [double]$Lat = 0,
    [double]$Lon = 0,
    [string]$Start = "2023-04-01",
    [string]$End = "2023-10-31",
    [double]$MaxCloud = 5
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$api = "https://earth-search.aws.element84.com/v1"

if ($Lat -ne 0 -or $Lon -ne 0) {
    $body = @{ collections = @("sentinel-2-l2a"); intersects = @{ type = "Point"; coordinates = @($Lon, $Lat) };
               datetime = "${Start}T00:00:00Z/${End}T23:59:59Z"; limit = 100;
               query = @{ "eo:cloud_cover" = @{ lt = $MaxCloud }; "s2:nodata_pixel_percentage" = @{ lt = 10 } } } | ConvertTo-Json -Depth 6
    $r = Invoke-RestMethod -Method Post -Uri "$api/search" -Body $body -ContentType "application/json"
    if ($r.features.Count -eq 0) { throw "no clear scene found" }
    $it = ($r.features | Sort-Object { $_.properties.'eo:cloud_cover' })[0]
} else {
    $it = Invoke-RestMethod -Uri "$api/collections/sentinel-2-l2a/items/$Item"
}
$id = $it.id
$dir = Join-Path $root "data\$Region\s2\$id"
New-Item -ItemType Directory -Force $dir | Out-Null
$assets = [ordered]@{ blue = "B02"; green = "B03"; red = "B04"; nir = "B08"; rededge1 = "B05"; rededge2 = "B06"; rededge3 = "B07"; nir08 = "B8A"; swir16 = "B11"; swir22 = "B12"; scl = "SCL" }
foreach ($k in $assets.Keys) {
    $out = Join-Path $dir "$($assets[$k]).tif"
    if (-not (Test-Path $out)) {
        & curl.exe -sS --fail --retry 3 -o $out $it.assets.$k.href
    }
}
$date = $it.properties.datetime.Substring(0, 10).Replace("-", "")
$offset = 0
if (-not $it.properties.'earthsearch:boa_offset_applied' -and [double]$it.properties.'s2:processing_baseline' -ge 4.0) { $offset = 1000 }
"$date $($it.properties.'proj:epsg') $offset" | Out-File -Encoding ascii -NoNewline (Join-Path $dir "meta.txt")
"$id ready in $dir (date $date, EPSG $($it.properties.'proj:epsg'), offset $offset, cloud $($it.properties.'eo:cloud_cover')%)"
