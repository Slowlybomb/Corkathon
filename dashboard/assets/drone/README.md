# Flying drone model

`drone.glb` is a web-ready copy of the model supplied by the project owner at `Downloads/flying-drone-animation/source/Flying drone_.glb`. The original stays unchanged. The supplied directory contained no author, source URL, or reuse licence; these details remain unverified.

- Original: 30,508,908 bytes; SHA-256 `7eae6f63393f5cd74a0ad72b2c3bf8a162358ed3bbece62bf5ad3073f139aa10`.
- Packaged: 5,335,864 bytes; SHA-256 `2cbad1970951f31df59895c92b3fd1cd56f1361000a8a935aafb108649158552`.
- Embedded textures resized to a maximum 1,024 pixels and encoded as WebP. Geometry and skinning retained; duplicate resources removed and animation keyframes resampled.
- Legacy `KHR_materials_pbrSpecularGlossiness` converted to metallic/roughness materials supported by Three.js 0.180.0. No extra runtime decoder is needed.
- All three clips remain in the asset. The map plays only `hover`, driven by survey replay time. `exploded_view` and `step_by_step` are assembly demonstrations and are not played.

The map rotates glTF's Y-up model into the Z-up map scene and centres it at the existing simulated drone position. Its displayed 140-metre span and 100-metre altitude are illustrative, not physical drone dimensions or measured telemetry. Reduced-motion preferences keep the model's hover pose fixed; the user-controlled replay still moves its position. The 2D/globe position dot remains available if the asset cannot load.

To reproduce with glTF Transform 4.2.1 (one-time asset tooling, not an app dependency):

```sh
npx --yes @gltf-transform/cli@4.2.1 dedup 'Flying drone_.glb' /tmp/drone-dedup.glb
npx --yes @gltf-transform/cli@4.2.1 metalrough /tmp/drone-dedup.glb /tmp/drone-metalrough.glb
npx --yes @gltf-transform/cli@4.2.1 optimize /tmp/drone-metalrough.glb drone.glb --compress false --texture-compress webp --texture-size 1024 --flatten false --join false --instance false --simplify false --palette false
```
