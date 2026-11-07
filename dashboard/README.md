# Fullscreen field dashboard

From the repository root:

```sh
python3 -m http.server 5173 --directory dashboard
```

Open http://localhost:5173. No installation or build step is required. Internet access and WebGL2 are required: MapLibre GL JS 5.6.2, Three.js 0.180.0, map styles/tiles, and optional fonts load from external services. A visible notice reports library or map-source loading failure.

The map starts at **latitude 51.949961, longitude -8.220098**. The exact supplied corners and UTM29N references are in [DEMO_AREA.md](../docs/DEMO_AREA.md) and `geo.mjs`.

## Controls

- Use the floating **Map / Satellite** switch. Satellite is the default and uses Esri World Imagery. Switching preserves camera, findings, replay, and Three.js state. Failed imagery requests return to Map with a notice.

- Switch between flat 2D and pitched 3D. MapLibre controls the map; a Three.js WebGL custom layer renders analysis meshes and the drone. The Canvas2D projector is removed.
- Drag to pan, right-drag or Ctrl-drag to rotate/tilt, scroll or use buttons to zoom, and Fit to show the full demo extent. Touch navigation uses MapLibre's native gestures.
- Select findings on the map or in the accessible list. Play/pause, scrub, change replay speed, and export findings.
- Open Demo source for the compact connection panel. Phone / AI feed opens a real WebSocket and shows connection and error states.

The page does not scroll. Long floating panels scroll internally; on compact screens, layers and observations initially collapse.

## Data and module reuse

`sample-data.mjs` holds six hand-authored findings and a simulated route. Edit freely: this is not an integration schema. `geo.mjs` contains supplied coordinates, temporary sample-grid placement, and the permissive feed adapter. `survey.mjs` retains replay/filter logic. `map.mjs` owns the MapLibre/Three.js bridge; `app.mjs` coordinates the UI.

The feed accepts an array, `{findings: [...]}`, `{observations: [...]}`, or one observation. Positions may use longitude/latitude, lon/lat, lng/lat, `coordinates: [lon,lat]`, or those fields inside `position`. Legacy x/y samples still work. Text is escaped, malformed messages retain previous observations, and results remain unvalidated.

```json
{"observations":[{"label":"Patch to inspect","latitude":51.949961,"longitude":-8.220098,"description":"Review the source image."}]}
```

No feed server is included. Configure ws:// or wss:// when the AI teammate has one; HTTPS requires wss://. Settings are session-only.

Map uses OpenFreeMap; Satellite uses Esri World Imagery satellite/aerial tiles, with source attribution visible. Imagery capture dates and resolution vary by location; it is not live drone footage. Provider terms apply: https://goto.arcgisonline.com/maps/World_Imagery. No terrain elevation model is enabled. The analysis columns, drone size and altitude, and replay are illustrative. Received observations disable the synthetic analysis surface. Map attribution remains visible.

## Checks

```sh
node --test dashboard/*.test.mjs
```

These check corner placement, coordinate priority, malformed feed handling, replay interpolation, filtering, and source-selection consistency. They do not constitute a WebGL integration test. Browser rendering still needs review on the user's machine because the sandbox blocked preview-server binding and Chromium launch.
