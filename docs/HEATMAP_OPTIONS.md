# Field heatmap options

Researched 7 November 2026. The user selected **deck.gl**. The dashboard now uses a six-sided ColumnLayer for value cells, with surface/columns controls; Three.js retains the drone. The comparison below is historical research context. Preserve MapLibre + Three.js, the five approved colours, satellite switching, and the fullscreen floating-module layout.

## Visual and library options

| Option | Visual result | Fit and trade-off | Inspect |
| --- | --- | --- | --- |
| MapLibre native heatmap | Smooth overlapping colour patches over imagery | Already installed; a straightforward view of weighted observation density. It is not interpolation of a measured soil property | [Live example](https://maplibre.org/maplibre-gl-js/docs/examples/create-a-heatmap-layer/), [style reference](https://maplibre.org/maplibre-style-spec/layers/#heatmap) |
| Three.js InstancedMesh | Real 3D square or hexagonal columns, with matching flat cells | Already used by `rebuildColumns` in `dashboard/map.mjs`. Best starting point for the user's reference image. Reuse the scene, geographic transforms, materials, and cell dataset; change geometry rather than add a new renderer | [Official source](https://github.com/mrdoob/three.js/blob/master/src/objects/InstancedMesh.js), [hex-column visual reference using deck.gl](https://deck.gl/examples/hexagon-layer) |
| deck.gl aggregation layers | Smooth heatmaps, grids, hexagonal bins, contour bands | Broad ready-made GPU visualisation toolkit with documented MapLibre integration. Adds another rendering layer; it is not Three.js. Keep Three.js for the required 3D implementation unless the project owner changes that requirement | [Heatmap demo](https://deck.gl/examples/heatmap-layer), [hexagon demo](https://deck.gl/examples/hexagon-layer), [contour demo](https://deck.gl/examples/contour-layer), [MapLibre integration](https://deck.gl/docs/developer-guide/base-maps/using-with-maplibre) |
| Turf.js interpolation and contours | Gridded estimated values or contour lines/bands | A geometry/data helper, not a rendering engine. Its IDW interpolation can produce grid estimates from sample values; render outputs with MapLibre/Three.js. Cell size, units, interpolation assumptions, and field clipping must be explicit | [Interpolate](https://turfjs.org/docs/api/interpolate), [isolines](https://turfjs.org/docs/api/isolines), [hex grid](https://turfjs.org/docs/api/hexGrid) |
| H3 / h3-js | Consistent geographic hexagonal cells with stable IDs | An indexing system, not a heatmap renderer. Useful later for comparing visits at consistent cells and zoom levels. Adds less value than a simple local grid for one small demo field | [Overview](https://h3geo.org/docs/), [polygon-to-cells semantics](https://h3geo.org/docs/api/regions/) |

## Recommended first direction

The selected implementation uses deck.gl ColumnLayer to offer **flat cells / 3D columns**, fed from the same values and colour scale. Hexagons can provide the reference-image look; square cells are also appropriate when the model produces image-aligned raster output. The best shape depends on the AI output rather than aesthetics alone.

Suggested controls for a later implementation: layer/metric selector, flat versus raised display, opacity, cell size, value tooltip, and selected-field boundary. Add only the controls the actual input data supports. Keep one legend with the metric, units, range, timestamp, and sample/estimate status.

For smooth viewing, render a georeferenced value raster or interpolate supported samples. A density heatmap brightens where observations cluster and can mislead when drone sampling is uneven; do not label that output moisture or soil quality. Clip the display to the selected parcel and leave unsurveyed areas visibly unassessed. Clipping cannot be based only on a cell centre if exact boundary containment matters; trim boundary cells or use a suitable mask.

Deck.gl is the most extensive optional library here, but the existing MapLibre + Three.js stack already covers the first proposed visual. The selected deck.gl dependency is pinned to 9.4.1; no additional grid or interpolation dependency has been added.

## Current evidence and boundaries

The app still has six synthetic observations, not a measured property raster. Real Cork parcel geometry has not been selected or imported. Current sample heatmap cells do not establish soil measurements. The AI teammate owns analysis and data generation. This research does not change the chosen renderer or install any new dependencies.
