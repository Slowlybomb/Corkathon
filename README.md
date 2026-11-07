# Ithir

On-device field analysis for agriculture. A soil and field model trained on satellite imagery runs on a phone mounted on a drone; a web workspace shows its results as field heatmaps, management zones and 3D views, and follows the drone's orientation and movement.

```
Sentinel-2 imagery ─► model (src/agri, Century) ─► ARM64 image ─► Android app (android/) ─Bluetooth LE─► web workspace (dashboard/)
                      trained on a laptop GPU      compiled         computes on the phone                 heatmaps, charts, 3D drone views
```

The design is described in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Repository layout

| Path | Contents |
| --- | --- |
| [`src/agri/`](src/agri/README.md) | The model: data loading, training, evaluation, the fast chunk engine and the phone entry point, written in Century |
| `lib/` | Century libraries used by the model: GeoTIFF, UTM, terrain tiles, PNG, binary and text I/O, linear algebra, random numbers |
| `models/` | Trained weights shipped with the app (`agri.bin`, Irish soil recalibration `cork_soil_heads.bin`) |
| [`android/`](android/README.md) | Android app: camera module, phone sensors, on-device model, Bluetooth link |
| [`dashboard/`](dashboard/README.md) | Web workspace: MapLibre, Three.js and deck.gl, no build step |
| `scripts/` | Data download, training pipeline, phone model build, local web server, test runner |
| `tests/` | Model consistency test (phone code path against the laptop engine) |
| `docs/` | Architecture, Bluetooth protocol, demo area and design notes |
| `century/` | Century compiler for Windows, [language manual](century/CENTURY.md) and language examples |

## Quick start

1. **Web workspace:** `python scripts/serve.py`, then open http://localhost:5173/dashboard/ in desktop Chrome (Web Bluetooth needs Chrome on localhost or HTTPS).
2. **Phone app:** `cd android` and `./gradlew assembleDebug`, then install `app/build/outputs/apk/debug/app-debug.apk`. On launch the app starts Bluetooth, shares GPS and orientation, checks the model against reference outputs and surveys the demo area on all cores.
3. **Connect:** in the workspace open **Camera module** and enter the six-digit code shown on the phone. Model results load automatically into the **Drone model** panel.
4. **Model:** downloading the data, training and evaluating are described in [src/agri/README.md](src/agri/README.md). The trained model is already in `models/`.

## Tests

```
powershell -File scripts/test.ps1
```

This runs the dashboard unit tests (Node), the Android unit checks (JVM, against `android.jar`) and the model consistency test, which requires the phone code path to reproduce the laptop GPU engine exactly. Use `-SkipModel` when the Sentinel-2 scene in `data/` has not been downloaded. Requirements: Node 18+, JDK 17 on `PATH`, the Android SDK (`ANDROID_HOME`).

## Measured performance

| Step | Result |
| --- | --- |
| Training (two seasons, about 30,000 Sentinel-2 images) | about 21 minutes on an RTX 4060 laptop GPU; every weight is an exact, certified solve |
| Regional recalibration (Cork) | 14 seconds |
| Survey on the phone (realme RMX3363, 5.76 × 5.76 km, 331,776 pixels at 10 m) | 77 seconds on 4 cores |
| Phone against laptop | identical outputs (maximum difference 0) |
| Model image for the phone | 40 KB of ARM64 code, compiled in under a second |
| One map layer over Bluetooth | 1.7 s at 30 m, 5.9 s at full 10 m resolution |

## Accuracy

Scores on held-out patches that were not used for training ([details](src/agri/README.md#results)):

| Output | Score |
| --- | --- |
| Crop type, 18 classes, one date | 58% of pixels correct |
| Field boundaries | F1 0.46 (precision 0.34, recall 0.67) |
| Soil pH, 0-5 cm | R² 0.45 |
| Air temperature | R² 0.78 |
| Uncertainty | 94-99% of true values fall inside the model's 95% interval |
| Ireland after recalibration | pH R² 0.19, organic carbon R² 0.20 |

## Data and licences

| Source | Use | Terms |
| --- | --- | --- |
| Copernicus Sentinel-2 (Earth Search on AWS) | Model input | Free and open; attribute "Contains modified Copernicus Sentinel data" |
| Munich480 (Kaggle) | Training patches and crop labels | See the dataset page |
| ISRIC SoilGrids 2.0 | Soil labels | CC BY 4.0 |
| ERA5-Land via Open-Meteo | Weather labels and observed weather layers | Copernicus licence; Open-Meteo data CC BY 4.0 |
| AWS Terrain Tiles | Elevation | Attribution per source dataset |
| Esri World Imagery, OpenFreeMap / OpenStreetMap | Basemaps | Provider terms; OpenStreetMap ODbL |

## Limitations

- Soil labels are SoilGrids predictions at 250 m, not field samples. Soil values are model estimates and must not be read as measurements.
- Weather layers in the workspace are ERA5-Land observations for the scene date, not model output.
- The phone surveys a recorded Sentinel-2 scene stored in the app. Using the drone camera's frames as model input is future work.
- In the workspace, the drone's position is the phone's GPS movement mapped onto the scene, starting at its centre.

Licensed under the terms in [LICENSE](LICENSE).
