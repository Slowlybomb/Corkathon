# Fullscreen field dashboard

From the repository root:

```sh
python3 -m http.server 5173 --directory dashboard
```

Open http://localhost:5173. No install or build step is required. Serve over HTTP for JavaScript modules.

The map fills the viewport. Floating modules contain layers, findings, connection settings, and replay. The document never scrolls; long panels scroll internally. On phones, layers and observations initially collapse.

- Switch between flat 2D and projected 3D. Drag to pan, Shift-drag to rotate 3D, scroll or use buttons to zoom, and use Fit to reset.
- Select findings in the map or accessible list. Play, pause, scrub, change replay speed, or export the current findings.
- Open Demo source for connection setup. Sample survey works offline. Phone / AI feed opens a real WebSocket and reports connection/error states.

## Sample data and feed

`sample-data.mjs` holds six hand-authored observations and a simulated route. Change it freely; this is not an integration schema. Map artwork is an original schematic. 3D sample-column height is illustrative intensity, not terrain or a measured property. No AI analysis or real flight runs here.

The temporary feed adapter accepts an array, `{findings: [...]}`, `{observations: [...]}`, or a single observation. It accepts a `title` or `label`, and map-local `x`/`y` either directly or inside `position`. The schematic spans x=0–1000 and y=0–900; latitude/longitude is not mapped yet. Optional description, action, time, and layer are used if available. Invalid messages retain the last observations, and feed text is escaped before display. Received findings are unvalidated and disable the synthetic heatmap. The replay route remains simulated.

Example only:

```json
{"observations":[{"label":"Patch to inspect","position":{"x":420,"y":350},"description":"Review the source image."}]}
```

No server is included; the AI teammate owns the feed. Configure its ws:// or wss:// address when available. HTTPS pages require wss://. Settings are session-only.

## Reuse and checks

Read [DESIGN.md](../DESIGN.md) before UI work. Reuse `map.mjs`, `survey.mjs`, floating-panel styles, and native controls before adding modules. The optional Manrope font falls back to local fonts without network access.

```sh
node --test dashboard/*.test.mjs
```

Browser rendering still needs review on the user's machine: the development sandbox blocked both the HTTP port and Chromium launch.
