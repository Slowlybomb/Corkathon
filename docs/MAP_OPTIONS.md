# Map and globe shortlist

Researched 7 November 2026. The project owner has selected **MapLibre + Three.js**. The original shortlist below is retained as research context. Dependencies are pinned CDN imports; the local demo uses a Mercator map with a Three.js WebGL layer. Three.js is required for the 3D renderer.

## Renderers

| Option | Three.js relationship | Fit for this project | Inspect |
| --- | --- | --- | --- |
| iTowns | Framework built on Three.js | Strong candidate for a geographic Earth globe with terrain, imagery, vector layers, and 3D objects. Supports 2D and 3D geospatial views. My first candidate when a genuine globe and Three.js are central | [Examples](https://www.itowns-project.org/itowns/examples/), [source and licensing](https://github.com/iTowns/itowns) |
| MapLibre GL JS + Three.js custom layer | MapLibre renders the base map; Three.js supplies custom 3D scene objects | Strong candidate for the fullscreen field dashboard. Supports geographic overlays, terrain, and globe projection. Verify the chosen Three.js integration under both flat and globe projections: a working Mercator example does not establish globe compatibility | [Globe demo](https://maplibre.org/maplibre-gl-js/docs/examples/display-a-globe-with-a-vector-map/), [Three.js integration example](https://maplibre.org/maplibre-gl-js/docs/examples/add-3d-tiles-3d-objects-and-models-using-threejs/), [project overview](https://maplibre.org/projects/gl-js/) |
| Globe.gl / three-globe | Three.js/WebGL globe library | Good candidate for overview points, paths, polygons, heatmaps, and custom Three.js objects. Includes a tiled-map engine. Field-scale terrain precision and a flat-mode workflow need assessment; I would favour a geographic mapping framework for detailed field work | [Tiled-globe demo](https://globe.gl/example/tile-engine/), [API and examples](https://globe.gl/), [source](https://github.com/vasturiano/globe.gl) |
| CesiumJS | Separate rendering engine, not Three.js | Useful comparison: geographic globe, terrain, imagery, 3D Tiles, telemetry, and runtime 2D/3D switching. It does not fulfil the requested Three.js engine choice by itself | [Features and licensing](https://cesium.com/platform/cesiumjs/), [playground](https://sandcastle.cesium.com/) |

The first three are free/open-source library options. iTowns documents MIT/CeCILL-B dual licensing. CesiumJS documents Apache 2.0 and free commercial/non-commercial use. Hosted imagery, terrain, and third-party services retain their own terms; library availability is not a blanket licence to those assets.

The recommendations above are judgments based on documented capabilities, not results of an integration benchmark. No claim is made that the demo providers cover Cork with high-resolution aerial photography.

## Map and elevation data, selected separately

| Source | What it provides | Free-use boundary / practical limit | Inspect |
| --- | --- | --- | --- |
| OpenFreeMap | OpenStreetMap-based vector basemaps | Its public service states no API key, registration, or map-view/request limits. This is a drawn map, not satellite imagery. Preserve source attribution | [Styles and quick start](https://openfreemap.org/quick_start/), [service description](https://openfreemap.org/) |
| Mapterhorn | Public terrain/elevation tiles | Global 30 m terrain plus finer regional datasets. Ireland is not listed among the finer-resolution regions on the reviewed page. Underlying open-data sources have attribution requirements. Terrain is separate from aerial imagery | [Viewer](https://mapterhorn.com/viewer), [coverage and licensing](https://mapterhorn.com/), [attribution](https://mapterhorn.com/attribution) |
| Copernicus Sentinel-2 | Free satellite data, including four 10 m bands | Useful for field context; 10 m imagery is not drone-scale detail. Obtaining open data and operating a hosted imagery endpoint are separate tasks and may have different quotas | [Collection and resolutions](https://dataspace.copernicus.eu/data-collections/copernicus-sentinel-missions/sentinel-2), [browser](https://browser.dataspace.copernicus.eu/) |
| NASA GIBS | Public standards-based imagery services | Useful source to evaluate for broader Earth imagery/context. Check the selected layer's resolution and attribution; do not assume close-up field detail | [Service documentation](https://nasa-gibs.github.io/gibs-api-docs/access-basics/) |

## Suggested inspection order

1. Inspect iTowns for the globe, terrain, and imagery experience.
2. Inspect MapLibre's globe and Three.js examples for a field-workspace alternative.
3. Inspect Globe.gl if a globe overview is more important than detailed local terrain.

Then choose the imagery and terrain sources. For drone overlays we will need geographic positions (latitude/longitude, and altitude when relevant); the prototype's local x/y coordinates are not yet georeferenced. A single phone image also needs a known footprint or camera pose to place it accurately as a ground overlay. Keep that integration flexible until the AI teammate's output is known.
