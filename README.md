# Ithir

A field inspection workspace that connects a geographic map, camera module imagery, and observations worth checking on the ground.

## Run

```sh
python3 -m http.server 5173 --directory dashboard
```

Open http://localhost:5173. No installation or build step is required. The map needs internet access and WebGL2. Camera module connectivity requires desktop Chrome on localhost or HTTPS.

The workspace opens empty. Connect a camera module or observation feed, or load the clearly labelled sample survey from **Data source**. The sample contains hand-authored findings and simulated movement; it is not evidence of working AI analysis or a drone flight.

## Project

- [Dashboard](dashboard/README.md): map controls, observations, feed format, and checks.
- [Camera module](docs/PHONE_LINK.md): Android build, Bluetooth pairing, and requested still images.
- `lib/`, `examples/`, `century/`, `data/`: active AI teammate workspace and Century runtime.
- [Design](DESIGN.md): palette, layout, and shared interface conventions.
- [Scope and responsibilities](docs/PROJECT_PLAN.md): current capabilities and integration handoff.

## Check

```sh
node --test dashboard/*.test.mjs
```

AI model integration is pending. Received results remain unvalidated, and field measurements must come from supporting data.
