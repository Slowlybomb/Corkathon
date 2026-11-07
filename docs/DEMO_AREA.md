# Cork demo area

User-supplied location, 7 November 2026. Geographic coordinates are preserved exactly as supplied. MapLibre uses **[longitude, latitude]**; displayed geographic coordinates are WGS84. The UTM references use zone 29N, EPSG:32629.

| Position | Easting (m) | Northing (m) | Latitude | Longitude |
| --- | ---: | ---: | ---: | ---: |
| Centre | 553600.0 | 5755760.0 | 51.949961 | -8.220098 |
| Top-left | 550720.0 | 5758640.0 | 51.976123 | -8.261574 |
| Top-right | 556480.0 | 5758640.0 | 51.975567 | -8.177723 |
| Bottom-left | 550720.0 | 5752880.0 | 51.924339 | -8.262424 |
| Bottom-right | 556480.0 | 5752880.0 | 51.923784 | -8.178670 |

The UTM rectangle is 5,760 × 5,760 m. This is a **survey/demo extent**, not a verified farm or field boundary. The map opens around the supplied centre and fits the entire extent with space for floating controls.

`dashboard/geo.mjs` is the location source. It stores both coordinate forms. No new UTM conversion is implemented or claimed: the supplied longitude/latitude values place the map and extent directly.

The disposable sample survey retains its old x=0–1000, y=0–900 grid. Bilinear interpolation between the four geographic corners places those sample findings and the replay route inside this area. That interpolation is a demo-placement shortcut, not a surveying transformation. The interpolated middle differs from the separately supplied centre by roughly one metre because the coordinates are rounded and geographic interpolation is approximate.

Incoming observations may supply `latitude`/`longitude`, `lat`/`lon`, `lat`/`lng`, a `position` with those fields, or `coordinates: [longitude, latitude]`. Geographic coordinates take priority over legacy sample x/y. UTM-only feed observations are not converted yet. The format stays flexible until the AI teammate's output is agreed.

The basemap is OpenFreeMap using OpenStreetMap-derived data, with provider attribution visible. It needs internet access. No satellite layer or terrain elevation model is enabled. Three.js renders real 3D mesh columns and the drone over the map. The sample columns, oversized drone model, 100 m demo altitude, findings, and replay are synthetic, not field measurements or actual flight telemetry.

Implementation references: [OpenFreeMap quick start](https://openfreemap.org/quick_start/), [MapLibre custom-layer interface](https://maplibre.org/maplibre-gl-js/docs/API/interfaces/CustomLayerInterface/), [MapLibre Three.js examples](https://maplibre.org/maplibre-gl-js/docs/examples/add-3d-tiles-3d-objects-and-models-using-threejs/).
