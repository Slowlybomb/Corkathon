# Satellite soil and field model

A OneSoil-style model written entirely in Century. From a single Sentinel-2 image it maps field boundaries, crop type, soil pH, organic carbon, clay and sand at six depths (0-200 cm), WRB soil group and texture class, temperature, humidity, soil moisture and the 30-day water balance, each with a confidence map. Training uses no backpropagation: every weight comes from an exact, certified solve.

## Running it

From the repo root:

```
.\scripts\fetch.ps1 -Kaggle                                       # Munich480 (Kaggle), SoilGrids rasters, ERA5-Land weather
.\cy src\agri\train.cy   --jit main --arg 100000 --arg 4 --arg 1    # stage 1: patches cap, clear dates per patch, years (1 = 2016, 2 = 2016+2017)
.\cy src\agri\stage2.cy  --jit main --arg 100000 --arg 4 --arg 1    # stage 2, appended to out/model.bin
.\cy src\agri\predict.cy --jit main --arg 1 --arg 100000            # held-out evaluation  -> out/eval_report.txt, out/boundary_threshold.txt
.\cy src\agri\predict.cy --jit main --arg 0 --arg 100000            # Bavaria maps and exports -> out/maps/
```

Training writes `out/model.bin`, `out/train_report.txt` and `out/train_log.txt`. When `out/model.bin` is missing, the programs load `models/agri.bin`, the trained final model. The evaluation also picks the field-boundary threshold with the best held-out F1, and the renders and zones use it.

**Any Sentinel-2 scene, such as Ireland:**

```
.\scripts\fetch_s2.ps1 -Region cork -Item S2A_29UNT_20230530_0_L2A    # or -Lat 51.95 -Lon -8.22 -Start 2023-04-01 -End 2023-10-31
.\scripts\fetch_dem.ps1 -Region cork -LatMin 51.915 -LatMax 51.985 -LonMin -8.275 -LonMax -8.165       # elevation (AWS Terrain Tiles)
.\scripts\fetch.ps1 -Region cork -LatMin 51.85 -LatMax 52.05 -LonMin -8.35 -LonMax -8.10 -Years 2023 -Step 0.1   # SoilGrids + ERA5-Land weather
.\cy src\agri\scene.cy --jit main --arg 550720 --arg 5758640 --arg 12  # top-left E, N (UTM metres), patches per side -> out/cork/
```

The Cork window is centred on 51.9500 N, 8.2201 W (UTM 29N E 553600, N 5755760), 5.76 x 5.76 km at 10 m, in East Cork tillage land between Carrigtwohill, Midleton and Lisgoold. In Ireland, the weather layers are the observed ERA5-Land values for the scene date: the weather heads learnt Bavarian seasons and cannot be recalibrated from one date.

**Recalibrating the soil heads for a new region:**

```
.\scripts\fetch.ps1 -Region corkcal -LatMin 51.82 -LatMax 52.08 -LonMin -8.43 -LonMax -8.01 -NoWeather   # SoilGrids labels for the area
.\cy src\agri\calibrate.cy --jit main --arg 542080 --arg 5767280 --arg 48                                 # 23 km area, top-left E, N, patches per side
```

`calibrate.cy` re-fits the 24 soil heads for the new region in closed form, stacked on the Bavarian model. It uses SoilGrids footprints over the area, with lambda chosen on a held-out checkerboard of 3.84 km blocks. It writes `out/cork_soil_heads.bin`, which `scene.cy` then uses automatically. Around Cork this takes about 13 seconds. It moves held-out pH from R2 -13.7 to 0.19, and organic carbon from -8.8 to 0.19 (`out/cork/recalibration.txt`).

`fetch_s2.ps1` searches Earth Search, a free catalogue of Sentinel-2 L2A data on AWS, for the least cloudy scene. It downloads the ten bands and the scene classification layer, which masks cloud and shadow. `scene.cy` reads only the window it needs, cuts it into 48 x 48 patches and runs the trained model in the scene's own UTM zone.

## Data

| Source | What it gives | Resolution |
|---|---|---|
| Munich480 (Kaggle, `artelabsuper/sentinel2-munich480`) | Sentinel-2 bands B2-B8A, B11, B12; crop labels per pixel (18 classes) | 10 m, 48 x 48 patches |
| ISRIC SoilGrids 2.0 (WCS) | pH, organic carbon, clay, sand at 6 depths; WRB most probable group | 250 m |
| ERA5-Land via Open-Meteo | daily mean temperature, humidity, soil moisture 0-7 cm, rain, reference evapotranspiration | about 9 km |

Field boundaries are where the crop label changes. Images from April to October are kept when the cloud test passes.

## The model

1. **Base channels (21 per pixel).** The 10 bands (z-scored), NDVI, NDMI, NDWI, NDRE and BSI, the day of year as sine and cosine, and the **spectral unmixing** fractions. Each pixel is solved as a non-negative mix, summing to one, of four endmember spectra (bare soil, green vegetation, dry vegetation, water). The endmembers start from library spectra and are refined by alternating least squares, regularised toward the library.
2. **Random convolutional features (192).** Four layers of fixed random 3x3 filters with ReLU at dilations 1, 2, 4 and 8, so the receptive field covers about 350 m. They run as `gpu do` kernels and are never trained.
3. **Law neurons (58).** For every target, every law of up to three terms is fitted on training patches and scored on held-out patches. The candidate terms are the base channels, their 7x7 local means, and bare-soil fraction times each band and index (30,913 candidates). All candidates are scored from one moment matrix, by exact small solves. A second layer repeats the search on the best law's residual. Each target contributes its best law and its combined law as neurons.
4. **Ridge heads, stacked on the laws.** Every head is an exact ridge solve over [1, base, conv, context, neurons]. Each regression head fits the residual of its own law, with lambda picked from 1e-6 to 1e3 times the mean diagonal on held-out moments. A head can therefore never do worse than its law on held-out data. Every solve is certified by the relative residual of its normal equations.
5. **Sharp maps from coarse labels.** Soil labels are 250 m and weather about 9 km, but the output is 10 m. Each coarse-label head is trained on footprint-averaged features: averaging is linear, so A(F b) = (A F) b. Soil footprints are weighted by each pixel's bare-soil fraction, so pixels where soil is visible carry the label. The same weights b then predict every 10 m pixel.
6. **Uncertainty.** Each prediction carries the Bayesian predictive variance s^2 (1 + f^T S^-1 f), where S is the regularised Gram matrix and s^2 the held-out residual variance.
7. **Edge features (8).** Sobel gradient magnitudes of NDVI, NDMI, NIR and SWIR, with their 3x3 local maxima. They give the field-boundary head both signs of an edge, which ReLU features cannot.
8. **Stage 2.** Stage 1's maps (boundary score, 0-5 cm soil, weather) are read back as inputs: two random conv layers over them, plus their patch means, give 66 more features. Stage 2's ridge is stacked on stage 1, fitting stage 1's residual with lambda chosen on held-out patches, so it cannot make held-out results worse. Stage-1 maps currently come from the full stage-1 model. Cross-fitting them by fold is the next refinement.

## Results

Held-out patches are spatially separate from the training patches (Munich480's own split). Soil is scored per 250 m SoilGrids cell and weather per patch. Every ridge solve certified to a relative residual of 1e-12 or better. The full figures are written to `out/train_report.txt` and `out/eval_report.txt`.

Final model: 2016 season, 5,009 training and 1,539 held-out patches, stages 1 and 2.

| Output | Held-out result |
|---|---|
| pH, 0-5 cm | R2 0.40 for 10 m predictions averaged per cell (0.445 at stage 2's footprint level); 94% of truths inside the 95% interval |
| Organic carbon, 0-5 cm | R2 0.22; 96% inside the 95% interval |
| Sand, 0-5 cm | R2 0.38; 96% inside the 95% interval |
| Clay, 0-5 cm | R2 0.01 (no signal); 95% inside the 95% interval |
| Air temperature | R2 0.87 |
| Relative humidity | R2 0.76 |
| 30-day water balance | R2 0.59 |
| Soil moisture, 0-7 cm | R2 0.17 |
| Field boundaries | F1 0.45 (precision 0.36, recall 0.61, threshold 0.25) |
| Crop type, 18 classes, one date | pixel accuracy 0.58 |

Stage 2 raised pH from 0.39 to 0.45, temperature from 0.83 to 0.87 and humidity from 0.73 to 0.76. Where it would not help, the stacking guard keeps stage 1. On a laptop (RTX 4060, i7-13620H), stage 1 trains in about 10 minutes and stage 2 in about 5.

**Ireland.** The Bavarian soil heads do not carry over to Irish soils, which are acidic and rich in organic carbon. On held-out Irish blocks around Cork their R2 is -11.4 for pH and -9.7 for organic carbon. Recalibrated in 14 seconds, they reach 0.18 and 0.20. A Cork window (5.76 km at 10 m) runs end to end in about 7 seconds.

## Outputs (`out/maps/`)

The PNGs are renders for checking. The GeoTIFFs are float32 in UTM zone 32N (EPSG:32632), with no-data -9999.

| File | Bands |
|---|---|
| `region_soil_40m.tif`, `detail_soil_10m.tif` | 24: pH, organic carbon (g/kg), clay (%), sand (%), each at 0-5, 5-15, 15-30, 30-60, 60-100 and 100-200 cm |
| `region_weather_40m.tif`, `detail_weather_10m.tif` | 4: temperature (C), relative humidity (%), soil moisture (m3/m3), 30-day water balance (mm) |
| `region_surface_40m.tif`, `detail_surface_10m.tif` | 5: NDVI, NDMI, boundary score, crop class, WRB code |

`detail_zones_ndvi.png` and `detail_zones_soc.png` split each detected field into low, medium and high zones.

The Bavarian 10 m detail window is also written as `<name>.f32` with a `<name>.json` sidecar, with the bands interleaved per pixel.

## Scene package for renderers (`out/cork/`)

`scene.cy` writes everything a renderer needs, for Three.js or any other engine:

| Path | What it is |
|---|---|
| `manifest.json` | CRS, width and height, pixel size, UTM origin, latitude and longitude of the four corners, the layer list (file, type, units, group, min, max, mean, depth), legends, the soil volume and notes on where each layer comes from |
| `layers/<name>.f32` | One float32 value per pixel, row-major from the north-west corner, little-endian, no-data -9999 |
| `layers/<name>.u8` | Categorical layers, one byte per pixel, no-data 255: `field_zones` (0 not a field, 1 low, 2 medium, 3 high), `texture_class`, `crop_class`, `wrb_code` |
| `layers/elevation.f32` | Terrain height in metres on the same 576 x 576 grid, for the terrain mesh |
| `layers/true_color.rgb8` | Display RGB, 3 bytes per pixel |
| `textures/*.png` | Coloured renders, ready to drape on the mesh |
| `geotiff/*.tif` | The same data as float32 GeoTIFFs, for GIS tools |

The layers are 24 soil layers (pH, organic carbon, clay and sand at 0-5, 5-15, 15-30, 30-60, 60-100 and 100-200 cm, together a 3D soil volume), 4 weather layers, NDVI, NDMI, the boundary score, the 4 unmixing fractions and elevation.

```js
const m = await (await fetch("out/cork/manifest.json")).json();
const layer = async (name) => {
  const L = m.layers.find(l => l.name === name);
  const buf = await (await fetch("out/cork/" + L.file)).arrayBuffer();
  return L.type === "uint8" ? new Uint8Array(buf) : new Float32Array(buf);
};
const height = await layer("elevation");     // m.width * m.height values, row 0 = north edge
const ph = await layer("ph_0-5cm");          // colour with m.layers[...].min / max
const zones = await layer("field_zones");
// PlaneGeometry(m.width * m.pixel_size_m, m.height * m.pixel_size_m, m.width - 1, m.height - 1):
// set vertex i's z to height[i], and use ph or zones as a DataTexture or vertex colours.
```

## Limits

- Soil labels are SoilGrids predictions, not field samples, so a soil map here can only be as good as SoilGrids. Clay shows no signal in this region.
- Weather labels are about 9 km cells. Temperature and humidity are learnt from season and surface state, not observed directly.
- Day of year is an input. Because cloud cover is regional, the dates on which a patch is clear partly encode its location; some of the skill for sand comes from that.
- The convolutions zero-pad each 48 x 48 patch, so boundary scores near patch edges are unreliable. The renders mask a 2-pixel ring.
- Munich480 is Sentinel-2 L1C (top of atmosphere, 2016), while Earth Search serves L2A (surface reflectance, darker in blue). On other scenes, patterns such as boundaries, zones and relative differences carry over better than absolute soil values. Bavarian cropland also differs from Irish grassland. Training on Irish labels would fix both.
