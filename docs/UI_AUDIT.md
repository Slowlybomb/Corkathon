# Dashboard UI audit — 7 November 2026

Scope: current dashboard source and saved desktop/mobile captures from 13:34–13:35. The local preview server could not bind a port in this sandbox, so this is not a fresh interactive browser or physical-device test. No UI changes were made. Findings distinguish source-confirmed behaviour from capture evidence.

## Implementation integrity verdict

The visual system is coherent: a fullscreen geographic workspace, shared floating modules, the approved palette, and real MapLibre/deck.gl/Three.js rendering. Preserve that foundation. Data-state feedback needs work before the demonstration: empty batches retain old findings, missing heatmaps have hidden explanations, and observations have no visible freshness information.

## Provisional health score

These are implementation-review scores, not WCAG certification or performance benchmarks. Keyboard traversal, touch gestures, text zoom, loading transitions, and frame timing still need a live browser check.

| Dimension | Score | Evidence |
| --- | --- | --- |
| Accessibility | 2/4 | Named controls, native inputs and focus styles exist; functional text is often 8–10 px and several controls are small. |
| Performance | 3/4 | Bounded feed input, lazy drone asset, and replay work gated by playback; no frame-time measurements were available. |
| Responsive design | 2/4 | Breakpoints and bounded panels exist; saved mobile capture shows attribution/control overlap and lost survey context. |
| Theming | 3/4 | Approved palette and surface tokens are present; several repeated literals remain. |
| Implementation integrity | 2/4 | Product-specific composition is strong; displayed states do not consistently explain the underlying data. |
| **Total** | **12/20** | **Acceptable; significant targeted work remains.** |

Seven issues: zero P0, one P1, six P2. Fix data-state feedback first, mobile layout next, and typography last. No redesign or new component library is needed.

## Findings

### 1. P1 — An empty result cannot clear previous findings

- **Location:** `dashboard/app.mjs:144–149,177`; `dashboard/geo.mjs:33–36`.
- **Category:** Implementation integrity.
- **Evidence:** `normaliseFeed({observations: []})` returns an empty array, and `receiveObservations` immediately returns false. Existing findings and heatmap remain. The WebSocket status calls this “no usable geographic or sample-grid positions,” even for an explicitly empty batch.
- **Impact:** Once results are displayed, a replacement batch with no findings cannot represent that outcome. Users may inspect outdated problems as though they remain in the latest result.
- **Recommendation:** Agree whether messages replace a snapshot or append events. Distinguish a valid empty snapshot from invalid input, and show a clear empty/latest-result state when appropriate. Keep malformed-input retention explicit.
- **Suggested command:** `$impeccable harden`.

### 2. P2 — Missing heatmap explanations are hidden

- **Location:** `dashboard/app.mjs:45–57`; `dashboard/analysis.mjs:15,35–38`; `dashboard/index.html:78`.
- **Category:** Implementation integrity / UX clarity.
- **Evidence:** Mixed metrics correctly produce no cells and the note “Choose a layer with one metric and unit before comparing values.” Observations without numeric values produce “No numeric assessment available.” Both notes are written inside `.legend`, which is hidden whenever there are no cells. A Node check confirmed the mixed-metric result.
- **Impact:** Users see findings but no heatmap and cannot tell whether data is missing, the chosen filter is unsuitable, or rendering failed.
- **Recommendation:** Keep an analysis-status message visible when observations exist. Hide the scale and sliders independently; explain how to reveal a supported layer.
- **Suggested command:** `$impeccable clarify`.

### 3. P2 — Mobile attribution overlaps map controls

- **Location:** `dashboard/style.css:28,40–44,54–57`.
- **Category:** Responsive design.
- **Evidence:** The saved 390 px-wide `ithir-mobile.png` shows expanded attribution occupying the same bottom-right area as zoom/fit controls and the source footer. The small-screen rule anchors attribution at bottom 6 px, while controls occupy bottom 48 px when replay is absent.
- **Impact:** Attribution text is obscured and the bottom of the map feels crowded. An expanded attribution state has no reserved space.
- **Recommendation:** Give attribution, map controls, and source credit separate positions in both replay states. Preserve provider credit and make expanded attribution usable.
- **Suggested command:** `$impeccable adapt`.

### 4. P2 — Small screens remove the survey identity and starting action

- **Location:** `dashboard/style.css:75`; `dashboard/app.mjs:26–27,128–130`; `dashboard/index.html:28`.
- **Category:** Responsive design / UX clarity.
- **Evidence:** Below 520 px, `.field-context` is hidden, removing both the area name and survey context. On narrow screens the observations panel also starts collapsed, hiding the explanatory empty state and “Connect a source” action. Both are visible in the saved mobile capture.
- **Impact:** The initial mobile view has no field identity or explanation of why it is empty. The user must infer which toolbar action starts the workflow. Sample/live context becomes less prominent after loading data too.
- **Recommendation:** Retain a compact area/source label and make the initial connect or sample action visible without expanding an empty panel. Reuse existing toolbar/disclosure modules.
- **Suggested command:** `$impeccable onboard`.

### 5. P2 — “Columns” can remain selected while the map is flat

- **Location:** `dashboard/app.mjs:69–74,122–124`; `dashboard/analysis-layer.mjs:18–24`.
- **Category:** Implementation integrity.
- **Evidence:** Choose Columns, then 2D. The renderer sets `raised=false` because the map view is 2D, but the Columns button keeps its active class and `aria-pressed=true`. Height becomes disabled without explaining the effective display change.
- **Impact:** The selected control and the rendered result describe different display states.
- **Recommendation:** Synchronize the effective analysis mode with map view, or clearly explain that column height is available in 3D and preserve it as an explicit preference. Update visual and accessible states together.
- **Suggested command:** `$impeccable harden`.

### 6. P2 — Functional text and secondary controls are too small

- **Location:** `dashboard/style.css:19–24,28,61,69–71`.
- **Category:** Accessibility / responsive design.
- **Evidence:** Finding metadata, evidence status, legend notes and replay labels use 8–10 px text. Disclosure/export buttons are 28×28 px; cell navigation is 29×29 px; mobile zoom controls are 30×33 px. The automated scan confirms repeated small-text declarations, and the saved sample capture shows the resulting density.
- **Impact:** Evidence qualifiers and units are harder to read during a projected demo or on a phone. Small targets make adjacent actions less forgiving under touch.
- **Standard:** These pixel sizes alone do not prove a WCAG AA failure. A live text-zoom, spacing and target-size assessment remains necessary.
- **Recommendation:** Raise important metadata toward 12–13 px and enlarge touch hit areas toward 44 px, preserving compact visible icons. Reduce secondary copy and use existing disclosure behaviour to make room.
- **Suggested command:** `$impeccable typeset`, followed by `$impeccable adapt`.

### 7. P2 — Retained observations have no visible freshness

- **Location:** `dashboard/geo.mjs:42–46`; `dashboard/app.mjs:23,39–42,143,155–156,181`.
- **Category:** Implementation integrity / UX clarity.
- **Evidence:** Incoming capture timestamps are not retained by the feed adapter. Live rows show only “Received · unvalidated.” Disconnect changes the toolbar/settings status and retains observations, but the observation module has no last-update time or stale badge. A Node check confirmed that an input `timestamp` is omitted from the normalized result.
- **Impact:** Users can recognize a disconnected link but cannot assess the age of the evidence still on the map. An open connection that stops delivering data also looks current indefinitely.
- **Recommendation:** Preserve agreed capture timestamps where supplied, record receipt time separately, and show last update plus retained/stale state beside observations. Do not substitute receipt time for capture time.
- **Suggested command:** `$impeccable harden`.

## Detector findings and false positives

The bundled detector ran through `sh` and returned 23 warnings/advisories: 10 undersized-functional-text reports, 8 tiny-text reports, 1 missing-image warning, 1 palette advisory and 3 radius advisories. These are not 23 separate user-facing defects; some refer to hidden or repeated elements.

- **Verified:** repeated 8–10 px functional text is a real pattern, grouped as finding 6.
- **False positive:** the camera `<img>` initially lacks `src`, but its figure is hidden. `phone-panel.mjs:43` assigns the captured image before revealing it. There is no initial broken-image box.
- **Advisory only:** the map fallback background `#243d2a` is outside the declared palette. This is a minor token consistency point, not a demonstrated readability defect.
- **Not counted:** 5/8/10 px radius advisories. DESIGN.md allows smaller rounded controls without specifying an exhaustive radius scale; these warnings do not establish inconsistency.

## Patterns and strengths

The main pattern is that visibility decisions hide useful state information along with unavailable controls. Connection state, analysis availability, and result freshness should remain understandable across map modes, screen sizes and empty results.

Keep the fullscreen map and shared floating surfaces. Native inputs, explicit button names, focus indicators, escaped received text, keyboard-accessible finding lists, sample/unvalidated labels, reduced-motion handling, and bounded panel scrolling are good foundations. Real 3D rendering already matches the requested direction.

## Recommended order

1. `$impeccable harden`: empty results, freshness, and synchronized display states.
2. `$impeccable clarify`: explain unavailable heatmaps.
3. `$impeccable adapt`: separate mobile attribution/controls and retain survey context.
4. `$impeccable onboard`: expose the initial connection/sample workflow.
5. `$impeccable typeset`: make evidence text readable and adjust control spacing.
6. `$impeccable polish`: review alignment and density after the functional changes.

Recheck desktop and mobile empty/sample/live/disconnected states, mixed metrics, 2D/3D transitions, expanded attribution, keyboard navigation, text zoom and synthesized touch. Re-run `$impeccable audit` after fixes.
