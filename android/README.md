# Android app

The app turns a phone into the drone's camera module and computer. It captures still images, shares GPS and orientation, runs the soil and field model on the phone's own cores, and serves the results to the web workspace over Bluetooth LE.

## Structure

| Class | Role |
| --- | --- |
| `MainActivity` | Main screen: Bluetooth GATT server, connection code, camera requests, GPS and orientation sharing, model status. Starts Bluetooth, sensors and the model survey when the app opens. |
| `ModelTestActivity` | Model test screen: reference checks against the laptop, the area survey with a live map preview, result sharing over WiFi or USB |
| `AgriModel` | Java API for the model: loads the ARM64 image and weights, keeps one image instance per core, runs chunks |
| `SurveyRunner` | Surveys the stored scene in 16 tiles on all cores; adds vegetation indices and observed weather layers |
| `ResultServer` | Packages survey layers for Bluetooth (`results`, `results_layer`) and as a gzip scene package over HTTP |
| `PhoneTelemetry` | GPS and rotation-vector readings with freshness checks |
| `SnapshotCamera`, `ExposureGate` | Single still capture with exposure settling |
| `PacketBuffer` | Newline-framed packet assembly for incoming Bluetooth writes |
| `cpp/agri_loader.c` | JNI loader: maps the model image into executable memory and calls it |

## How the model runs

- `assets/agri/agri_arm64.bin` is the model compiled from `src/agri/phone.cy` by Century's arm64 back end, with its BSS size in `agri_arm64.txt`.
- `jniLibs/arm64-v8a/libagri.so` is the loader built from `cpp/agri_loader.c`.
- `assets/agri/agri.bin` and `cork_soil_heads.bin` are the trained weights from `models/`.
- `assets/agri/cork_cube.u16` and `cork_cube.json` hold the recorded Sentinel-2 scene (30 May 2023, 5.76 × 5.76 km), and `weather/` holds the observed ERA5-Land layers for that date.
- `golden32_*` and `cork128_*` are reference inputs and outputs computed on the laptop. The app checks itself against them and requires an exact match.

Each chunk costs about 89,000 multiply-adds per pixel. On a realme RMX3363 (Snapdragon 778G), a 144 × 144 tile takes about 18.5 s on one core and the 16-tile survey about 77 s on four.

## Build

```
cd android
./gradlew assembleDebug
```

Requirements: JDK 17, Android SDK platform 36 and build tools 35. The model image, loader and assets are committed, so the Gradle build needs no NDK.

To rebuild the model image and loader after changing `src/agri/`:

```
powershell -File scripts/build_phone.ps1 -Century <path to an arm64-capable century.exe>
```

The Century compiler in `century/bin/` targets x86-64 only. The arm64 back end is in the Century compiler source (`native/A64*.cy`); build that compiler with its `build.ps1` and pass it as `-Century`. `-Fixtures` also regenerates the scene cube and the reference chunks, which needs the downloaded Sentinel-2 scene and a scene package in `out/cork/`.

## Permissions

Bluetooth (connect and advertise), camera, fine location and internet (for the optional WiFi result sharing). The app asks for each when first needed.

## Tests

`scripts/test.ps1` compiles every class against `android.jar` and runs the JVM checks in `app/src/test/java`: packet framing, exposure gating, sensor freshness, scene cutting and model output layout.
