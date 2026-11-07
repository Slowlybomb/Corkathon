# Ithir project scope

Ithir connects field observations, imagery, and inspection actions in one map workspace. The first user is a farmer or field manager deciding where to inspect next.

## Current application

- Fullscreen MapLibre map with satellite imagery, 2D/3D views, a Three.js drone layer, and a deck.gl analysis overlay.
- Observation list, geographic selection, layer filters, inspection suggestions, and JSON export.
- Android phone companion with direct Bluetooth LE connectivity, status, logs, and requested still images.
- Optional WebSocket observation feed. No feed server is included.
- Optional sample survey with six hand-authored observations and a simulated route. The app opens empty.

The survey centre and supplied extent are in [DEMO_AREA.md](DEMO_AREA.md). The extent is not a verified farm boundary. Real parcel sources are recorded in [IRISH_FIELD_DATA.md](IRISH_FIELD_DATA.md).

## Team

| Owner | Responsibility |
| --- | --- |
| AI teammate, working with Claude | Choose the analysis target, prepare the dataset, implement analysis, and document supported findings and limitations |
| Project owner, working with Codex | Web dashboard, phone integration, observation workflow, and overall delivery |
| Third teammate | Proposed: farmer needs, challenge fit, pitch, presentation, and narration; confirm with the team |

AI and dashboard ownership are confirmed. Keep the AI workspace and concurrent work intact. Agent responsibilities are in [AGENTS.md](../AGENTS.md).

## Integration handoff

Agree with the AI owner on example inputs and outputs, available findings, capture timestamps, locations, evidence references, failed or unavailable analysis, and delivery method. Record dataset sources and reuse terms. The current permissive feed adapter is documented in [dashboard/README.md](../dashboard/README.md); it is not an agreed model schema.

Keep visible observations, estimates, measurements, and unassessed properties distinguishable. Received results remain unvalidated. Images alone do not establish soil moisture, nutrients, disease, or soil composition.

## Hardware and demonstration

The hardware concept is a custom 5-inch FPV drone carrying a Realme RMX3363 phone as camera and computing unit. Payload suitability, flight readiness, and airborne processing remain unverified.

The Cork Hackathon deadline is 19:00 on 7 November 2026, Cork local time. Show the physical construction without flying. Use stationary phone capture or the labelled sample survey, and distinguish working capabilities from future plans. Prioritise one repeatable observation-to-inspection workflow.

## Remaining work

- Agree on and connect the model output with the AI owner.
- Attach source evidence, timestamps, and verified locations when available.
- Select actual field parcels before presenting any boundary as a farm.
- Validate findings before making agronomic claims.

Autonomous flight, drone control, continuous video, and validated agronomic diagnosis are outside the current implementation.
