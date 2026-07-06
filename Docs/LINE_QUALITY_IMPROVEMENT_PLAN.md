# EtchBot Line-Drawing Quality — Code Review & Revision Action Plan

**Date:** 2026-07-06
**Scope reviewed:** Full iOS image-processing pipeline (`ImagePreprocessor` → `EdgeDetector` → `VoronoiStippler`/`VoronoiDiagram` → `TSPSolver` → `PathOptimizer` → `DrawingPathEncoder`) plus firmware execution path (`drawing_executor.cpp`, `motor_controller.cpp`).
**Goal:** Raise the visual quality of the drawn output. This document is structured so independent agents can each own a workstream.

---

## Part 1 — Findings

Findings are ranked by expected visual impact. Category A items are **correctness bugs** that physically distort every drawing today; fixing them is prerequisite to judging any algorithmic improvement.

### Category A — Geometry bugs (visible distortion in every drawing)

#### A1. Backlash compensation corrupts the logical position — zigzag at every direction reversal
`PathOptimizer.optimize`, `PathOptimizer.swift:70-81`.

When an axis reverses, the code injects `backlash` compensation steps **and then advances the logical cursor** (`currentX += signX * backlash`). Compensation steps exist to take up mechanical slack — the pointer does not move during them — so the logical cursor must **not** change. Because it does, the next Bresenham segment is computed from a phantom position.

Worked example (backlash = 60 steps, default): cursor at x=100, target x=90 (a 10-step westward reversal). The code emits 60 steps **west**, sets `currentX = 40`, then Bresenham from 40 → 90 emits 50 steps **east** — a second reversal, which then triggers backlash compensation again on the following segment. Net effect: every direction change produces a ~1.5 mm (60-step) excursion-and-return artifact. With thousands of reversals in a TSP tour, this alone plausibly explains most of the perceived quality gap.

**Fix:** inject the compensation steps but leave `currentX`/`currentY` untouched (all coordinates in the move list are pointer-space; the extra steps are motor-space slack).

#### A2. Backlash is compensated twice — once in the app, once in firmware
`PathOptimizer.swift:69-81` injects compensation into the encoded path. `motor_controller.cpp:55-74` **also** injects backlash steps on every axis reversal during `move()`, with non-zero defaults (`DEFAULT_BACKLASH_H/V`), including for drawing moves streamed from the app. The firmware comment claims it "catches calibration-routine moves that bypass iOS compensation," but it is applied unconditionally, so every reversal in a drawing is compensated twice (after A1 is fixed, this becomes the dominant reversal artifact).

**Fix:** exactly one owner. Recommended: **firmware-only** compensation — it also covers pause/resume, homing, and calibration moves, and keeps the encoded path purely geometric. Remove injection from `PathOptimizer` (keep the calibration values in the app for time estimation only), and have the app push backlash values to the firmware (the BLE calibration write already exists).

#### A3. Aspect-ratio distortion — every image is stretched ~7% vertically
Working canvas is 500×320 (`ImagePreprocessor.swift:27-28`, ratio 1.5625). Physical drawing area is 175×120 mm (`CalibrationData.swift:32-39`, ratio 1.4583). `PathOptimizer.swift:38-39` scales X by 7000/500 = 14 steps/px and Y by 4800/320 = 15 steps/px — non-uniform. Faces come out visibly elongated.

**Fix:** derive the working canvas from the physical aspect ratio (e.g. 500×343 for 175:120), or scale uniformly and letterbox. The canvas size should ultimately come from `CalibrationData`, not a hardcoded constant.

#### A4. Preview does not show what will be drawn
`ImageProcessingViewModel.renderPreviewImage` (`ImageProcessingViewModel.swift:153-186`) normalizes points to their own bounding box and stretches to fill 500×320. The preview therefore has different geometry than the plot (compounding A3), so the user can't judge output quality from the preview.

**Fix:** render the preview with the identical transform used by `PathOptimizer` (same scale, same aspect, no bounding-box normalization).

---

### Category B — Algorithmic quality (the core of "better line drawings")

#### B1. Stray lines across blank areas: points are forced into pure-white regions
Three separate mechanisms put and keep stipple points where the image is empty:
- `VoronoiStippler.rejectionSample` (`VoronoiStippler.swift:137`) accepts any location with ≥ 2% probability (`max(density, 0.02)`), and falls back to **uniform** placement if sampling undershoots (`:145-150`).
- `singleRejectionSample` uses a 5% floor (`:165`).
- `VoronoiDiagram.computeWeightedCentroids` (`VoronoiDiagram.swift:56`) gives every pixel a background weight of 0.01, so cells in white regions never orphan and their points never leave.

Result: dots in blank backgrounds, which the TSP then connects — the classic "scribble wandering across empty space" artifact.

**Fix:**
- Apply a white cutoff in the density map (e.g. density below ~0.08 → 0, smoothstep above), tunable.
- Remove the acceptance floors; if rejection sampling can't place N points, **reduce N** (return fewer points) instead of filling uniformly.
- In Lloyd relaxation, drop orphaned points (shrink the array) rather than re-seeding them randomly. `pointCount` becomes a maximum, not an exact count.

#### B2. Flat tone response; CLAHE is unconditional and amplifies background noise
`ImagePreprocessor.process` always runs CLAHE (`ImagePreprocessor.swift:56`) with clipLimit 3.0. On flat/blank regions CLAHE stretches sensor noise into real density (feeding B1). Density is then a linear inversion of luminance, but perceived tone from stippling is nonlinear in dot spacing — midtones come out muddy.

**Fix:**
- Make CLAHE strength a setting (0 = off); default to a mild value or off.
- Add gamma shaping to the density map (`density = pow(density, γ)`, γ ≈ 1.5–2.0, user-tunable as a "tone" slider) after inversion, before the white cutoff.
- Optionally replace the blunt `contrastMultiplier` (plain multiply, clips highlights) with black/white-point levels.

#### B3. Contour fidelity — the highest-leverage upgrade
Pure stipple-TSP reproduces *tone* but not *edges*: eyes, jawlines, glasses, hairlines dissolve into dot fields. Currently edge blending exists but is **off by default** (`DrawingSettings.swift:36`) and, even when on, only adds density along edges — the tour is still free to cross contours rather than follow them.

Two stages:

- **B3a (cheap, immediate):** default `edgeEmphasisEnabled = true` with weight ≈ 0.35; dilate the Canny map by 1px before blending so edge density survives stippling; expose edge weight as a user slider. Tune Canny thresholds at the working resolution.

- **B3b (the real upgrade): hybrid contour + stipple pipeline.**
  1. Trace the Canny edge map into **polyline chains** (edge linking / 8-connected following), discard chains shorter than a minimum length, simplify with Douglas-Peucker (ε ≈ 0.75 px).
  2. Subtract traced edge density from the tonal density map (so stipples don't double-cover contours).
  3. Stipple the remaining tonal density as today.
  4. Solve a **chained ordering problem**: nodes are stipple points plus contour chains (each chain enterable at either endpoint). Greedy nearest-endpoint construction + 2-opt over the connector edges. Chains are drawn along their polyline; connectors link chain endpoints and stipples.
  5. Output: lines that *follow* image contours, with stippling for shading — this is what visibly separates "recognizable portrait" from "noise cloud."

  This is the largest single quality win and the most work. It should land behind a settings flag (`renderStyle: .stipple | .hybrid`) so the two pipelines can be A/B compared.

#### B4. Angular, jagged path — no smoothing before step conversion
The tour is a polyline through stipple points with hard corners. The plotter can draw smooth curves, so corner-rounding is free quality.

**Fix:** in `PathOptimizer`, before Bresenham decomposition, apply Chaikin corner-cutting (1–2 iterations) or Catmull-Rom sampling with a maximum-deviation clamp (≤ ~0.5 working-px) so tone placement isn't disturbed. Contour chains from B3b should be smoothed with a tighter clamp to stay faithful to the image. Do smoothing in float space, then quantize to steps once (the current per-point rounding at `PathOptimizer.swift:42-48` is fine after smoothing).

#### B5. TSP solver has algorithmic performance defects that cap tour quality
Within a fixed time budget, solver speed *is* solution quality. Two defects burn nearly all of it:

- `twoOptPass` (`TSPSolver.swift:170`) calls `improved.firstIndex(of: candidateIdx)` — an O(n) scan — for each of ~20 candidates for each of n edges: O(n²·k) per pass, up to 50 passes. For n = 3000 this is billions of operations.
  **Fix:** maintain a `position[pointIndex] → tourIndex` array, updated on each segment reversal (O(segment) — already being paid by the reversal itself).
- `orOpt` (`TSPSolver.swift:196-226`) recomputes full `tourLength` — O(n) — for every candidate insertion of every node: **O(n³)** per iteration. For n = 3000 that's ~10¹⁰ distance evaluations; it cannot complete meaningfully.
  **Fix:** O(1) incremental delta cost (removed-edge / inserted-edge arithmetic); restrict insertion candidates to k-nearest neighbors of the moved node; extend to segment lengths 1–3 (standard Or-opt).
- Additional cheap wins: candidate set for 2-opt should include neighbors of `b` (the edge's second endpoint), not only `a`; add don't-look bits; seed nearest-neighbor starts from distinct random points (currently `startIdx` is unused — `TSPSolver.swift:60` draws a fresh random each time, so "multiple starts" may duplicate).

#### B6. The never-drawn tour edge is chosen arbitrarily
`tourLength` optimizes the **closed** tour, but the drawing is an **open** path — one edge is skipped by `breakTourNearHome` (`TSPSolver.swift:245-259`), chosen only by proximity to home. The tour's single longest, ugliest edge often still gets drawn.

**Fix:** break the tour at its **longest edge** (optionally weighted toward home proximity for start/end convenience). Zero algorithmic cost, removes the worst line in most drawings.

---

### Category C — Resolution & performance headroom (P2)

- **C1.** Run Canny at 2× working resolution and downsample the edge map — 500 px wide loses fine facial features. Replace the scalar Gaussian/Sobel loops with `vImage`/`vDSP` equivalents (`EdgeDetector.swift:51-125`) to pay for it.
- **C2.** `VoronoiDiagram.computeWeightedCentroids` does a KD-tree query per pixel (160k queries × up to 40 iterations). A jump-flood or region-growing (multi-source BFS) assignment is ~10× faster, buying either more relaxation iterations or higher canvas resolution in the same budget.
- **C3.** Once B5/C2 land, raise `pointCountRange` upper bound (6000 → 10000) and consider an adaptive default derived from the image's tonal coverage.
- **C4.** Firmware is already on `MICROSTEP` and interleaves X/Y on diagonals — no firmware quality work needed beyond the A2 ownership decision. (Note: `Adafruit_StepperMotor::step()` over I2C is blocking and slow; if drawings feel too slow after quality fixes, that's a separate latency workstream — out of scope here.)

---

## Part 2 — Revision Action Plan (agent workstreams)

### Sequencing

```
WS0 (harness) ──┬── WS1 (geometry fixes A1–A4)      [parallel, no deps]
                ├── WS2 (density/stippling B1,B2)    [parallel, no deps]
                ├── WS3 (TSP engine B5,B6)           [parallel, no deps]
                └── WS4a (edge defaults B3a)         [parallel, no deps]
WS4b (hybrid contour pipeline B3b) ── after WS3 (needs chained-TSP hooks) 
WS5 (smoothing B4) ── after WS1 (correct geometry) and WS4b (chain-aware)
WS6 (perf/resolution C1–C3) ── after WS0 metrics exist; anytime
```

WS0–WS4a are fully independent: five agents can start simultaneously. Each workstream must keep `swift build && swift test` green (SPM package `EtchBotCore` builds on macOS/Linux; UIKit-dependent files are excluded).

---

### WS0 — Verification harness & quality metrics *(do first or parallel; everything else proves itself against this)*

**Owner:** 1 agent. **Size:** M.

| Task | Detail |
|---|---|
| WS0.1 | Add `EtchBotTests/ImageProcessingTests/PipelineQualityTests.swift` plus 3–4 fixture inputs. Since `UIImage` isn't available in SPM, add fixtures as **synthetic `DensityMap`s** generated in code (portrait-like gradient + sharp shapes, high-contrast silhouette, busy texture, mostly-blank image with small subject). |
| WS0.2 | Implement a `PlotSimulator` test utility: replays a `DrawingPath` move list into a step-space polyline, **including a backlash model** (first N steps after axis reversal don't move the pen). This is what catches A1/A2 regressions forever. |
| WS0.3 | Metrics computed per fixture and asserted/reported: open-path tour length; count of reversal artifacts (pen excursions > 20 steps that immediately return); % of stipple points in zero-density regions (B1); X/Y scale ratio of output vs. source (A3, must be 1.0 ± 0.5%); edge-coverage score (fraction of Canny pixels within r of the drawn path — improves with B3). |
| WS0.4 | Golden snapshot: rasterize simulator output to PGM/PNG bytes written to a temp dir on test run for human review (not asserted). |

**Acceptance:** `swift test` runs the suite; metrics print a per-fixture table; simulator demonstrates the A1 zigzag on current `main` (regression proof).

---

### WS1 — Geometry correctness (A1, A2, A3, A4)

**Owner:** 1 agent. **Size:** S–M. **Highest certainty, do not defer.**

| Task | Files | Change | Acceptance |
|---|---|---|---|
| WS1.1 (A1) | `PathOptimizer.swift:69-81` | Inject backlash steps **without** mutating `currentX`/`currentY`. | Simulator (WS0.2) with backlash model shows zero excursion artifacts; unit test: reversal segment produces exactly `backlash + distance` steps in one direction. |
| WS1.2 (A2) | `PathOptimizer.swift`, `Docs/` | Remove app-side backlash injection entirely; firmware becomes sole owner (it already receives values via BLE calibration write). Document the ownership decision in `BUILD_PLAN.md`. Keep `CalibrationData` backlash fields (used for firmware sync + time estimates). | Encoded path for a reversal-heavy tour contains no compensation runs; firmware behavior unchanged. |
| WS1.3 (A3) | `ImagePreprocessor.swift:27-28`, `PathOptimizer.swift`, callers | Make the working canvas match physical aspect: keep width 500, set height = `round(500 * 120/175)` = 343. Thread width/height through instead of hardcoding (grep for `500`/`320` in Views too — `EtchASketchFrame`, preview code). | WS0.3 aspect metric = 1.0 ± 0.5%; all tests updated. |
| WS1.4 (A4) | `ImageProcessingViewModel.swift:153-186` | Preview renders with the same uniform transform as the plot (no bounding-box stretch); canvas uses the corrected aspect. | Visual: preview aspect equals plot aspect; add a unit-testable pure function for the transform. |

---

### WS2 — Density map & stippling quality (B1, B2)

**Owner:** 1 agent. **Size:** M.

| Task | Files | Change | Acceptance |
|---|---|---|---|
| WS2.1 (B1) | `VoronoiStippler.swift:137,145-150,165`, `VoronoiDiagram.swift:56` | Remove acceptance floors and uniform fill; white cutoff (smoothstep, threshold setting default ≈ 0.08); orphaned Lloyd cells are **dropped**, not re-seeded; `pointCount` becomes an upper bound. | WS0.3 "points in zero-density regions" metric = 0 on the mostly-blank fixture; downstream handles variable point counts. |
| WS2.2 (B2) | `ImagePreprocessor.swift:50-77`, `DrawingSettings.swift` | Add `toneGamma` setting (default 1.8) applied to density post-inversion; add `claheStrength` setting (0…1, default mild ~0.3, 0 = skip) — interpolate CLAHE output with input; keep `contrastMultiplier` but apply as levels (black/white point) rather than plain multiply-and-clip. | Unit tests on synthetic ramps: gamma monotonic, CLAHE off at 0; blank fixture produces near-zero density everywhere. |
| WS2.3 | `DrawingSettings.swift`, `Views/Editor/*` | Surface new settings: tone slider, background-cutoff slider (advanced), CLAHE strength (advanced). Keep `DrawingSettings` `Codable`-compatible (new fields with defaults via custom `init(from:)` or optionals). | Settings round-trip encode/decode test passes with old saved payloads. |

---

### WS3 — TSP engine (B5, B6)

**Owner:** 1 agent. **Size:** M–L. Pure Swift, fully unit-testable, no UI.

| Task | Files | Change | Acceptance |
|---|---|---|---|
| WS3.1 | `TSPSolver.swift:153-192` | Position-lookup array (`position[pointIdx] = tourIdx`) maintained across reversals; eliminate `firstIndex(of:)`. | 2-opt pass on n=3000 completes in < 100 ms in a measured test; tour length ≤ current implementation's on same seed. |
| WS3.2 | `TSPSolver.swift:196-226` | Or-opt with O(1) delta costs, segment lengths 1–3, insertion candidates restricted to k-nearest neighbors, don't-look bits. | Full solve (NN + 2-opt + Or-opt) for n=3000 < 3 s in a measured test; open-path length improves ≥ 5% vs. baseline on WS0 fixtures (record baseline first). |
| WS3.3 | `TSPSolver.swift:59-61` | Fix multiple-start seeding (use distinct start indices; `startIdx` is currently ignored). Seed the RNG per solve for reproducible tests. | Deterministic test with injected seed. |
| WS3.4 (B6) | `TSPSolver.swift:230-259` | Optimize the **open** path: `breakTour` drops the longest edge (tie-break toward home proximity); `tourLength` metric for reporting excludes the dropped edge. | WS0 metric: longest drawn edge decreases on all fixtures. |
| WS3.5 | `TSPSolver.swift` | Add the segment-ordering entry point WS4b needs: solve over nodes that are either points or **chains with two endpoints** (chain traversal cost fixed; connector edges optimized; chains reversible). Design the API now (`solve(elements: [TourElement])`), implement greedy + 2-opt over connectors. | Unit tests with hand-built chain sets; used by WS4b. |

---

### WS4 — Contours (B3a then B3b)

**Owner:** 1 agent (B3a is a half-day; B3b is the big one). **Size:** L. **WS4b depends on WS3.5.**

| Task | Files | Change | Acceptance |
|---|---|---|---|
| WS4a.1 | `DrawingSettings.swift`, `ImagePreprocessor.swift:63-74`, editor Views | `edgeEmphasisEnabled` default true, `edgeWeight` default 0.35, expose as slider; dilate Canny map 1 px before blending; tune Canny thresholds against WS0 fixtures. | Edge-coverage metric (WS0.3) improves on portrait fixture with no increase in blank-region points. |
| WS4b.1 | new `Services/ImageProcessing/ContourTracer.swift` | Trace Canny output into 8-connected polyline chains; junction handling (split at branch points); discard chains < min length (setting, default ≈ 10 px); Douglas-Peucker simplification (ε = 0.75 px). | Unit tests: synthetic edge maps (circle, square, T-junction) produce expected chain counts/topology. |
| WS4b.2 | `ImagePreprocessor.swift` | Hybrid density: subtract traced-chain coverage from the tonal density map before stippling (so dots don't double-draw contours). | Stipple count near chains drops measurably on fixtures. |
| WS4b.3 | `ImageProcessingViewModel.swift`, `TSPSolver` (WS3.5 API), `PathOptimizer.swift` | New `renderStyle` setting: `.stipple` (current) / `.hybrid`. Hybrid path: chains + stipples → chained ordering (WS3.5) → concatenated polyline → PathOptimizer. | Both styles selectable; hybrid improves edge-coverage metric ≥ 2× on portrait fixture; end-to-end simulator output reviewed via WS0.4 snapshots. |
| WS4b.4 | editor Views | Style toggle in the editor UI; preview renders chains + connectors distinguishably during development (debug overlay). | Manual review. |

---

### WS5 — Path smoothing (B4) — after WS1 and WS4b

**Owner:** 1 agent. **Size:** S–M.

| Task | Files | Change | Acceptance |
|---|---|---|---|
| WS5.1 | `PathOptimizer.swift` (pre-Bresenham) | Chaikin corner-cutting (1–2 iterations) with max-deviation clamp (≤ 0.5 working-px for stipple connectors; ≤ 0.25 px for contour chains). Operate in float space; quantize to steps once at the end. | Simulator polyline curvature histogram shows corner reduction; tour tone metrics unchanged within tolerance; move count growth < 30%. |
| WS5.2 | `DrawingPathEncoder.swift`, `PathOptimizer.swift:151-159` | Verify the 65 535-move ceiling still holds with smoothing + higher point counts; if not, raise header move-count field to uint32 (bump protocol magic to 0xEB 0x02) **coordinated with firmware `path_storage`/`drawing_executor` decode** — flag to the user before changing the BLE protocol. | Encoder round-trip tests; explicit overflow test. |

---

### WS6 — Resolution & performance (C1–C3) — optional, after WS0

| Task | Change |
|---|---|
| WS6.1 | Canny at 2× resolution, downsample edge map; vImage convolution for blur/Sobel. |
| WS6.2 | Replace per-pixel KD queries in `VoronoiDiagram` with jump-flood assignment; re-tune iteration count. |
| WS6.3 | Raise point-count ceiling; adaptive default = f(tonal coverage). Update `estimatedDrawTimeMinutes` from actual encoded step counts instead of the 0.8 s/point heuristic. |

---

## Part 3 — Verification strategy

1. **Every workstream** runs `swift build && swift test` (SPM, `EtchBotCore`) before pushing.
2. **WS0 metrics table** is the shared scoreboard: each workstream records before/after values in its PR description for the four fixtures.
3. **Human review loop:** WS0.4 snapshot PGMs per fixture per branch — Jim reviews side-by-side; algorithm aesthetics can't be fully asserted numerically.
4. **Hardware validation (Jim, after merge):** one physical test drawing per milestone — (1) after WS1 (reversal artifacts gone, aspect correct), (2) after WS2+WS3 (clean backgrounds, tighter tour), (3) after WS4b (contour-following lines).

## Part 4 — Decisions & open questions

**Decided (Jim, 2026-07-06):**

1. **Backlash ownership (WS1.2): firmware is the sole owner.** The app never injects compensation into the encoded path; it only syncs calibration values to the device via the BLE calibration write. *(Implemented.)*
2. **The 60-step backlash defaults are placeholders**, not measured values. Real values come from the calibration wizard on hardware; doc comments updated to say so.

**Still open:**

3. **Draw-time budget:** smoothing (WS5) and higher point counts (WS6.3) increase step counts and therefore drawing time. Is there a target ceiling (e.g. ≤ 10 min) that should constrain defaults?
4. **BLE protocol change (WS5.2):** acceptable to bump the binary protocol version if the move-count ceiling needs raising? Requires reflashing firmware.

## Part 5 — Status log

- **2026-07-06 — WS6 complete** (this branch; WS5 path smoothing deferred until hardware testing):
  - WS6.1: Canny now runs at 2× working resolution and the edge map is max-pooled back down (thin edges survive; fine detail like eyes/hair is caught). Blur is vDSP_f5x5, Sobel is vDSP_f3x3 ×2, magnitude via vDSP_vdist; convolution border artifacts suppressed within 3 px. Also fixed `resizedImage` to force renderer scale 1 — the default format renders at device display scale, which would size every derived pixel buffer 2–3× the working resolution.
  - WS6.2: `VoronoiDiagram` assignment rewritten from per-pixel KD-tree queries to jump flooding (ping-pong JFA + a final step-1 pass), with nearest-free-pixel seeding so near-coincident sites aren't dropped. Equivalence vs. brute force asserted in tests (≥99% exact, all within 0.75 px).
  - WS6.3: point-count ceiling raised to 10 000 (safe: run-length-merged move counts stay well under the 65 535 protocol limit); point count auto-tunes per photo from mean density (√coverage scaling, 800–6000), with a `lastProcessedSettings` guard so the programmatic settings change doesn't trigger a redundant reprocess; draw-time estimate now computed from the actual encoded moves at the calibrated RPM with diagonal runs costed 2×, shown in the editor instead of the 0.8 s/point heuristic.
  - Same toolchain caveat: authored without local Swift — **run `swift test` on macOS/Xcode before merging.**

- **2026-07-06 — WS2 complete** (this branch):
  - WS2.1: rejection sampling is now strictly density-proportional (no 2% acceptance floor, no uniform fallback — `pointCount` is an upper bound); orphaned Lloyd cells are dropped instead of re-seeded; the Voronoi background weight (0.01) is removed so blank pixels contribute nothing. `PipelineQualityTests` now ASSERTS ≤1% of points in blank regions (was report-only).
  - WS2.2: new `ToneShaper` (platform-independent, unit-tested): contrast as a mid-gray-pivoted stretch (the old multiply just brightened everything), `toneGamma` (default 1.8) for midtone/shadow separation, smoothstep `backgroundCutoff` (default 0.08); CLAHE now has a strength setting (default 0.3, 0 = off) blended with the input instead of always applying at full strength.
  - WS2.3: editor UI gains a Shading Depth (gamma) slider and an Advanced section with CLAHE strength and Background Cutoff sliders; ViewModel gracefully reports "no drawable content" instead of erroring when a blank image yields <2 points.
  - Same toolchain caveat: authored without local Swift — **run `swift test` on macOS/Xcode before merging.**

- **2026-07-06 — WS3 complete, WS4a complete, WS4b complete** (this branch):
  - WS3.1/3.2: `TSPSolver` rewritten — precomputed k-nearest candidate lists, O(1) tour-position lookup in 2-opt (no more `firstIndex` scans), Or-opt relocation of 1–3-node segments (forward/reversed) with O(1) cost deltas.
  - WS3.3: multiple NN starts now use distinct seeded starting points (`startIdx` was previously drawn and ignored); `solve(seed:)` gives reproducible tours for tests.
  - WS3.4: `breakTourAtLongestEdge` drops the tour's worst edge instead of an arbitrary one; ViewModel switched to it.
  - WS3.5: new `ChainedTourSolver` — orders mixed chains+points with greedy nearest-endpoint construction plus orientation-aware 2-opt over connectors.
  - WS4a: edge emphasis on by default (weight 0.35, slider exposed), Canny map dilated 1px before blending; blend applies to the stipple style only.
  - WS4b: hybrid contour+stipple pipeline — new `ContourTracer` (crossing-number junction detection, open-chain + loop tracing, Douglas-Peucker simplification), chain coverage subtracted from the density map before stippling, `renderStyle` setting (`.hybrid` default / `.stipple`), editor style picker, ViewModel integration.
  - Tests: `ContourTracerTests`, `ChainedTourSolverTests`, TSP determinism/permutation/longest-edge tests; settings-defaults test updated.
  - Same toolchain caveat as WS1: authored without local Swift — **run `swift test` on macOS/Xcode before merging.**

- **2026-07-06 — WS1 complete, WS0 complete** (this branch):
  - WS1.1/1.2: app-side backlash injection removed from `PathOptimizer`; firmware is sole owner. Firmware slack take-up steps no longer counted into `_posX/_posY` pen telemetry (`motor_controller.cpp`).
  - WS1.3: working canvas corrected to 500×343 (matches 175:120 physical aspect); constants moved to platform-independent `WorkingCanvas` in `Utilities/Extensions.swift`.
  - WS1.4: preview renders with the plotter's uniform transform (no bounding-box stretch).
  - WS0: `PlotSimulator` (lash-model trajectory replay), synthetic `DensityFixtures`, and `PipelineQualityTests` (geometric-path invariants asserted; WS2/WS3 baseline metrics reported, not yet asserted).
  - Note: changes were authored in a Linux container without a Swift toolchain (network policy blocks swift.org) — **run `swift test` on macOS/Xcode to verify before merging.**
