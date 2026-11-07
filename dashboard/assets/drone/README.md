# Flying drone model

`drone.glb` is a web-ready copy of the model supplied by the project owner at `Downloads/flying-drone-animation/source/Flying drone_.glb`. The original stays unchanged. The supplied directory contained no author, source URL, or reuse licence; these details remain unverified.

- Original: 30,508,908 bytes; SHA-256 `7eae6f63393f5cd74a0ad72b2c3bf8a162358ed3bbece62bf5ad3073f139aa10`.
- Packaged: 5,335,864 bytes; SHA-256 `2cbad1970951f31df59895c92b3fd1cd56f1361000a8a935aafb108649158552`.
- Embedded textures resized to a maximum 1,024 pixels and encoded as WebP. Geometry and skinning retained; duplicate resources removed and animation keyframes resampled.
- Legacy `KHR_materials_pbrSpecularGlossiness` converted to metallic/roughness materials supported by Three.js 0.180.0. No extra runtime decoder is needed.
- All three clips remain in the asset. The loader evaluates `hover` at time zero to retain the assembled model, with no animated rotor motion. `exploded_view` and `step_by_step` are not played.

The loader rotates glTF's Y-up model into the Z-up map scene. Its displayed 140-metre span is exaggerated for visibility, not a physical dimension. Geographic placement requires fresh phone GPS; pose requires fresh attitude readings. No simulated route, replay heading, or fixed demo altitude is used. The 2D/globe position dot remains available if the model cannot load.

For live phone data, `drone-model.mjs` prepares the same upright, assembled model for the map and the separate attitude view. `telemetry.mjs` constructs its pose from the phone's reported heading, pitch, and roll; zero pitch/roll keeps the body level at every heading. The top edge of a screen-up phone is forward. The hover clip stays at its assembled initial pose; it adds no motion to telemetry. Live map placement uses phone GPS and its optional WGS84 altitude without a fixed demo height. The attitude preview is centred without a geographic position, so it can show orientation while GPS is still acquiring.

To reproduce with glTF Transform 4.2.1 (one-time asset tooling, not an app dependency):

```sh
npx --yes @gltf-transform/cli@4.2.1 dedup 'Flying drone_.glb' /tmp/drone-dedup.glb
npx --yes @gltf-transform/cli@4.2.1 metalrough /tmp/drone-dedup.glb /tmp/drone-metalrough.glb
npx --yes @gltf-transform/cli@4.2.1 optimize /tmp/drone-metalrough.glb drone.glb --compress false --texture-compress webp --texture-size 1024 --flatten false --join false --instance false --simplify false --palette false
```
