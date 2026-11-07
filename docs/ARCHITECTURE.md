# Architecture

Ithir has three parts: a model written in Century, an Android app that runs the model on the phone, and a web workspace that renders the results. They share one model file, one scene geometry and one Bluetooth protocol.

```
            laptop (training, Century)                     phone (Android, ARM64)                         browser (dashboard)
 Sentinel-2 ─► train.cy, stage2.cy ─► models/agri.bin ─► agri_arm64.bin (model) ─► SurveyRunner ─► ResultServer ─BLE─► phone-results.mjs ─► model-panel.mjs ─► map.mjs
 SoilGrids     calibrate.cy ────────► cork_soil_heads.bin   agri_loader.c (JNI)      16 tiles,       layers as         decode, cache     styles, charts,      MapLibre + Three.js
 ERA5-Land                                                  AgriModel.java           4 cores         compressed grids                    compare view          drone, frustum
```

## Model (`src/agri/`)

The model maps ten Sentinel-2 bands to 31 output layers per 10 m pixel: field boundary score, crop class, soil group, pH, organic carbon, clay and sand at six depths, and four weather variables. Training uses no backpropagation.

| Stage | Description |
| --- | --- |
| Base channels | 21 per pixel: z-scored bands, NDVI, NDMI, NDWI, NDRE, BSI, spectral unmixing fractions, day of year |
| Convolutional features | four layers of 48 fixed random 3×3 filters at dilations 1, 2, 4 and 8 |
| Law neurons | 58 formulas selected from 30,913 candidates by exact small solves on held-out moments |
| Heads | ridge regressions over 301 features, each solve certified by its normal-equation residual |
| Stage 2 | the same heads refit on stage 1's maps; a guard keeps stage 1 wherever stage 2 would not help |
| Coarse labels | soil (250 m) and weather (9 km) heads are fitted on footprint averages, so predictions stay at 10 m |
| Uncertainty | Bayesian predictive variance for every soil and weather output |

There are three implementations of the forward pass, all computing the same function:

- `predict.cy` and `scene.cy`: the patch pipeline used for evaluation and scene packages.
- `fast.cy`: the chunk engine, fifteen GPU kernels with a 24-pixel margin so chunks join without seams.
- `phone_core.cy`: the same chunk pipeline with CPU-friendly convolution and head kernels, entered from `phone.cy`.

`tests/agri/phone_core_test.cy` runs `phone_core.cy` on the laptop CPU and requires its outputs to equal the GPU engine's exactly. [`src/agri/INFERENCE.md`](../src/agri/INFERENCE.md) specifies the model file and every step of the forward pass.

## Phone (`android/`)

1. `scripts/build_phone.ps1` compiles `src/agri/phone.cy` with Century's arm64 back end (`--target arm64 --flat`). The result, `agri_arm64.bin`, is a position-independent AArch64 image (entry at byte 0, AAPCS64, no system calls) with its heap in BSS.
2. `agri_loader.c`, compiled with the NDK, maps the image into executable memory, one copy per core, and calls its entry with eight integer arguments: addresses and lengths of the weights, regional soil heads, input bands and output buffer, the chunk size and the day of year.
3. `AgriModel.java` loads the image and weights from the app's assets and hands each call a free instance, so four chunks run in parallel.
4. `SurveyRunner.java` cuts the stored Cork scene into 16 tiles of 144 × 144 pixels (192 × 192 with margin), runs them on four cores and assembles 25 model layers. It adds NDVI, NDMI and NDWI computed from the same bands, and the observed ERA5-Land weather layers.
5. `ResultServer.java` turns a survey into Bluetooth packets on request, or into a gzip-compressed scene package over HTTP.
6. `MainActivity.java` runs the Bluetooth link, camera, GPS and orientation sensors, and starts the self-check and survey when the app opens. `ModelTestActivity.java` is the on-device test screen.

Results on the phone are identical to the laptop's (maximum difference 0) for both reference chunks bundled in the app.

## Bluetooth protocol

The phone is a GATT server; the browser connects with Web Bluetooth. Messages are UTF-8 JSON objects followed by a newline, split across 20-byte writes from the browser and notifications of up to 180 bytes from the phone. Every message carries `v: 1`, a `type` and `sentAt`. The full camera and sensor protocol is in [PHONE_LINK.md](PHONE_LINK.md).

| Command (browser → phone) | Reply (phone → browser) |
| --- | --- |
| `hello` with the six-digit `pin` | `ready`, then `status` |
| `ping` | `pong` |
| `capture`, `stop_camera` | `ack`, `image`, or `error` |
| `results` | `results`: the scene geometry and the list of layers with units, group, source, minimum, maximum and mean |
| `results_layer` with `layer` and `grid` | one or more `results_layer` parts |

A layer is averaged to `grid` × `grid` cells (96, 192 or 576 for the 576-pixel scene), quantised to one byte per cell between `min` and `max` (255 is no data), compressed with zlib deflate and base64-encoded. Data above 45,000 characters is split into `parts`, each with its `part` index. A 192-cell layer arrives in about 1.7 s and the full 576-cell layer in about 6 s. While the survey is still running, the phone answers with an `error` giving its progress, and `status.model` reports `computing`, `results_ready` or `on_device`.

## Web workspace (`dashboard/`)

| Module | Role |
| --- | --- |
| `phone.mjs`, `phone-panel.mjs` | Web Bluetooth connection, packet framing, camera and sensor panel |
| `phone-results.mjs` | Requests results, reassembles parts, decodes and caches layers |
| `model-panel.mjs` | Layer and detail choice, styles (heatmap on fields, management zones, 3D relief), histogram, soil depth profile, data-view thumbnails, side-by-side comparison |
| `map.mjs` | MapLibre map, Three.js layer for the drone, its camera frustum and the 3D relief surface, camera modes |
| `flight.mjs` | Drone pose: phone orientation, and GPS movement mapped onto the scene |
| `scene.mjs`, `analysis*.mjs` | Satellite scene packages and the deck.gl analysis layer |

Heatmaps are drawn only on field interiors: a pixel is shown when its field boundary score is below the scene's 82nd percentile and its NDVI is above 0.25, so roads, hedges and buildings keep the satellite imagery.

## Scene geometry

The demo scene is 576 × 576 pixels of 10 m in UTM zone 29N (EPSG:32629), with its north-west corner at E 550720, N 5758640 ([DEMO_AREA.md](DEMO_AREA.md)). The phone stores it as `cork_cube.u16`: ten bands of 624 × 624 digital numbers, including the 24-pixel margin, band-major. Reflectance is the digital number divided by 10,000.
