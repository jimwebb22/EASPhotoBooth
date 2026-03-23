# EtchBot Drawing Quality Improvement Plan

## Problem Statement

At the current defaults (2,500 points, contrast 1.0, edge emphasis off), the TSP art
output does not recognizably resemble the source photograph. Even with the user manually
cranking points to 5,000+, contrast to 2.0, and enabling edge emphasis, the results are
still far from photo-recognizable. The line drawing appears as random scribbles rather
than coherent shapes from the photograph.

Looking at the leaf photo vs. the EtchBot output, the key gaps are:
1. **Insufficient point density** — 2,500–6,000 points across a 500×320 working area
   gives roughly 1 dot per 25–64 pixels. Tonal gradients cannot be rendered.
2. **Weak edge preservation** — edges are optionally blended at 30% weight, meaning
   structural contours (leaf outlines, veins) compete with tonal fill.
3. **Low working resolution** — 500×320 pixels loses fine detail before stippling begins.
4. **TSP solver time pressure** — 10-second cap on 2-opt means the tour is poorly
   optimized at higher point counts, creating long cross-image jumps that waste line
   and obscure the image.
5. **Buffer constraints** — 50KB firmware buffer limits the number of move commands.

---

## Research: What Works in Similar Projects

### TSP Art (Robert Bosch, Craig Kaplan)
- **Academic standard**: Robert Bosch's TSP art uses **10,000–100,000** stipple points
  for recognizable portraits. His Mona Lisa TSP art used ~100,000 points.
- **Craig Kaplan's work** on TSP art typically uses 10,000–30,000 points for
  poster-sized output.
- **Key insight**: The minimum viable point count for a *recognizable face* on a
  small canvas is roughly **8,000–15,000 points**. For organic scenes (foliage,
  landscapes), you need even more because there are fewer strong edges to anchor
  recognition.

### EtchABot / CNC Etch A Sketch Projects
- **Evil Mad Scientist's EtchABot**: Uses NEMA 17 steppers (same as ours), typically
  with 1/8 or 1/16 microstepping. Draws edge-detected contour outlines rather than
  TSP art — focusing on edges produces more recognizable results with fewer total steps.
- **Various Arduino Etch A Sketch CNC projects** typically use:
  - NEMA 17 steppers at 1/8 microstepping (same as us)
  - Edge-based or hatching algorithms rather than TSP
  - Drawing times of 15-60 minutes for complex images

### Weighted Voronoi Stippling (Adrian Secord, 2002)
- Secord's original paper recommends **50–100 Lloyd's iterations** for convergence
  at high point counts. Our 40 iterations may be slightly low for 10,000+ points.
- The algorithm scales well up to ~50,000 points, but the pixel-based Voronoi
  diagram computation becomes the bottleneck (O(width × height × log n) per iteration).

### Continuous Line Drawing Algorithms
- **Hilbert curve approach**: Some projects trace a space-filling curve and modulate
  line deviation based on pixel darkness. Produces consistent density without TSP.
- **Spiral approach**: Trace a spiral path and modulate amplitude. Very fast, no TSP
  needed, but produces a distinctive "vinyl record" look.
- **Hatching/cross-hatching**: Draw parallel lines with spacing proportional to
  darkness. Multiple passes at different angles create cross-hatching. Very effective
  for recognizable images and computationally cheap.

### Motor Considerations
- Our NEMA 17 at 8× microstepping (1600 steps/rev, 40 steps/mm) provides **0.025mm
  resolution** — more than sufficient. The bottleneck is not mechanical precision but
  algorithmic quality.
- At 100 RPM: 333 steps/second ≈ 8.3mm/second. A 10,000-point drawing averages ~8,000
  seconds (~2.2 hours) which is long but feasible for a photo booth if reduced.
- Speed can be increased to 150–200 RPM for straight segments without quality loss.

---

## Identified Bottlenecks (Priority Ordered)

### 1. Point Count Too Low (CRITICAL)
- **Current**: max 6,000 points across 160,000 pixels = 1 dot per 26 pixels
- **Needed**: 10,000–20,000 points for recognizable photos
- **Impact**: The single biggest factor in drawing quality

### 2. Edge Preservation Too Weak (HIGH)
- **Current**: Optional 30% blend of Canny edges into tonal density map
- **Problem**: Edges should dominate structural recognition, not be a light seasoning
- **Similar projects**: Edge contours are drawn *first* as continuous lines, then tonal
  fill is added as TSP art in the remaining space

### 3. Working Resolution Too Low (MEDIUM)
- **Current**: 500×320 = 160,000 pixels
- **Needed**: 800×512 or 1000×640 for adequate detail at 10,000+ points
- **Rationale**: At 10,000 points on a 500×320 grid, each Voronoi cell is ~16 pixels.
  The density map can't represent enough tonal variation in cells that small.

### 4. TSP Solver Doesn't Scale (HIGH)
- **Current**: 2-opt with 10-second time cap, O(n² × passes)
- **At 15,000 points**: 2-opt barely completes 1 pass in 10 seconds
- **Fix needed**: Better heuristics, longer time budget, or alternative algorithms

### 5. Firmware Buffer Constraint (MEDIUM)
- **Current**: 50KB = ~25,500 move commands max
- **At 15,000 points**: With run-length encoding, typical paths produce 8,000–15,000
  move commands (well within budget). But with backlash compensation, this can double.
- **May need**: Buffer increase to 80-100KB or streaming protocol

### 6. Draw Time (LOW-MEDIUM)
- **Current heuristic**: 0.8 seconds per point → 10,000 points = ~2.2 hours
- **Optimization**: Increase speed for long straight segments (variable speed)
- **For photo booth use**: Need to target 30-60 minutes max

---

## Implementation Plan

### Phase 1: Raise Point Count Ceiling & Improve Defaults (HIGH IMPACT, LOW RISK)

**Files to modify:**
- `EtchBot/EtchBot/Models/DrawingSettings.swift`

**Changes:**
1. Raise `pointCountRange` from `500...6000` to `500...20000`
2. Change default `pointCount` from `2500` to `8000`
3. Change default `contrastMultiplier` from `1.0` to `1.5`
4. Change default `edgeEmphasisEnabled` from `false` to `true`
5. Change default `edgeWeight` from `0.3` to `0.5` (50/50 edges and tone)
6. Add a preset system: "Quick" (3000 pts), "Balanced" (8000 pts), "Detailed" (15000 pts)

**Rationale:** This alone will dramatically improve output quality. The algorithms
already work — they just need more points to work with.

---

### Phase 2: Increase Working Resolution (MEDIUM IMPACT, LOW RISK)

**Files to modify:**
- `EtchBot/EtchBot/Services/ImageProcessing/ImagePreprocessor.swift`

**Changes:**
1. Increase `workingWidth` from `500` to `1000`
2. Increase `workingHeight` from `320` to `640`
3. This gives 640,000 pixels — 4× more tonal detail for stippling
4. The physical output resolution stays the same (7000×4800 steps); only the
   *analysis* resolution increases

**Performance impact:** CLAHE will take ~4× longer (from ~50ms to ~200ms — still
within the 200ms target). Voronoi pixel-scan will take ~4× longer per iteration but
this is acceptable since it's background work.

---

### Phase 3: Stronger Edge-First Pipeline (HIGH IMPACT, MEDIUM EFFORT)

**Files to modify:**
- `EtchBot/EtchBot/Services/ImageProcessing/ImagePreprocessor.swift`
- `EtchBot/EtchBot/Services/ImageProcessing/EdgeDetector.swift`
- `EtchBot/EtchBot/Models/DrawingSettings.swift`

**Changes:**

#### 3a. Adaptive Edge Weighting
Instead of a flat blend weight, make edges dominate in edge regions and let tone
dominate in smooth regions:
```
blended[i] = max(edgeMap[i] * edgeBoost, densityPixels[i])
```
This ensures edges are never weaker than the tonal layer beneath them.

#### 3b. Multi-Scale Edge Detection
Add a second Canny pass at a coarser scale (σ=2.0) to capture broader structural
edges (leaf outlines) in addition to the fine edges (leaf veins). Merge both edge
maps before blending:
```
fineEdges   = Canny(σ=1.0, low=0.05, high=0.15)
coarseEdges = Canny(σ=2.0, low=0.03, high=0.10)
combinedEdges = max(fineEdges, coarseEdges)
```

#### 3c. Edge-Aware Stipple Density Boost
In regions where edges are detected, multiply the density by 1.5–2.0× to force
more stipple points onto edges. This concentrates the "ink" where structural
information lives:
```
if edgeMap[i] > 0.5:
    densityPixels[i] = min(1.0, densityPixels[i] * 2.0)
```

---

### Phase 4: TSP Solver Scalability (HIGH IMPACT, MEDIUM EFFORT)

**Files to modify:**
- `EtchBot/EtchBot/Services/ImageProcessing/TSPSolver.swift`
- `EtchBot/EtchBot/Models/DrawingSettings.swift`

**Changes:**

#### 4a. Scale Time Budget with Point Count
Replace the fixed 10-second 2-opt cap with a scaled budget:
```swift
let twoOptSeconds = max(10, min(60, points.count / 500))
// 3000 pts → 10s, 10000 pts → 20s, 15000 pts → 30s, 30000 pts → 60s
```

#### 4b. Increase 2-opt Neighbor Window
Currently checks 20 nearest neighbors. For higher point counts, increase to 30–40:
```swift
let neighborCount = min(40, max(20, n / 200))
```

#### 4c. Add 3-opt Moves (Optional, Advanced)
After 2-opt converges, run a 3-opt pass on the longest 10% of edges. This catches
crossing paths that 2-opt misses.

#### 4d. Segment-Based TSP for Large Counts
For point counts >10,000, divide the canvas into a grid of regions (e.g., 4×3),
solve TSP within each region, then stitch regions together. This reduces the
effective problem size from O(n²) to O((n/k)² × k), giving a dramatic speedup
while maintaining local quality:
```
Grid: 4×3 = 12 regions, 15000 points → ~1250 points/region
Each sub-TSP: trivial (<1 second for 2-opt)
Stitching: Connect region tours by breaking the closest edge pairs at boundaries
```

---

### Phase 5: Improved Preprocessing (MEDIUM IMPACT, LOW EFFORT)

**Files to modify:**
- `EtchBot/EtchBot/Services/ImageProcessing/ImagePreprocessor.swift`

**Changes:**

#### 5a. Replace Linear Contrast with Sigmoid Curve
The current `contrastMultiplier` just scales pixel values linearly — it clips at 0
and 1, losing tonal range. A sigmoid curve preserves the full range while boosting
separation:
```swift
// Sigmoid contrast: maps [0,1] → [0,1] with variable steepness
let midpoint: Float = 0.5
let steepness = 5.0 * Float(settings.contrastMultiplier)
pixels[i] = 1.0 / (1.0 + exp(-steepness * (pixels[i] - midpoint)))
```

#### 5b. Bilateral Filter (Optional)
Before edge detection, apply a bilateral filter to smooth noise while preserving
edges. This reduces spurious stipple points in noisy regions (like the bokeh in
the leaf photo) and concentrates them on true structure.

#### 5c. Background Suppression
For photos with shallow depth-of-field (like the leaf photo), suppress out-of-focus
background regions. This can be approximated by reducing density in low-variance
regions:
```
For each tile in the density map:
  if local_variance < threshold:
    density *= 0.3  // suppress smooth/blurry background
```
This concentrates points on the sharp foreground subject.

---

### Phase 6: Firmware Buffer Expansion (LOW IMPACT, LOW RISK)

**Files to modify:**
- `etchbot-firmware/config.h`

**Changes:**
1. Increase `PATH_BUFFER_SIZE` from 50KB to 100KB:
   ```c
   #define PATH_BUFFER_SIZE (100u * 1024u)  // 100KB
   ```
   The nRF52840 has 256KB RAM; BLE stack uses ~80KB, leaving ~176KB free. Going to
   100KB still leaves 76KB for stack/heap — comfortable margin.

2. This doubles max move commands from ~25,500 to ~51,000, removing any buffer
   constraint for paths up to 20,000 points.

---

### Phase 7: Variable Drawing Speed (MEDIUM IMPACT, LOW EFFORT)

**Files to modify:**
- `etchbot-firmware/drawing_executor.cpp`
- `etchbot-firmware/config.h`

**Changes:**
For long straight-line segments (run length > 100 steps), increase motor speed
to 150–200 RPM. For short segments near detail areas, keep 100 RPM. This can
reduce total draw time by 20-40% without visible quality loss:
```c
uint16_t speedForMove(uint16_t runLength) {
    if (runLength > 200) return SPEED_MAX_RPM;
    if (runLength > 50)  return 150;
    return SPEED_DRAW_DEFAULT_RPM;
}
```

---

## Summary: Expected Impact by Phase

| Phase | Change | Point Target | Quality Impact | Draw Time Impact | Effort |
|-------|--------|:------------:|:--------------:|:----------------:|:------:|
| 1 | Raise point count & defaults | 8K–20K | ★★★★★ | +2-3× longer | Small |
| 2 | Increase working resolution | — | ★★★☆☆ | +50ms preprocess | Small |
| 3 | Stronger edge pipeline | — | ★★★★☆ | Negligible | Medium |
| 4 | TSP solver scalability | 15K+ | ★★★★☆ | +10-30s compute | Medium |
| 5 | Better preprocessing | — | ★★★☆☆ | Negligible | Small |
| 6 | Firmware buffer expansion | — | ★☆☆☆☆ | None | Tiny |
| 7 | Variable draw speed | — | ☆☆☆☆☆ | -20-40% | Small |

## Recommended Implementation Order

1. **Phase 1** (immediate, biggest bang for buck)
2. **Phase 3** (edge quality is critical for recognition)
3. **Phase 4** (necessary to support Phase 1 at high point counts)
4. **Phase 2** (supports the quality gains from Phase 1 and 3)
5. **Phase 5** (polish — sigmoid contrast and background suppression)
6. **Phase 6** (safety net for high point counts)
7. **Phase 7** (quality of life — faster draws)

## Target: "Good Photo" Settings

For the leaf photo and similar organic subjects, the target parameters should be:
- **Point count**: 12,000–15,000
- **Contrast**: 1.5 (sigmoid curve)
- **Edge emphasis**: ON, weight 0.5, with multi-scale detection
- **Working resolution**: 1000×640
- **Draw time**: ~45-60 minutes at variable speed
- **Result**: Leaf outlines and major veins clearly visible, tonal shading in leaf
  bodies, suppressed blurry background
