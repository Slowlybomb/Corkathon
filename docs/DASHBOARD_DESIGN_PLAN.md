# Dashboard implementation notes

The current design authority is [DESIGN.md](../DESIGN.md). The user's fullscreen-map reference and fixed palette replace the earlier light sidebar dashboard proposal.

Implemented in `dashboard/` on `feat/field-dashboard`:

- A viewport-sized map with floating toolbar, layers, observations, and replay modules.
- Five approved brand colours: forest, sage, cream, peach, and ochre.
- MapLibre 2D and pitched 3D, with a Three.js custom WebGL layer for illustrative analysis cells and the drone.
- Shared map renderer, geographic placement helpers, panel styles, disclosure behaviour, and controls.
- Existing replay/filter helpers and six freely replaceable sample observations.
- Compact connection setup, real optional WebSocket connection, and a permissive adapter for geographic or legacy sample-grid positions.
- Document scrolling disabled; long panel content scrolls internally. Phone panels initially collapse and open one at a time.

The map uses OpenFreeMap geographic tiles at the user's supplied Cork demo location; see [DEMO_AREA.md](DEMO_AREA.md). It is a drawn basemap, not satellite imagery. The sample surface is not measured terrain or calibrated analysis. Received observations disable the synthetic sample surface. The route remains simulated in either source mode.

Run instructions and prototype boundaries are in [dashboard/README.md](../dashboard/README.md). Replay, filtering, geographic placement, and feed adaptation have Node checks. Browser visual verification remains pending because this execution environment denied preview-server binding and Chromium launch.
