---
name: Ithir field workspace
description: Fullscreen field map with floating operational controls
colors:
  forest: "#2C6E49"
  sage: "#4C956C"
  cream: "#FEFEE3"
  peach: "#FFC9B9"
  ochre: "#D68C45"
  ink: "#102C20"
  surface: "#153526"
  muted: "#B8CAB5"
typography:
  title:
    fontFamily: "Manrope, Avenir Next, system-ui, sans-serif"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "-0.5px"
  body:
    fontFamily: "Manrope, Avenir Next, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.75
rounded:
  control: "7px"
  panel: "14px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "18px"
  xl: "24px"
components:
  primary-button:
    backgroundColor: "{colors.cream}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    height: "40px"
  primary-button-hover:
    backgroundColor: "{colors.peach}"
  floating-panel:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.cream}"
    rounded: "{rounded.panel}"
---

# Ithir design system

## Overview

The map is the workspace. The user's supplied grazing-map reference establishes a fullscreen spatial view, with compact controls and summaries floating above it. Preserve this composition when adding features. The previous sidebar, headline, and card-dashboard composition is retired.

The user chose the five brand colours in the frontmatter. They are fixed. Deep green derived surfaces and muted text support contrast; map imagery may have natural terrain colours. New interface accents must come from the approved palette.

This file is the current visual authority. Product and data responsibilities remain in `AGENTS.md`.

## Colors

- Forest anchors the interface and selected map elements.
- Sage indicates vegetation, lower illustrative variation, and neutral source status.
- Cream provides readable text, active controls, and light heatmap values.
- Peach identifies the drone position and inspection emphasis without asserting a diagnosis.
- Ochre marks the upper end of the illustrative variation scale.
- Ink and surface are derived deep green neutrals. Muted text remains readable on these dark surfaces.

Use cream or ink on filled controls as appropriate. Sage and ochre are not small-text colours on cream. Every heatmap needs a visible legend; every status needs words as well as colour. Sample intensity is not a soil measurement. Do not add blue, purple, red, or neon interface accents.

## Typography

Use Manrope with the declared local fallbacks. Short, sentence-case labels take priority. Field names and findings provide the hierarchy; there is no marketing headline above the map. Metadata is subordinate, with tabular numbers for times and readings. Do not add decorative uppercase labels or technical-looking monospace text.

## Layout

**The map stays visible.** The root occupies the viewport (`100dvh`). The document and body do not scroll. Long lists, detail content, and connection settings may scroll inside their own bounded panels.

- Full-bleed map beneath all modules; no content grid or fixed sidebar.
- Floating top toolbar: identity, selected field, survey context, connection setup.
- Lower-left floating layer module: analysis selection and legend.
- Upper-right floating observation module: a short list and selected finding details.
- A floating Map/Satellite control, plus lower-right projection and zoom controls.
- Bottom replay module, inset from viewport edges, with a small source credit below.

Ithir opens with an empty workspace and a connection action. The sample survey is optional under Data source. Hide layers until observations arrive, the intensity legend without supporting numeric data, and replay without a route. Export belongs beside the observations. Keep the Ithir name visible on small screens and omit fixed survey dates and duplicate map-context labels.

Maintain roughly 24 px desktop edge insets and 12 px on smaller screens. Controls should leave the central field usable. At phone sizes, modules initially collapse to headings and expand on demand; they must not force page scrolling. Connection setup is a small anchored panel, not a separate settings page.

## Elevation & Depth

Dark floating surfaces use a restrained offset soft shadow. Their depth separates them from the map. Do not add decorative glows or blur washes.

The selected stack is MapLibre GL JS for geographic navigation, deck.gl for the field analysis, and Three.js for the drone model. The user explicitly chose deck.gl for the heatmap. An interleaved `MapLibreOverlay` shares the map WebGL context; a six-sided `ColumnLayer` provides flat hexagonal cells or raised geometry. Keep the same cells and colour scale between surface and columns. The Canvas2D software projector remains retired.

Keep terrain elevation separate from analysis-column height. Elevation requires an elevation dataset; soil or vegetation overlays require their own supporting observations. Preserve consistent geographic positioning across 2D and 3D modes. The demo centre, supplied corners, and coordinate conventions are recorded in `docs/DEMO_AREA.md`. A shared Map/Satellite segmented control switches between OpenFreeMap and Esri World Imagery without resetting the camera, replay, observations, or Three.js scene. Satellite is the default. Keep provider attribution visible. No terrain elevation dataset is enabled.

The user requested a globe when zoomed out. In 3D, MapLibre's globe projection wraps native map layers around the planet and transitions to Mercator at field scale. Local Three.js meshes render only after the transition reaches Mercator. The deck.gl field layer is hidden below zoom 9; the geographic point and route layers remain on the map. The 2D view uses flat Mercator.

Motion explains interaction: map navigation, projection changes, and replay movement. Avoid idle pulsing, entrance sequences, and ornament. Respect reduced-motion preferences.

The analysis module reuses the existing segmented control for Surface/Columns. Opacity, display diameter, and height scale use native range inputs. The legend must name the metric, range, units, and sample/unvalidated status. Cell tooltips use plain text; previous/next controls support keyboard inspection. Column height is a visual scale, not terrain elevation. Until numeric model data arrives, observations remain points.

## Shapes

Use restrained rounded panels and smaller rounded controls. Circles are reserved for point markers, status indicators, and the replay action. Use consistent thin SVG icon strokes. Field boundaries and heatmap cells are map geometry, not decorative shapes.

## Components

Check for an existing component before adding one. Reuse a working module or extend it with one clear option before introducing another abstraction.

| Component | Existing implementation | Reuse rule |
| --- | --- | --- |
| Field map | `dashboard/map.mjs`, `createFieldMap` | Keep the interaction boundary while using MapLibre sources/layers and the Three.js scene |
| Field analysis | `dashboard/analysis.mjs` and `dashboard/analysis-layer.mjs` | One value adapter and one interleaved deck.gl overlay; reuse for filters, display settings, and inspection |
| Geographic placement | `dashboard/geo.mjs` and MapLibre Mercator coordinates | Preserve supplied WGS84 positions; map temporary sample x/y through the geographic extent; use the engine camera in 3D |
| Replay and filtering | `dashboard/survey.mjs` | Preserve interpolation and filtering rather than duplicating them in UI code |
| Floating surface | `.floating-surface` in `dashboard/style.css` | Shared material for toolbar, modules, settings, and playback |
| Module heading/disclosure | `.panel-heading` and `wireDisclosure` in `app.mjs` | Same collapse behaviour and accessible expanded state for layers and observations |
| Basemap switch | `.view-switch` styling, `setBasemap` in `map.mjs` | Toggle the satellite raster layer above the drawn basemap and below survey overlays; do not replace the style or shared WebGL context |
| Buttons | `.button`, `.primary`, `.icon-button` | Reuse size, hover, focus, and disabled treatment; icon-only controls require accessible names |
| Observation list/detail | `renderFindings`, `renderDetail` in `app.mjs` | Reuse selected state and evidence labels; escape received text |
| Connection setup | `#connection-panel` in `index.html` | Anchor to the toolbar; show actual connecting, connected, disconnected, and error states |
| Sample data | `dashboard/sample-data.mjs` | Temporary and freely replaceable; it is not an integration contract |

Use native inputs, selects, buttons, and range controls. Keep sample data, rendering, and UI coordination separate. Avoid a new component library, state framework, or schema package for this prototype.

## Do's and Don'ts

- Do preserve the five approved colours and fullscreen map composition.
- Do keep the main page stationary and scroll long content only within modules.
- Do show source status, sample labels, and unassessed data honestly.
- Do make map findings available in a keyboard-accessible list.
- Do look for an existing module before creating or duplicating one.
- Don't bring back the sidebar, marketing heading, or grid of summary cards.
- Don't show a cosmetic 3D toggle that changes only its button state.
- Don't use Canvas2D projection or CSS transforms as the 3D renderer. Use deck.gl for analysis geometry and Three.js for the drone.
- Don't fabricate live connectivity, agronomic measurements, or validated AI results.
