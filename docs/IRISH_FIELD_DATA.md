# Irish agricultural field and parcel data

Researched 7 November 2026. Sources identified; no field dataset has been downloaded into the app or integrated yet.

## Best candidates

1. **DAFM anonymised LPIS, catalogued as 2024.** Official agricultural parcel polygons and attributes including crop, claimed area, digitised area, eligible hectares, grassland/tillage/arable indicators, organic indicator, and scheme-related fields. The public geospatial service advertises GeoJSON and bounding-box queries. [Official collection](https://geoapi.opendata.agriculture.gov.ie/shps/collections/anonymous-lpis-data-for-2024_2024-lpis-data?f=html), [sample records](https://geoapi.opendata.agriculture.gov.ie/shps/collections/anonymous-lpis-data-for-2024_2024-lpis-data/items?f=html).
2. **fiboa Ireland / GSAA 2024.** A converted dataset derived from DAFM, with crop names/codes and identifiers, distributed as GeoParquet and PMTiles. The publisher lists 1,123,135 boundaries, CC-BY-4.0, EPSG:4258, and a DAFM GSAA_2024 source. Useful for a tiled map overlay or extracting a local subset. [Current dataset](https://source.coop/fiboa/data/ie), [dataset index](https://fiboa.org/data/). The older `source.coop/fiboa/ireland` listing says it has moved and is no longer updated; prefer the current listing.
3. **Teagasc Irish Soil Information System.** Soil association map, soil series descriptions, representative profiles, and downloadable spatial data/API information. Use it for soil context, with its usage terms. The national soil association map is 1:250,000 and should not be presented as a soil test for each field. [Downloads/API](https://gis.teagasc.ie/soils/downloads.php), [official overview](https://teagasc.ie/environment/soil/irish-soil-types-and-maps/irish-soil-information-system/).

## Dimensions and other useful attributes

Boundary geometry supports calculating area in hectares, perimeter, lengths of boundary segments, centroid, and approximate bounding dimensions. Use a suitable projected CRS, such as the supplied UTM29N coordinates, or geodesic measurements; do not calculate square metres from longitude/latitude degrees. Irregular fields do not have a single meaningful width and length without defining how they are measured.

Keep reported claimed, eligible, and digitised areas distinct from newly calculated polygon area. Verify each source field's units and year before labelling the dashboard. Crop/organic/scheme indicators are declarations for the dataset year, not live observations.

LPIS records administrative agricultural parcels, which can split physical fields or group several fields. See the [official LPIS description](https://www.gov.ie/en/department-of-agriculture-food-and-the-marine/services/land-parcel-identification-system-lpis/) and the [SEAI-supported project report's discussion of LPIS limitations](https://www.seai.ie/sites/default/files/documents/research-project/RDD-000493-Final_Report_2025.pdf).

## Local demo extraction

Use the existing location in `dashboard/geo.mjs`:

```text
bbox west,south,east,north:
-8.262424,51.923784,-8.177723,51.976123
```

Suggested workflow: extract parcels intersecting this envelope, inspect and transform their CRS, retain source IDs/crop/year/area attributes, and add one GeoJSON or tiled boundary layer over the satellite view. A selected parcel can then show its reported area and geometry-derived dimensions beside drone observations.

The source descriptions have been verified on the web. A live bounding-box API download was attempted but could not be validated because the local client reported a certificate-verification failure. No local parcel extract is claimed to exist. The API's JSON collection description also mentions 2023 while its title and HTML description say 2024; check resource provenance before treating it as a specific year's declarations. The fiboa listing has an explicit GSAA_2024 lineage.
