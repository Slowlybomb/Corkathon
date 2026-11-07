# Satellite soil and field model

A OneSoil-style model written entirely in Century. From a single Sentinel-2 image it maps field boundaries, crop type, soil pH, organic carbon, clay and sand at six depths (0-200 cm), WRB soil group and texture class, temperature, humidity, soil moisture and the 30-day water balance, each with a confidence map. Training uses no backpropagation: every weight comes from an exact, certified solve.

## Running it

From the repo root:

```
.\scripts\fetch.ps1 -Kaggle                                       # Munich480 (Kaggle), SoilGrids rasters, ERA5-Land weather
.\cy src\agri\train.cy   --jit main --arg 100000 --arg 4 --arg 2    # stage 1: patches cap, clear dates per patch, seasons (1 = 2016, 2 = 2016+2017)
.\cy src\agri\stage2.cy  --jit main --arg 100000 --arg 4 --arg 2    # stage 2, appended to out/model.bin
.\cy src\agri\predict.cy --jit main --arg 1 --arg 100000            # held-out evaluation  -> out/eval_report.txt, out/boundary_threshold.txt
.\cy src\agri\predict.cy --jit main --arg 0 --arg 100000            # Bavaria maps and exports -> out/maps/
```

Training writes `out/model.bin`, `out/train_report.txt` and `out/train_log.txt`. When `out/model.bin` is missing, the programs load `models/agri.bin`, the trained final model. The evaluation also picks the field-boundary threshold with the best held-out F1, and the renders and zones use it. `.\scripts\run_all.ps1` runs everything in order: training (skip it with `-SkipTrain`), evaluation, maps, the Irish recalibration, the Cork scene, the fast engine and the test vectors.

**Any Sentinel-2 scene, such as Ireland:**

```
.\scripts\fetch_s2.ps1 -Region cork -Item S2A_29UNT_20230530_0_L2A    # or -Lat 51.95 -Lon -8.22 -Start 2023-04-01 -End 2023-10-31
.\scripts\fetch_dem.ps1 -Region cork -LatMin 51.915 -LatMax 51.985 -LonMin -8.275 -LonMax -8.165       # elevation (AWS Terrain Tiles)
.\scripts\fetch.ps1 -Region cork -LatMin 51.85 -LatMax 52.05 -LonMin -8.35 -LonMax -8.10 -Years 2023 -Step 0.1   # SoilGrids + ERA5-Land weather
.\cy src\agri\scene.cy --jit main --arg 550720 --arg 5758640 --arg 12  # top-left E, N (UTM metres), patches per side -> out/cork/
```

The Cork window is centred on 51.9500 N, 8.2201 W (UTM 29N E 553600, N 5755760), 5.76 x 5.76 km at 10 m, in East Cork tillage land between Carrigtwohill, Midleton and Lisgoold. In Ireland, the weather layers are the observed ERA5-Land values for the scene date: the weather heads learnt Bavarian seasons and cannot be recalibrated from one date.

**Fast chunk engine (real time, and the reference for a phone port):**

```
.\cy src\agri\fastrun.cy --jit main --arg 550720 --arg 5758640 --arg 2 --arg 288 --arg 0   # Cork: 2 x 2 chunks of 288 px -> out/cork_fast/
.\cy src\agri\fastrun.cy --jit main --arg 550720 --arg 5758640 --arg 1 --arg 32 --arg 1    # golden test vectors -> out/golden/
```

`fast.cy` computes any `n x n` chunk entirely on the GPU, in 15 `gpu do` kernels, with a 24-pixel margin, so stage-1 chunks join without seams and can be computed in any order and cached. On the RTX 4060 laptop a 288 x 288 chunk takes about 90 ms at best and 120 ms on average (0.9 Mpixel/s at best), 8 to 11 chunks per second, about ten times faster than `scene.cy`. Over the Cork window its layers match `scene.cy`. The soil layers correlate at 0.93-0.99 and the boundary score at 0.98. Crop class agrees on 92% of pixels, WRB group on 98% and field zones on 97.5%. Indices, unmixing fractions and elevation are identical. The differences come from the sliding 49 x 49 context mean replacing per-patch means. Its weather layers are the model's own, learnt from Bavarian seasons; in Ireland `scene.cy` replaces them with observed ERA5-Land values. **`INFERENCE.md` specifies every step, so the model can be ported to Java or any other language and checked against the test vectors.**

**Recalibrating the soil heads for a new region:**

```
.\scripts\fetch.ps1 -Region corkcal -LatMin 51.82 -LatMax 52.08 -LonMin -8.43 -LonMax -8.01 -NoWeather   # SoilGrids labels for the area
.\cy src\agri\calibrate.cy --jit main --arg 542080 --arg 5767280 --arg 48                                 # 23 km area, top-left E, N, patches per side
```

`calibrate.cy` re-fits the 24 soil heads for the new region in closed form, stacked on the Bavarian model. It uses SoilGrids footprints over the area, with lambda chosen on a held-out checkerboard of 3.84 km blocks. It writes `out/cork_soil_heads.bin`, which `scene.cy` and `fastrun.cy` then use automatically. The Cork result also ships as `models/cork_soil_heads.bin`, used when `out/` has none. Around Cork this takes about 14 seconds. It moves held-out pH from R2 -15.5 to 0.19, and organic carbon from -12.4 to 0.20 (`out/cork/recalibration.txt`).

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

The shipped model (`models/agri.bin`) is trained on two seasons, 2016 and 2017: 5,009 training patches and 1,539 held-out patches per season, about 30,000 images, stages 1 and 2. The held-out scores below come from both seasons' held-out patches. The calibration column is the share of true values inside the model's own 95% interval (2016 held-out patches, one date each).

| Output | Held-out R2 or score | Calibration |
|---|---|---|
| pH, 0-5 cm | **0.45** | 94% |
| Organic carbon, 0-5 cm | 0.16 | 95% |
| Sand, 0-5 cm | 0.17 | 99% |
| Clay, 0-5 cm | 0.00 (no signal) | 95% |
| Air temperature | **0.78** | |
| Relative humidity | 0.53 | |
| Soil moisture, 0-7 cm | 0.28 | |
| 30-day water balance | 0.15 | |
| Field boundaries | F1 **0.46** (precision 0.34, recall 0.67, threshold 0.225) | |
| Crop type, 18 classes, one date | pixel accuracy 0.58 | |

**Why two seasons, although some scores fall.** Trained on 2016 alone, the model scored higher on 2016's held-out patches: temperature 0.87, humidity 0.76, water balance 0.59, sand 0.35. Those patches share the season, so the day of year could stand in for that year's weather. It could also stand in for location, because the dates a patch is cloud-free depend on regional cloud. With a second season the same date brings different weather, and only what the imagery really shows counts. The two-season numbers are therefore the ones to expect on a new year, such as the 2023 Cork scene. pH (0.39 to 0.45 with stage 2) and soil moisture (0.17 to 0.28) improved with the extra data. The 2016-only model is kept as `out/model_2016.bin`.

Stage 2 adds about 0.04 to pH, sand, temperature and humidity. Where it would not help, the stacking guard keeps stage 1. On the laptop (RTX 4060, i7-13620H), the two-season stage 1 trains in about 10 minutes and stage 2 in about 11.

**Ireland.** The Bavarian soil heads do not carry over to Irish soils, which are acidic and rich in organic carbon. On held-out Irish blocks around Cork their R2 is -15.5 for pH and -12.4 for organic carbon. Recalibrated in 14 seconds, they reach 0.19 and 0.20; sand and clay at 0-5 cm reach only 0.04. Inside the 5.76 km Cork demo window the maps follow SoilGrids' pattern but not its exact values. Against the 835 SoilGrids cells, correlation is 0.34 for pH, 0.35 for organic carbon and 0.39 for sand, with R2 of -0.14, -0.05 and -0.01. Clay shows no agreement (correlation -0.10). The window runs end to end in about 10 seconds.

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
- Day of year is an input. Within one season it can stand in for that year's weather and, through regional cloud, for location. Training on two seasons reduces this (see Results), but some may remain.
- The weather and crop heads learnt Bavarian seasons and crops. In Ireland the scene package uses observed ERA5-Land weather instead, and the crop classes do not apply to Irish grassland.
- In `predict.cy` and `scene.cy` the convolutions zero-pad each 48 x 48 patch, so boundary scores near patch edges are less reliable. The renders mask a 2-pixel ring, and `scene.cy` blends two passes offset by half a patch. The fast engine's margin avoids patch edges.
- Munich480 is Sentinel-2 L1C (top of atmosphere, 2016-2017), while Earth Search serves L2A (surface reflectance, darker in blue). On other scenes, patterns such as boundaries, zones and relative differences carry over better than absolute soil values. Bavarian cropland also differs from Irish grassland. Training on Irish labels would fix both.
