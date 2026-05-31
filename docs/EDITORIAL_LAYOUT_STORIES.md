# Stories landing — editorial layout spec (iOS)

This document is the **contract** for matching web spacing on the native Stories feed. Agents should not “make it airy”; they should tune **named constants** against **measured** screenshot ratios.

## Canonical reference

- **Target:** IMG_1177 (hero + LATEST STORIES peek only).
- **Structure:** Black hero dominates the first screen; the first content below the hero is **LATEST STORIES** on a **light brown** (`understoodBeige`) background (header + horizontal peek). **Belief / connection carousel is not shown on Stories landing** — open Beliefs from the menu.
- **Philosophy:** See [`.cursor/rules/mobile-layout-philosophy.mdc`](../.cursor/rules/mobile-layout-philosophy.mdc) — scrolling is effortless; the first paint is a magazine cover, not an index.

## Measured reference (PNG export)

Run `python3 docs/scripts/measure_hero_cutoff.py <file.png>` for `cutoff_ratio`.

| Reference asset | Size | cutoff_ratio |
|-----------------|------|----------------|
| `IMG_1121-1b5c7d89-079d-480d-8785-0d978c1ef6fd.png` | 471×1024 | **0.6338** |
| Canonical **IMG_1177** (`IMG_1177-307ec950-06af-4cf5-b729-e2b7dc8a9c5c.png`) | 471×1024 | **0.6494** |

**iOS constant:** `StoriesLandingMetrics.heroHeightScreenFraction` is **0.634** (aligned to the first row). If tuning purely to IMG_1177, stay within **0.63–0.67** or update the constant and re-verify.

**Acceptance:** Simulator screenshot of Stories landing (same device class, e.g. iPhone 17 Pro) should yield `cutoff_ratio` within **±0.02** of **0.634** (or your chosen target in the 0.63–0.67 band once agreed).

## Landmarks (vocabulary for prompts)

Specify spacing with **ratios or points**, not adjectives:

| Landmark | Spec |
|----------|------|
| Hero / light cutoff | Bottom edge of black hero = **~63.4%** of scroll content coordinate space height used for hero (`GeometryReader` height in `ContentView`). |
| Overlay nav | Wordmark + search + menu; horizontal padding matches `StoriesLandingMetrics`. |
| First editorial line | Category + date row; top padding below screen top accounts for status bar + overlay (see `StoriesLandingMetrics.heroContentTopPadding`). |
| Peek | `LATEST STORIES` section starts **at or just below** hero bottom — user scrolls for full list. |

## Code constants

Magic numbers for this screen live in **`StoriesLandingMetrics`** in [`Understood/ContentView.swift`](../Understood/ContentView.swift). Change those only after re-measuring.

## Verification script (PIL only)

Save a full-screen PNG from Simulator (e.g. *Device → Screenshot*), then:

```bash
python3 docs/scripts/measure_hero_cutoff.py path/to/screenshot.png
```

The script prints `cutoff_ratio` — compare to **0.634** ± **0.02**.

## Forbidden on this landing (canonical IMG_1177)

- Belief carousel **above** LATEST STORIES (breaks fold alignment with web).
- `ZStack` default centering for hero text (use `topLeading`).
- `Spacer()` at top of hero text stack (pushes copy to bottom incorrectly).
