# Running the model anywhere: inference specification

This file is what you need to reimplement the trained model in another language (Java on Android, JavaScript, C++). It covers how to read the model file, what to feed it and every step of the forward pass. The Century code is the reference: `src/agri/fast.cy` (`run_chunk`) computes one chunk exactly as described here, and `src/agri/fastrun.cy` drives it and writes test vectors to check a port against.

There is no training here: only matrix and vector arithmetic on float32 arrays.

## 1. The idea: chunks with a margin

The model maps Sentinel-2 bands to 31 output layers per 10 m pixel. Each stage-1 output pixel depends on input pixels up to 24 pixels away (the receptive field, set by the 49 x 49 context mean of section 4.2). So a chunk is computed like this:

- To produce an `n x n` block, feed `S x S` input pixels with `S = n + 2 * MARGIN` and `MARGIN = 24`: the block plus 24 pixels on every side.
- Run the forward pass on the whole `S x S` block.
- Keep the central `n x n` pixels and discard the margin.

With stage 1, chunks computed this way join without seams, in any order, and the same ground pixel gives the same output whichever chunk it falls in. Stage 2 (section 4.9) reaches 48 pixels, so use `MARGIN = 48` there for exact seams; with 24, pixels near a chunk edge can differ from a whole-scene computation. The regional setup (section 6) runs stage 1 only. Results depend only on location and image, so cache every computed chunk.

Layout throughout: arrays are channel-major, `a[c * P + p]`, where `P = S * S` and `p = row * S + col`, with row 0 at the north edge. Everything is little-endian float32 unless noted.

## 2. The model file (`models/agri.bin`)

Read it sequentially (Java: `ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)`). `f32[n]` means n float32 values and `u32[n]` means n uint32 values.

| Field | Type | Meaning |
|---|---|---|
| magic | 4 bytes | ASCII `AGRI` |
| version | u32 | 1 |
| DF | u32 | stage-1 feature count: 301 (293 in older models without edge features) |
| NW | u32 | number of WRB soil groups the model knows |
| NP | u32 | number of conv-bank parameters |
| norm | f32[20] | band means [10] then band standard deviations [10] |
| em | f32[40] | endmember spectra, `em[band * 4 + k]`, k = 0 bare soil, 1 green vegetation, 2 dry vegetation, 3 water |
| wrb_codes | u32[NW] | SoilGrids WRB code for each WRB output index |
| conv | f32[NP] | conv bank, section 4.3 |
| laws | u32[29 * 2 * 4] | law neurons, section 4.4 |
| coefs | f32[29 * 2 * 4] | law coefficients |
| ymu | f32[29] | target means: index 1..24 soil, 25..28 weather (0 unused) |
| ysd | f32[29] | target standard deviations, same indices |
| beta_pixel | f32[DF * 19] | `[feature][output]`: output 0 boundary, 1..18 crop classes |
| beta_soil | f32[DF * (24 + NW)] | `[feature][output]`: 0..23 soil targets, 24.. WRB groups |
| beta_weather | f32[DF * 4] | `[feature][output]`: temperature, humidity, soil moisture, water balance |
| s2 | f32[24 + NW + 4] | held-out residual variances (normalised units), for uncertainty |
| L_soil | f32[DF * DF] | Cholesky factor for soil uncertainty (lower triangle, row-major) |
| L_weather | f32[DF * DF] | the same for weather |
| crop_weights | f32[18] | training only; skip |
| stage2_flag | u32 | 1 if stage 2 follows (absent in stage-1-only files) |
| DF2 | u32 | stage-2 feature count = DF + 66 |
| NP2 | u32 | number of stage-2 conv parameters |
| conv2 | f32[NP2] | stage-2 conv parameters, section 4.9 |
| beta2_pixel, beta2_soil, beta2_weather | f32[DF2 * 19], f32[DF2 * (24 + NW)], f32[DF2 * 4] | stage-2 heads, laid out like stage 1 |

**Regional soil heads.** `models/cork_soil_heads.bin` (f32[DF * 24], 28,896 bytes, no header, `[feature][target]`) replaces columns 0..23 of `beta_soil`, and stage 2 is then skipped. `calibrate.cy` makes it as `out/cork_soil_heads.bin` (section 6).

## 3. Inputs

- `refl[10 * P]`: surface reflectance for these bands, in this order: **B2, B3, B4, B8, B5, B6, B7, B8A, B11, B12**. Reflectance is the digital number divided by 10000. For Sentinel-2 L2A from processing baseline 04.00 on, subtract 1000 first unless the offset was already applied; Earth Search files have it applied. The six 20 m bands are upsampled to 10 m by nearest neighbour: `refl20[(row / 2) * (S / 2) + col / 2]`.
- `doy`: day of year of the image, 1..366.
- A validity mask from the scene classification layer is not used by the model; outputs on cloud (SCL 3, 8, 9, 10), snow (11) or no data (0, 1) should be hidden.

## 4. The forward pass

### 4.1 Base channels `x[21 * P]`

For each pixel, with `r_b` = refl band b (order above: r0 = B2, r1 = B3, r2 = B4, r3 = B8, r4 = B5, r7 = B8A, r8 = B11) and `eps = 1e-6`:

| k | x[k] |
|---|---|
| 0..9 | `(r_k - norm[k]) / norm[10 + k]` |
| 10 | NDVI `(r3 - r2) / (r3 + r2 + eps)` |
| 11 | NDMI `(r7 - r8) / (r7 + r8 + eps)` |
| 12 | NDWI `(r1 - r3) / (r1 + r3 + eps)` |
| 13 | NDRE `(r7 - r4) / (r7 + r4 + eps)` |
| 14 | BSI `((r8 + r2) - (r3 + r0)) / ((r8 + r2) + (r3 + r0) + eps)` |
| 15..18 | unmixing fractions (below) |
| 19 | `sin(2 pi doy / 365.25)` |
| 20 | `cos(2 pi doy / 365.25)` |

**Unmixing.** Compute once from `em`, with `d2 = 100`:

1. `A[i][j] = d2 + sum_b em[b*4+i] * em[b*4+j]` (a 4 x 4 matrix).
2. `Minv = inverse(A)`.
3. `pq[i*10+b] = sum_k Minv[i][k] * em[b*4+k]`.
4. `pq[40+i] = sum_k Minv[i][k] * d2`.

Then per pixel:

1. `a_i = max(0, pq[40+i] + sum_b pq[i*10+b] * r_b)`.
2. `s = sum_i a_i`.
3. `x[15+i] = a_i / s`. If `s <= 0`, the fractions are (1, 0, 0, 0).

### 4.2 Local means

- `bx[21 * P]` = mean of x over a 7 x 7 window (radius 3).
- `cx[21 * P]` = mean of x over a 49 x 49 window (radius 24).

Windows are clipped at the chunk edge: the mean is taken over the part inside the chunk. Compute each as a horizontal pass then a vertical pass, which gives exactly the clipped rectangle mean.

### 4.3 Random convolution bank `f1..f4[48 * P]`

There are four layers, each 3 x 3 with ReLU:

| Layer | Input | Input channels | Dilation |
|---|---|---|---|
| 1 | x | 21 | 1 |
| 2 | f1 | 48 | 2 |
| 3 | f2 | 48 | 4 |
| 4 | f3 | 48 | 8 |

```
f[o][i][j] = max(0, bias[o] + sum_c sum_ky sum_kx w[o][c][ky][kx] * in[c][i + d*(ky-1)][j + d*(kx-1)])
```

Inputs outside the chunk count as 0. In `conv`, each layer is its weights `w[48][Cin][3][3]` (index `((o*Cin + c)*3 + ky)*3 + kx`), then `bias[48]`, layer after layer.

### 4.4 Law neurons `nr[58 * P]`

A grammar term `g(k)` for k = 0..57:

| k | g(k) |
|---|---|
| 0 | 1 |
| 1..21 | `x[k-1]` |
| 22..42 | `bx[k-22]` |
| 43..57 | `x[15] * x[k-43]` (bare-soil fraction times a band or index) |

For target t = 0..28 and layer L = 0, 1, let `o = (t*2 + L)*4`. Then `law(t, L) = coefs[o] + sum_{i < laws[o]} coefs[o+1+i] * g(laws[o+1+i])`, where `laws[o]` is the number of terms (0..3).

- Neuron `2t` is `law(t, 0)`.
- Neuron `2t+1` is `law(t, 0) + law(t, 1)`.

### 4.5 Edge features `mag[4 * P]`, `mx[4 * P]`

- `mag` is the Sobel gradient magnitude `sqrt(gx^2 + gy^2)` of `x[10]`, `x[11]`, `x[3]` and `x[8]` (NDVI, NDMI, NIR, SWIR), with neighbours clamped at the chunk edge.
- `mx` is the 3 x 3 maximum of `mag`.

The kernels are the usual ones, applied to `x[ch]` around (i, j):

```
gx = (p[i-1][j+1] + 2 p[i][j+1] + p[i+1][j+1]) - (p[i-1][j-1] + 2 p[i][j-1] + p[i+1][j-1])
gy = (p[i+1][j-1] + 2 p[i+1][j] + p[i+1][j+1]) - (p[i-1][j-1] + 2 p[i-1][j] + p[i-1][j+1])
```

Models with DF = 293 have no edge features.

### 4.6 Feature vector `phi[DF * P]`

| Channels | Content |
|---|---|
| 0 | 1 |
| 1..21 | x |
| 22..69 | f1 |
| 70..117 | f2 |
| 118..165 | f3 |
| 166..213 | f4 |
| 214..234 | cx |
| 235..292 | nr |
| 293..296 | mag |
| 297..300 | mx |

### 4.7 Heads

Concatenate the three matrices column-wise into `B[DF][MO]` with `MO = 19 + 24 + NW + 4`:

| Columns | Content |
|---|---|
| 0 | boundary |
| 1..18 | crop classes |
| 19..42 | soil targets |
| 43..42+NW | WRB groups |
| 43+NW..46+NW | weather |

Then, per pixel, `s[o] = sum_c phi[c] * B[c][o]`. This is one matrix multiply `[P x DF] * [DF x MO]` and the place to spend optimisation effort.

### 4.8 Outputs `out[31 * P]`

| Channel | Value |
|---|---|
| 0 | field-boundary score `s[0]` |
| 1 | crop class = argmax of `s[1..18]` (0..17, legend in the manifest) |
| 2 | WRB index = argmax of `s[43..42+NW]`; the code is `wrb_codes[index]` |
| 3..26 | soil target `t = c - 3`: `clamp(s[19+t] * ysd[1+t] + ymu[1+t])` |
| 27..30 | weather `k = c - 27`: `clamp(s[43+NW+k] * ysd[25+k] + ymu[25+k])` |

Soil target `t` is property `t / 6` (pH, organic carbon g/kg, clay %, sand %) at depth `t % 6` (0-5, 5-15, 15-30, 30-60, 60-100, 100-200 cm).

The clamps:

| Output | Range |
|---|---|
| pH | 3.5 to 9.5 |
| Organic carbon | 0 to 600 g/kg |
| Clay, sand | 0 to 100 % |
| Temperature | -30 to 45 C |
| Humidity | 0 to 100 % |
| Soil moisture | 0 to 0.7 m3/m3 |
| Water balance | -400 to 400 mm |

### 4.9 Stage 2 (when `stage2_flag` is 1)

1. `maps[9 * P]`: `out[0]`, then the 0-5 cm pH, carbon, clay and sand in normalised units (`(out[3+t] - ymu[1+t]) / ysd[1+t]` for t = 0, 6, 12, 18), then the four weather outputs normalised the same way (`(out[27+k] - ymu[25+k]) / ysd[25+k]`).
2. Two conv layers as in section 4.3: `g1` (9 to 24 channels, dilation 2) and `g2` (24 to 24, dilation 4). In `conv2`, each layer is its weights then 24 biases.
3. `mc[9 * P]` = 49 x 49 clipped mean of maps (as `cx`).
4. `psi[(DF + 66) * P]` = [phi, maps, g1, g2, mc].
5. Repeat sections 4.7 and 4.8 with `beta2_*` over psi. These outputs replace stage 1's.

### 4.10 Keep the interior

Return `out[c][MARGIN + r][MARGIN + col]` for r, col < n.

### 4.11 Derived layers (cheap, optional)

- **Texture class** (USDA) from clay and sand at 0-5 cm: `texture()` in `src/agri/predict.cy` gives the exact rules. The legend is in the manifest.
- **Field zones:**
  1. Take boundary score < threshold as field interior. The threshold is 0.225 on Munich480 (`out/boundary_threshold.txt`); on a new scene use the scene's 85th percentile of the score.
  2. Find connected regions (4-neighbour, 25 pixels or more).
  3. Within each region, take the z-score of NDVI (or any layer): below -0.43 is low, above +0.43 is high, otherwise medium.

## 5. Cost and making it fast on a phone

Multiply-adds per pixel:

| Part | MACs |
|---|---|
| Conv bank | 21·48·9 + 3·48·48·9 = 71,280 |
| Heads | DF · MO = 301 · 51 = 15,351 |
| Stage-2 conv | 9·24·9 + 24·24·9 = 7,128 |
| Stage-2 heads | 367 · 51 = 18,717 |
| Everything else | about 2,000 |

That is about 89k per pixel for stage 1 and 114k for both stages. A 256 x 256 chunk (304 x 304 with the margin) is 8 GMAC (stage 1) or 10.5 GMAC (both).

- **Reference speed:** the Century engine on the RTX 4060 laptop computes a 288 x 288 chunk (stage 1 with the regional heads) in about 90 ms at best and 120 ms on average (0.9 Mpixel/s at best), 8 to 11 chunks per second. The first chunk takes longer while the GPU warms up.
- **On Android:** run the convolutions and heads as GPU compute (Vulkan or OpenGL ES 3.1 compute shaders: one thread per output value, exactly as the kernels in `fast.cy`), or on the CPU with NEON and multiple threads over output channels. Expect roughly 20-80 ms per 256 x 256 chunk on a recent phone GPU, and 0.3-1 s on the CPU. These are estimates from the operation count, not measurements.
- **Order of work:** compute chunks in the camera frustum first, nearest first; cache them (the result never changes for a given image); use 128 x 128 chunks for faster first display. Show coarse layers far away: average 4 x 4 blocks of computed chunks, or precompute a pyramid.
- **Cheapest of all:** precompute a region once (on the laptop or a server) and ship the layers. The scene package in `out/cork/` is exactly that.
- **Float32 is enough.** Summation order changes the last bits only (section 7).

## 6. Regional recalibration

The soil heads can be re-fitted for a new region in closed form, in seconds, from SoilGrids labels: `src/agri/calibrate.cy` (see `README.md`). It writes `out/cork_soil_heads.bin`; the Cork result is shipped as `models/cork_soil_heads.bin`. Apply it as described in section 2. On a phone, ship the recalibrated file; no recalibration needs to run there.

**Weather and crops outside Bavaria.** The weather heads (outputs 27..30) learnt Bavarian seasons and cannot be recalibrated from one date. Outside Bavaria, show observed weather instead, as `scene.cy` does with ERA5-Land values from Open-Meteo for the scene date. The crop classes (output 1) are Munich480's Bavarian classes and do not apply to Irish grassland.

## 7. Checking a port: test vectors

`.\cy src\agri\fastrun.cy --jit main --arg 550720 --arg 5758640 --arg 1 --arg 32 --arg 1` writes one 32 x 32 chunk (S = 80) from the Cork scene of 30 May 2023 (doy 150) to `out/golden/`. `out/` is not in git, so rerun the command to make them:

| File | Content |
|---|---|
| `input_refl.f32` | `refl[10 * 6400]`, the input of section 3 |
| `expected_features.f32` | `phi[DF * 6400]`, the features of section 4.6 |
| `expected_out.f32` | `out[31 * 6400]`, the outputs of section 4.8 |

They use `models/agri.bin` (= `out/model.bin`) with both stages and no regional heads. Feed `input_refl.f32` with doy 150 to the port and compare:

- **features:** absolute difference below 1e-3 at the chunk interior;
- **outputs:** soil and weather within 1e-3 of the value range, and identical classes except near ties.

Differences beyond that point to a step done differently. Compare `expected_features.f32` channel range by channel range (table in section 4.6) to find which one.
