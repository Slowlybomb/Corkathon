# Cork demo area

User-supplied location, 7 November 2026. Geographic coordinates are preserved exactly as supplied. MapLibre uses **[longitude, latitude]**; displayed geographic coordinates are WGS84. The UTM references use zone 29N, EPSG:32629.

| Position | Easting (m) | Northing (m) | Latitude | Longitude |
| --- | ---: | ---: | ---: | ---: |
| Centre | 553600.0 | 5755760.0 | 51.949961 | -8.220098 |
| Top-left | 550720.0 | 5758640.0 | 51.976123 | -8.261574 |
| Top-right | 556480.0 | 5758640.0 | 51.975567 | -8.177723 |
| Bottom-left | 550720.0 | 5752880.0 | 51.924339 | -8.262424 |
| Bottom-right | 556480.0 | 5752880.0 | 51.923784 | -8.178670 |

The UTM rectangle is 5,760 × 5,760 m. These supplied reference coordinates describe the original demo area, not a verified farm or field boundary. They remain in `dashboard/geo.mjs`; the map opens at the supplied centre without drawing or fitting a placeholder rectangle.

Fit uses the loaded scene's geographic bounds or the positions of received observations. Without either, a fresh phone GPS fix can be located; an empty workspace has no inferred footprint. The retired x/y sample grid and simulated replay have been removed.

Incoming observations may supply `latitude`/`longitude`, `lat`/`lon`, `lat`/`lng`, a `position` with those fields, or `coordinates: [longitude, latitude]`. Records without geographic coordinates are not plotted. `scene.mjs` reads the exported raster's WGS84 UTM CRS, origin, and pixel size and converts pixel centres to longitude/latitude with the inverse UTM series shared with the model implementation. UTM-only point-feed records are not converted automatically.

The drawn basemap is OpenFreeMap using OpenStreetMap-derived data. Satellite mode uses Esri World Imagery with visible source attribution. Both need internet access. Imagery date and detail vary by location; this is not live camera imagery. No terrain elevation model is enabled. deck.gl renders numeric analysis cells; their diameter and height are display scales. Three.js places the drone from fresh phone GPS and attitude. Its size is exaggerated for visibility. There is no simulated map position or fixed demo altitude.

Implementation references: [OpenFreeMap quick start](https://openfreemap.org/quick_start/), [MapLibre custom-layer interface](https://maplibre.org/maplibre-gl-js/docs/API/interfaces/CustomLayerInterface/), [MapLibre Three.js examples](https://maplibre.org/maplibre-gl-js/docs/examples/add-3d-tiles-3d-objects-and-models-using-threejs/).
