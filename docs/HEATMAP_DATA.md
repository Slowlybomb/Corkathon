# Heatmap data handoff

The user selected deck.gl for field analysis; the AI teammate owns model output. The dashboard reads the scene manifest documented in `src/agri/README.md` and geographically positioned numeric observations through the existing feed adapter.

## Current display

- MapLibre owns basemap, projection, navigation, and finding markers.
- deck.gl 9.4.1 MapLibreOverlay shares its WebGL context. ColumnLayer draws actual hexagonal geometry, flat or extruded.
- Three.js positions the drone from real phone GPS and attitude, with rotor motion held still.
- The approved five-colour ramp maps the displayed metric range. Heights are normalized visual scale, not metres of terrain.
- Surface/Columns, opacity, radius, and height scale are display settings, not model parameters.

Startup remains empty. There is no synthetic lattice or placeholder field boundary. Loading a scene previews actual raster pixels; received numeric observations use their supplied positions. No numeric values means no heatmap.

## Example input, not a contract

The existing WebSocket and phone observation paths accept a list or a findings/observations wrapper. Geographic coordinates use the existing adapter. These optional fields are enough to preview actual numeric output:

```json
{
  "observations": [
    {"label":"Example cell A", "latitude":51.949961, "longitude":-8.220098,
     "layer":"coverage", "value":0.42, "metric":"Example model index", "unit":"index"},
    {"label":"Example cell B", "latitude":51.9502, "longitude":-8.2198,
     "layer":"coverage", "value":0.61, "metric":"Example model index", "unit":"index"}
  ]
}
```

Zero is valid. Non-finite or missing values do not generate a cell. Different metric/unit groups are not mixed into one colour scale; select a compatible layer first. Raw model confidence should not be relabelled as soil moisture or health. Results remain unvalidated.

For live point samples, diameter describes the **display footprint**. It does not establish the observed footprint or interpolate unobserved ground. Actual Cork parcel boundaries have not been imported, so exact field clipping is not claimed.

For additional AI outputs, establish which values, units, coordinates, coverage masks, timestamps, and pixel/cell footprints they actually provide. Adapt `dashboard/geo.mjs` and `dashboard/analysis.mjs` accordingly; a raster or polygon output need not be forced into the temporary point example. Keep the deck.gl overlay, controls, and legend reusable.

Sources: [deck.gl MapLibre integration](https://deck.gl/docs/developer-guide/base-maps/using-with-maplibre), [ColumnLayer](https://deck.gl/docs/api-reference/layers/column-layer). Tests cover value handling, mixed metrics, rejecting ungeolocated values, palette interpolation, and cell inspection. The actual pinned UMD bundle was inspected for MapLibreOverlay and ColumnLayer exports. Visual depth, picking, and alignment still need a browser pass.
