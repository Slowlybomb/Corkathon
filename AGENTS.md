# Corkathon: team and agent responsibilities

## Project context

- Cork Hackathon project inspired by OneSoil: field observations and analysis in a map-based dashboard.
- Deadline: 19:00 on 7 November 2026, Cork local time.
- Hardware concept: a custom 5-inch FPV drone carrying a Realme RMX3363 phone as camera and computing unit.
- The hackathon demonstration shows the construction without flying. Clearly label recorded data, simulated movement, and illustrative map positions.
- See [the project plan](docs/PROJECT_PLAN.md) for the product scope and demo story.

## Responsibilities

| Owner | Responsibility | Expected handoff |
| --- | --- | --- |
| AI teammate, working with Claude | Own the AI and analysis work, choose the initial analysis target, find and prepare the dataset, and assess what the results support | Example inputs and outputs, dataset source and reuse terms, supported findings, and known limitations |
| Project owner, working with Codex | Own the web app and computer dashboard: layout, map, survey replay, observation views, and integration of AI results | A usable dashboard that connects position, evidence, analysis results, and inspection actions |
| Third teammate, with strong social skills | Proposed focus: farmer needs, challenge fit, pitch, presentation materials, and demo narration | A clear user problem, presentation, and rehearsed demo story; confirm this assignment with the team |

The AI and dashboard assignments are confirmed by the project owner. The third teammate's assignment is proposed. The project owner also coordinates overall scope and the final demonstration.

## Collaboration

- Read [DESIGN.md](DESIGN.md) before changing dashboard UI. It records the user's fixed palette, fullscreen map, floating modules, 2D/3D views, and no-page-scroll requirement. It supersedes conflicting earlier visual proposals.
- Before creating a UI module, inspect the existing renderer, replay/filter helpers, floating-panel styles, disclosure behaviour, and buttons. Reuse or extend these first.
- The user selected deck.gl for the field heatmap. Reuse `analysis.mjs` for value preparation and `analysis-layer.mjs` for the shared MapLibre overlay. Three.js remains responsible for the drone model. Keep model input adaptation flexible; show no synthetic heatmap for live observations without numeric values.
- The user selected MapLibre + Three.js. Use the real WebGL custom layer, not Canvas2D projection. The demo centre is latitude 51.949961, longitude -8.220098; preserve the supplied extent in `dashboard/geo.mjs` and `docs/DEMO_AREA.md`. Keep the approved palette and floating fullscreen-map layout.

- Codex should focus implementation on the web app and dashboard. Claude's AI work is owned by the AI teammate; coordinate changes across these areas with their owner.
- Preserve concurrent work by other teammates and agents. Do not overwrite or revert their changes to make the workspace match an earlier state.
- Before integrating AI results, agree on an example result format, available findings, timestamps, location information if available, and how unavailable or failed analysis is represented. Agree on the delivery method during technical planning.
- Dashboard development can use clearly labelled example results while AI work proceeds. Example results do not establish that automated analysis works.
- Keep observations, estimates, measurements, and unassessed properties distinguishable. Do not invent soil measurements or accuracy claims.
- Prioritise one complete, repeatable demonstration before optional features.
