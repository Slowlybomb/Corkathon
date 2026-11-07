# Ithir dashboard

From the repository root:

```sh
python3 -m http.server 5173 --directory dashboard
```

Open http://localhost:5173. No installation or build step is required. Internet access and WebGL2 are required: MapLibre GL JS 5.6.2, Three.js 0.180.0, deck.gl 9.4.1, map styles/tiles, and optional fonts load from external services. A visible notice reports library or map-source loading failure.

The map starts at **latitude 51.949961, longitude -8.220098**. The exact supplied corners and UTM29N references are in [DEMO_AREA.md](../docs/DEMO_AREA.md) and `geo.mjs`.

The workspace opens empty. Use **Camera module** to connect the Android companion, or **Data source** to choose a satellite scene package, WebSocket observation feed, or optional illustrative sample survey. Replay and synthetic analysis appear only with the sample survey.

## Controls

- Use the floating **Map / Satellite** switch. Satellite is the default and uses Esri World Imagery. Switching preserves camera, findings, replay, and Three.js state. Failed imagery requests return to Map with a notice.

- Switch between flat 2D and pitched 3D. MapLibre controls the map; an interleaved deck.gl layer renders analysis cells and a Three.js WebGL custom layer renders the drone.
- Drag to pan, right-drag or Ctrl-drag to rotate/tilt, scroll or use buttons to zoom, and Fit to show the survey extent. Touch navigation uses MapLibre's native gestures.
- Select findings on the map or in the accessible list. Export from the observations heading. The sample survey adds playback, scrubbing, and replay speed controls.
- Open **Data source** for a satellite scene package, observation feed, or sample survey. The feed opens a real WebSocket and reports connection and error states.
- Open **Camera module** for the Android companion's actual Bluetooth connection, status, logs, and requested still images. Follow [PHONE_LINK.md](../docs/PHONE_LINK.md) for the APK and connection steps. No model or continuous video runs yet.
- In **3D**, zoom out to see the globe. MapLibre smoothly returns to Mercator at field scale; local Three.js meshes render once that transition completes. **2D** stays flat. Both basemaps use the selected projection.
- The owner's [textured drone model](assets/drone/README.md) loads only when a survey route is present, keeping its 5.3 MB download out of empty startup. Its `hover` animation follows replay time, including pause and scrubbing; reduced motion fixes its pose. Display size, altitude, and route remain illustrative. The position dot works in 2D, on the globe, and if model loading fails.

The page does not scroll. Long floating panels scroll internally; on compact screens, layers and observations initially collapse.

Resize Field layers from its upper-right grip, and Observations, Camera module, or Data source from the lower-left grip. Drag with a mouse or touch, or focus the grip and use arrow keys (Shift for larger steps). Press Home or double-click the grip to reset. Panels stay within the viewport; collapsing preserves the expanded size until the page reloads.

## Field analysis

Load **Data source → Sample survey** to inspect the optional hexagonal sample layer. The default workspace stays empty until data arrives. Surface/Columns, opacity, cell/display diameter, and height-scale controls are inside Field layers. Hover or tap cells for values, or use the previous/next buttons for keyboard inspection. Zoom in to at least level 9 for the analysis layer; the global globe view remains available.

Received findings may optionally contain a numeric `value`, `metric`, and `unit`. Observations without a numeric value remain point findings. Different metrics/units are not combined into one scale. Live points use an illustrative display radius rather than an inferred field-wide surface. See [HEATMAP_DATA.md](../docs/HEATMAP_DATA.md) for temporary examples, not a required model schema.

`analysis.mjs` prepares values; `analysis-layer.mjs` owns the deck.gl MapLibreOverlay and ColumnLayer. Reuse these modules when the AI output arrives. Display heights and normalized colours are visual encodings, not terrain or agronomic validation.

## Satellite scene exports

The dashboard reads the renderer package documented in [src/agri/README.md](../src/agri/README.md). Obtain the generated `out/cork/manifest.json` and `layers/` folder from the AI teammate; these files are not included in this checkout. The loader does not run or train the model.

To serve an export in `out/cork/` beside the dashboard, run this **from the repository root** instead of the dashboard-only server above:

```sh
python3 -m http.server 5173
```

Open http://localhost:5173/dashboard/, choose **Data source → Satellite scene package**, enter `/out/cork/manifest.json`, and click **Load source**. Another HTTP(S) server works if it permits browser cross-origin requests; HTTPS pages need HTTPS export URLs. `file://` paths do not work.

NDVI opens first when available. Choose another numeric layer, including soil depths and weather, in **Field layers → Satellite layer**. Each layer is fetched on demand. Float32 data is read little-endian, with no-data and non-finite values excluded. WGS84 UTM metadata places pixel centres on the map, and Fit uses the scene bounds. Failed loads retain the previous observations; switching sources cancels an unfinished scene request.

This first integration previews at most 1,000 actual pixels on a regular stride, with original pixel indices preserved in exported findings. It uses the existing deck.gl cells and an explicitly illustrative display radius, rather than reconstructing the raster between samples. The legend's min/max describe the displayed pixels. It does not yet display categorical classes, RGB textures, terrain elevation, confidence rasters, or a soil volume.

Scene names, source notes, and provenance survive JSON export. Soil values remain model estimates based on SoilGrids predictions, not field samples. Cork weather layers are exported ERA5-Land values, about 9 km resolution; the 10 m output grid does not establish 10 m observational accuracy. Review the package notes and model README for regional limitations before interpreting a layer.

## Camera evidence

After a requested JPEG arrives over Bluetooth, its latest still and capture time also appear in **Observations**. The still remains available after disconnection and can coexist with satellite layers. Export includes it in a separate `cameraEvidence` object; it has no inferred location, map marker, analysis result, or automatic association with a satellite pixel. No camera model runs yet. Only the latest still is retained in memory; reload clears it. Follow [PHONE_LINK.md](../docs/PHONE_LINK.md) for the device setup.

## Data and module reuse

`sample-data.mjs` holds the optional six hand-authored findings and simulated route. Edit freely: this is not an integration schema. `geo.mjs` contains supplied coordinates, temporary sample-grid placement, and the permissive feed adapter. `survey.mjs` retains replay/filter logic. `map.mjs` owns the MapLibre/Three.js bridge; `app.mjs` coordinates the UI.

The feed accepts an array, `{findings: [...]}`, `{observations: [...]}`, or one observation. Positions may use longitude/latitude, lon/lat, lng/lat, `coordinates: [lon,lat]`, or those fields inside `position`. Legacy x/y samples still work. Text is escaped, malformed messages retain previous observations, and results remain unvalidated.

```json
{"observations":[{"label":"Patch to inspect","latitude":51.949961,"longitude":-8.220098,"description":"Review the source image."}]}
```

No feed server is included. Configure ws:// or wss:// when the AI teammate has one; HTTPS requires wss://. Settings are session-only.

Map uses OpenFreeMap; Satellite uses Esri World Imagery satellite/aerial tiles, with source attribution visible. Imagery capture dates and resolution vary by location; it is not live drone footage. Provider terms apply: https://goto.arcgisonline.com/maps/World_Imagery. No terrain elevation model is enabled. The analysis columns, drone size and altitude, and replay are illustrative. Received observations clear the sample route, drone position, and synthetic analysis surface. Map attribution remains visible.

## Checks

```sh
node --test dashboard/*.test.mjs
```

Panel interaction checks run in Chrome/Chromium with no npm dependencies:

```sh
CHROME=/path/to/chrome node scripts/check-panels.mjs
```

The browser check needs internet access for the map libraries and exercises mouse, touch, a second finger, keyboard resizing, reset, collapse, anchors, and viewport bounds. It also loads a labelled satellite fixture, switches soil layers, checks failed-load retention, and transfers a still through the Bluetooth radio double. Screenshots are written to the system temporary directory. Fixtures and radio doubles do not validate the AI model or physical hardware.

The Node checks cover geographic placement, malformed feeds, replay, filtering, camera module packets, the packaged drone asset, and analysis data/controller behavior. Chromium checks verified empty startup, optional sample playback, received-observation transitions, 2D/3D switching, and viewport bounds at 1440 × 960 and 390 × 844. The integrated analysis layer was visually reviewed. Physical Bluetooth and camera operation require a camera module.
