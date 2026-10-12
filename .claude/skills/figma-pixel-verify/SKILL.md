---
name: figma-pixel-verify
description: Verify a rendered Compose Multiplatform composable against its Figma node with measured evidence instead of impressions. Use when asked to compare a Compose screen or component with Figma, match a design, check against the mock, make something pixel perfect, prove a UI change matches the spec, or when implementing a Figma node and needing evidence the result is correct. Covers Figma MCP extraction, source and layout-tree geometry, headless Skia rendering of a @Preview through a throwaway desktopTest, Pillow measurement, and the Haze, Modifier.blur, line-height and density traps that make previews lie.
version: 1.0.0
---

# Purpose

Compare a **compiled** Compose Multiplatform composable against a Figma node and report
differences as evidence, not impressions.

Evidence has four tiers, strongest first:

1. **Source geometry and tokens** — what the code declares, what the design declares.
   Deterministic and always comparable.
2. **Layout-tree geometry** — the semantics-node bounds the render writes next to the PNG.
   Exact px from the layout pass, no edge detection, no antialiasing.
3. **Raster geometry** — where things actually landed in the pixels. Catches the gap between
   declared and rendered, which is where most real bugs live.
4. **Raster colour** — only probative when both sides have a comparable backdrop. See
   `Comparability`.

Most agents jump straight to tier 4 and get a confident wrong answer.

## Instructions

- Render the **real composable's `@Preview`** through the harness, never a hand-written replica.
  The harness invokes the preview by name; it does not copy its body.
- Read the source before attributing a cause. A pixel delta tells you *what*, a layout trace
  tells you *why*.
- **Always look at the images too.** Numeric agreement is necessary, not sufficient: a row mean
  cannot tell a blur from a flat slab.
- Calibrate every raster measurement against the layout-tree bounds of a known node before
  believing any delta.
- Every number is in **dp with the density stated**; raw px are labelled `px`.
- Every render is labelled **"Skia desktop render"**. It is not an Android or iOS render: text
  rasterization, blur radius and the Haze fallback differ per platform.
- Say plainly when something cannot be measured, instead of estimating.
- When the platform cannot express what the design asks for, escalate rather than shipping an
  approximation that scores well on a flawed metric.
- Correct your own earlier claims when a better measurement contradicts them.

## Prerequisites

Run every check **before** the first step of the workflow, not after a call has already failed.
A tool that has not answered once in this session is unproven, no matter how ordinary the call
looks.

```bash
SKILL="$(git rev-parse --show-toplevel)/.claude/skills/figma-pixel-verify/scripts"
```

| Need | Check |
|---|---|
| Figma desktop running, the file open, Dev Mode on, "Enable desktop MCP server" switched on in the inspect panel | `python3 "$SKILL/figma.py" probe` prints `ok session=…`, **then** one real call (`meta`) that returns content |
| JDK and Gradle for the target repository | `java -version` (the project compiles to JVM 21; Gradle 9.7 runs on JDK 17 to 26) and `./gradlew --version` from the repository root |
| Python 3 with Pillow | `python3 -c "import PIL; print(PIL.__version__)"` |
| The module of the preview has the desktop test dependencies | `grep -n "compose.ui.test\|coroutines.test\|kotlin.test" <module>/build.gradle.kts`; see step 3 for the temporary edit when one is missing |
| The preview is renderable | it lives under `src/commonMain` or `src/desktopMain` of a module with a `jvm("desktop")` target and takes no parameters; `render_preview.sh` refuses otherwise |

When a probe fails — **stop and ask the user**, do not improvise. Name the exact thing to fix
(open the file in Figma desktop, switch on the MCP server, install Pillow with
`python3 -m venv .venv && .venv/bin/pip install pillow`), wait for confirmation, then retry the
same call once. Do not retry blindly, do not switch to a substitute method (screenshotting the
running app, eyeballing the IDE preview, hand-written replicas), and do not report a
verification that was never measured.

If the user declines, finish the determinate part of the task and list the unverified items
explicitly as an unmeasured gap.

**Read-only audits:** keep every artifact under `/tmp`. Do not copy renders into the repository,
never commit the harness (CI runs `allTests`, and the commit rule forbids staging files that were
not part of the change), and run **one render at a time**.

`ksrc` is the way to read Compose, Skiko and Haze sources. In a project with
`org.gradle.isolated-projects=true` it needs `export GRADLE_OPTS="-Dorg.gradle.isolated-projects=false"`,
`--subproject :path:to:module` and `--targets desktop`.

## Workflow

### 1. Select and read the design

If you were given a file key and node id, **open it first** — the MCP serves the active tab, so an
id alone is meaningless:

```bash
open "figma://file/<fileKey>?node-id=31-5391" && sleep 5
```

Prefer the native `figma_*` MCP tools when the host exposes them. `figma.py` is a fallback for
when `tools/list` times out; both return the same payloads.

```bash
python3 "$SKILL/figma.py" meta    31:5391   # tree, positions, sizes, hidden flags
python3 "$SKILL/figma.py" context 31:5391   # fills, radii, borders, blur (React + Tailwind reference)
python3 "$SKILL/figma.py" vars    31:5391   # authoritative token values
python3 "$SKILL/figma.py" shot    31:5391 /tmp/figma.png   # PNG; no scale option on the desktop server
```

Read `meta` first: `hidden="true"` layers are not part of the spec, and implementing one is a bug.
`get_design_context` returns React + Tailwind whatever `clientLanguages`/`clientFrameworks` say;
treat it as a structural reference, the screenshot is the visual truth. A scaled export
(`download_assets`) exists only on the remote server, so the screenshot is the canvas at 1x.
`get_metadata` without a node id (`figma.py raw get_metadata '{}'`) lists the document's pages:
use it to recover when a node id points at a page instead of a frame.

**Record what geometry you actually have.** A node queried directly reports its own local origin
as `(0, 0)`. Absolute placement lives in its *parent* — query the parent frame for it. If you
cannot obtain it, say "absolute design position unavailable from this node" rather than comparing
against a guess.

### 2. Read the source

Before any image work, establish what the code declares:

- the composable under test and its modifier chain, in order (`padding` before `background`
  and after it are different pictures)
- **which modifier sizes each child and what constraints it receives** — `Modifier.size` is
  clamped by the parent, `Modifier.requiredSize` is not and centers its overflow
- the text styles: font family, size, `lineHeight`, and whether `lineHeightStyle` is set
- the token definitions in the codebase, so you compare RGBA values rather than token names:
  `Color(0x0DFAFAFA)` is **ARGB** (`#FAFAFA` at alpha `0x0D`), Figma and Tailwind write `RRGGBBAA`
- the preview's own `@Preview(widthDp, heightDp, fontScale, showBackground, …)` parameters: the
  harness does **not** apply them, the request does (step 3)

This step is what finds most real bugs. Tiers 3 and 4 only confirm them.

### 3. Render the compiled composable

```bash
bash "$SKILL/render_preview.sh" \
  components/core/ktx-compose/src/commonMain/kotlin/.../TextPlaceholderComposable.kt \
  TextPlaceholderComposableRegularPreview /tmp/code.png \
  --width 360 --height 200 --density 2            # --font-scale 1 --inspection true
```

What it does: derives the Gradle path from the file path and the facade class from the package
(`<FileName>Kt`, or `@file:JvmName`), copies `FigmaPreviewRenderTest.kt.template` into
`<module>/src/desktopTest/kotlin/figmaverify/`, runs
`./gradlew <module>:desktopTest --tests figmaverify.FigmaPreviewRenderTest --rerun`, copies the
PNG and `<out>.nodes.tsv`, and removes the harness again on success or failure. The log is at
`/tmp/figma-compose-verify/gradle.log`.

- The harness calls the v2 `runSkikoComposeUiTest(size, density)` and captures the whole surface,
  so the PNG is exactly `width × density` by `height × density` px, transparent where nothing was
  drawn.
- A `private` preview is fine: a zero-parameter `@Composable` compiles to a static
  `(Composer, Int)` method and is invoked by name through reflection. `@Preview` has BINARY
  retention, so nothing can discover previews at runtime; name them explicitly.
- A preview **with parameters** (`@PreviewParameter`) cannot be invoked. Add a temporary
  zero-parameter `private` preview next to it that calls the same composable, render, and revert
  that edit; never commit it.
- Previews under `androidMain` are not part of the desktop compilation and cannot be rendered.
- When the module lacks `ui-test`, `kotlinx-coroutines-test` or `kotlin-test`, add them to its
  `commonTestDependencies` block for the duration of the task and revert the edit; the script
  prints the three lines.
- `--inspection true` (default) mirrors the IDE preview: `LocalInspectionMode` is true, so the
  focus and autofill guards of the `compose-hoisting` skill skip. The IDE sets it, a plain test
  render does not.
- The first run compiles the module and its dependencies for the desktop target and takes
  minutes; with the module already built a render takes seconds. `--rerun` is passed because
  Gradle otherwise reports `UP-TO-DATE` and writes nothing.
- A render that fails prints the last lines of the Gradle log and the JUnit failure. A
  `ClassNotFoundException` means the facade class is wrong (pass `--facade`); "expected exactly
  one zero-parameter composable" means the name or arity is wrong.

### 4. Normalize, and write down the scale

The render is already the right size and has no window chrome. What differs from Figma:

| Image | Unit | Background |
|---|---|---|
| `/tmp/code.png` | px = dp × density | transparent where nothing was drawn |
| `/tmp/figma.png` | px = dp (1x export) | whatever the canvas baked in |

```bash
python3 "$SKILL/measure.py" info /tmp/code.png --density 2            # size, alpha, content bbox
python3 "$SKILL/measure.py" flatten /tmp/code.png /tmp/a.png --backdrop 000000
python3 "$SKILL/measure.py" resize  /tmp/figma.png /tmp/b.png --factor 2 --filter bicubic
```

Flatten onto the backdrop the design assumes and **state it**: a transparent pixel reads as black
in every luminance command, and the commands refuse an image with partial alpha. Either render at
density 1 to compare against the 1x export without resampling (fractional dp then rounds), or
render at density 2 for half-dp geometry and upscale the Figma image (resampling blurs; treat
small deltas as noise). State the choice in the report.

### 5. Calibrate

Confirm the raster agrees with the layout tree on a node whose design position you know from
`meta`. If they disagree, the crop or the scale is wrong, not the code.

```bash
python3 "$SKILL/measure.py" nodes /tmp/code.png.nodes.tsv --density 2 --grep Title
python3 "$SKILL/measure.py" vscan /tmp/a.png 143 190 300 --density 2
python3 "$SKILL/measure.py" vscan /tmp/b.png 143 190 300 --density 2
```

The node dump holds every semantics node (text, `testTag`, clickable, shapes with semantics) with
`boundsInRoot` in px; a bare `Column` without semantics is not in it. Nodes of zero size are
flagged: a `fillMaxWidth` inside unbounded width, or a child that got no space.

### 6. Measure raster geometry

```bash
python3 "$SKILL/measure.py" hscan /tmp/a.png 400 --density 2             # left and right edges
python3 "$SKILL/measure.py" vscan /tmp/a.png 143 360 440 --density 2     # top and bottom edges
python3 "$SKILL/measure.py" glyph /tmp/a.png 16 370 270 426 --density 2 --min-lum 150   # ink bounds
```

`glyph` reports the extent of pixels brighter than `--min-lum` (use `--dark` for dark text on a
light backdrop); keep the box tight so borders and neighbouring text do not leak in.

If a scan reports `none`, the edge is below the detection threshold, not absent. Retry with
`--threshold 1` and cross-check against the node dump and the source geometry:

```bash
python3 "$SKILL/measure.py" hscan /tmp/a.png 375 --density 2 --threshold 1
```

Report **declared** (source), **laid out** (node dump) and **observed** (raster) geometry
separately whenever they disagree — that disagreement is usually the finding.

### 7. Compare style from authoritative values

Corner radius, fill, border colour and width, blur: compare the code's token RGBA against `vars`
output. Do not read colours off pixels when a token exists, and convert the channel order before
comparing (ARGB in code, RRGGBBAA in Figma).

### 8. Raster colour, only if comparable

See `Comparability` below. When it applies:

```bash
python3 "$SKILL/measure.py" bands /tmp/a.png /tmp/b.png --density 2 --step 20   # screening
python3 "$SKILL/measure.py" stats /tmp/a.png /tmp/b.png                         # distribution
```

`bands` is a **screening** tool that shows which y ranges deserve attention. It aggregates text,
icons, borders and fills into one number, so never quote it as proof on its own. `stats` reports
mean |delta|, median, p95 and the share within ±2 and ±10 over every pixel.

Treat ±2 as a match: antialiasing and font rasterization differ between Skia and Figma, and the
same nominal text renders at different widths.

### 9. Look at the images

Read both crops as images. Crop tight around anything flagged, save under stable `/tmp` names
and say in the report which crops you inspected.

```bash
python3 "$SKILL/measure.py" crop /tmp/a.png /tmp/q_a.png 0 505 286 545 --density 2
python3 "$SKILL/measure.py" crop /tmp/b.png /tmp/q_b.png 0 505 286 545 --density 2
```

### 10. Re-render after every change and repeat 5-9

Changing what a container *holds* can change its geometry. Re-verify after swapping a placeholder
for a real component, not only after editing layout.

### 11. Prove the fix with a before/after pair

When the task is *fixing* review findings, "after matches design" is only half the proof. The
reviewer also needs to see that the finding existed and is gone. Produce a **baseline** render of
the same preview from the base commit and run the **same measurement commands** on both images.
Do this for every finding, not only the visually obvious ones.

```bash
git worktree add --detach /tmp/<task>-base "$(git merge-base HEAD origin/dev)"
cp local.properties /tmp/<task>-base/            # gitignored, Gradle needs the SDK path
bash "$SKILL/render_preview.sh" /tmp/<task>-base/<same file> <same preview> \
  /tmp/<task>-proof/before/<name>.png --width 360 --height 200 --density 2
```

Rules:

- If the fix also changed the preview, apply **only** that preview change to the baseline
  worktree so both renders have the same canvas. Never let the baseline carry any of the fix.
- Keep artifacts under `/tmp/<task>-proof/{before,after}/<name>.png`. Same file name for the same
  preview on both sides, same request (size, density, font scale).
- Measure with identical commands and quote both numbers plus the design value in the report:
  `chevron ink to card edge: 18.5 -> 13.5 dp (design 13.67)`. For weight changes measure ink
  width and mean luminance of the same word, for blur count `hardEdges` in the same region, for
  wrapping measure the width of the second line.
- Build a labelled side-by-side per screen, so the reviewer can read it without the numbers:

```bash
python3 "$SKILL/measure.py" sheet before/x.png after/x.png compare-x.png \
  --labels 'BEFORE (origin/dev)' 'AFTER (<ticket>)'
python3 "$SKILL/measure.py" sheet before/x.png after/x.png compare-x-zoom.png \
  --zoom 0 505 80 545 --density 2 --factor 4      # hairline defects: crop and scale 4x
```

- Two worktrees share `~/.gradle` (caches, daemons) and nothing else; still render one side at a
  time. The baseline's first build compiles everything again.
- Remove the baseline worktree when done (`git worktree remove`), it is evidence, not a branch.

## Comparability

Before comparing colours, decide which case you are in.

| Situation | Verdict |
|---|---|
| Neither side uses backdrop blur (`backdrop-blur`, Haze) or `Modifier.blur` | Comparable. Proceed. |
| Both sides sit on the same known backdrop (the render flattened onto it, the export over it) | Comparable. State the backdrop. |
| Figma uses `backdrop-blur` and the export baked an unknown canvas backdrop | **Not comparable.** Compare geometry, tokens and source instead, and label colour numbers non-probative. |
| The code uses Haze and the render has a detailed `hazeSource` behind the effect | Comparable for the Skia desktop render only. State the radius mapping (Traps) and that Android is unverified. |
| The code uses Haze over a uniform or missing source | **Not comparable.** A blur of a flat backdrop is invisible; measure geometry only. |
| The code uses `Modifier.blur` | A content blur, not glass. Compare it as a content effect. |
| The target is Android below API 31 | Haze draws its scrim fallback there; a desktop render does not predict it. |

Detect a baked backdrop by cross-checking two regions: if a 70 % black fill implies a bright
(~247) backdrop in one band while another band implies ~160, one of them is an export artifact.
Confirm from the fills — a container emitted as `relative rounded-[34px] size-full`, with no `bg-`
class, contributes nothing of its own.

Proving a blur is real: a real backdrop blur destroys high-frequency detail. Scan **across** the
detail — horizontal stripes are invisible to a horizontal scan.

```bash
python3 "$SKILL/measure.py" region /tmp/a.png 100 50 200 150 v --density 1
# contrast=  7  hardEdges= 0   <- blur present
# contrast=255  hardEdges=25   <- no blur, detail reads through
```

## Traps

Each entry is a measurement that once produced a confident wrong conclusion. The *fix* lines are
remediation context, not part of the verification workflow.

### Layout

**`requiredSize` overflows and centers.** `Modifier.size` is clamped by the incoming constraints;
`Modifier.requiredSize`/`requiredWidth`/`requiredHeight` are not: the parent is reported a size
coerced into its constraints and the content is offset to be centered on the space it was given.
A 140 dp `requiredSize` child of a 100 × 80 dp parent renders 140 × 140, centered on the parent
and overflowing it on every side; the same child with `size` renders 100 × 80. Always find out in step 2 which modifier sizes
the child. *Fix: `size` with the right constraints, or correct the padding.*

**`Spacer()` has no size; `weight` has.** A `Spacer(Modifier)` measures 0 × 0 inside a `Column`,
so nothing overflows because of it. `Modifier.weight(1f)` takes the space that remains after the
unweighted children, and `fill = false` lets the column shrink. `fillMaxWidth` inside unbounded
width (a `Row` with `horizontalScroll`) has no effect and the node measures 0 wide.

**Bottom-anchored content is not misaligned.** Content placed with `Arrangement.Bottom`,
`Alignment.BottomCenter` or a weighted spacer is positioned from the bottom, so comparing its top
against an absolute Figma y produces a phantom delta. Verify `top + height == container bottom`
from the node dump.

**Text is not clipped just because the background ends there.** A glyph row occupies only the
middle of its line box. Measure the actual glyph extent in both images before claiming truncation;
identical spans mean the text is intact and the real difference is the missing background beneath
it.

**The default `LineHeightStyle` trims the text box.** A one-line 20 sp `Text` with
`lineHeight = 40.sp` measures 24 px tall at density 1 under the default style (`Proportional`, `Trim.Both`) and 40 px
with `LineHeightStyle(alignment = Center, trim = Trim.None)`. A Figma text box of
`lineHeight × lines` therefore does not match a Compose `Text` unless the style sets
`lineHeightStyle`. `includeFontPadding` exists only on Android and a desktop render cannot show it.

**Layout rounds every dp.** Each size goes through `Dp.roundToPx()`: 10.5 dp is 21 px at density
2 but 11 px at density 1 and 28 px at 2.625. A half-dp design value is exact only at an even
density; compare in dp and state the density.

### Blur

**Alpha on a Haze child brings the detail back.** `Modifier.alpha(0.25f)` on the effect, or
`alpha(0.25f)` in the `HazeBlurStyle`, crossfades the blurred layer with the sharp backdrop:
measured over a striped backdrop, contrast 7 / hardEdges 0 intact versus 192 / 25 with alpha. It
is the Compose twin of `.opacity()` on a `Material`. *Fix: composite a tint over an intact blur
with `colorEffects(listOf(HazeColorEffect.tint(...)))`.*

**A blur over a flat backdrop proves nothing.** The blurred and the sharp render of a uniform
backdrop are identical. The `hazeSource` must carry detail behind the effect, and the scan must
cross it.

**`Modifier.blur` is a content blur.** It renders the composable into a layer with a
`BlurEffect`; it does not touch what is behind it, and below Android 12 it is ignored. Compare it
as a content effect, never as glass.

**A Compose blur radius is not a CSS sigma.** On Skia, `blurRadius` becomes a sigma of
`0.57735 × r + 0.5`, while CSS `blur(Npx)` (Figma's `backdrop-blur-[Npx]`) uses `N` as the sigma.
`backdrop-blur-[7.43px]` is therefore about `blurRadius(12.dp)`, confirmed by measuring the step
response, not by the number. How Android maps the radius is unverified; never quote a desktop
render as proof of an Android blur radius.

**Haze below API 31 draws a scrim.** `isBlurEnabledByDefault()` is true on Skia targets and
`SDK_INT >= 31` on Android. With blur off, a style with only `backgroundColor` and no colour
effect draws **nothing**; the fallback needs `fallbackColorEffect` or a `colorEffects` tint.

### Measurement method

**Row means cannot distinguish a blur from a slab.** Both average to 127.5 over the same
stripes. Pair `bands` with `stats` and with the image.

**Transparent pixels read as black.** Every luminance command refuses an image with partial
alpha; `flatten` first and state the backdrop. A render flattened onto white and an export over
black are not comparable.

**Edge scans fail silently on translucent borders.** A 3 % border over a similar backdrop falls
under the default threshold and reports `none`. Retry with `--threshold 1` before concluding an
edge is absent.

**Scan across the detail, not along it.** Horizontal stripes give contrast 6 to a horizontal scan
and 133 to a vertical one.

**The node dump is px, the commands are dp.** `nodes` converts with `--density`; a copied raw
number is wrong by the density factor, and the resulting delta looks like a real bug.

### Figma extraction

**Never guess a design token's value.** Token families are not internally consistent: one real
palette has `colorBlack100` and `colorBlack0` as `#000000` but `colorBlack50` as `#111111` at
50 %. Guessing `colorBlack70` from the family name risks a 12/255 error. Get the value from
`vars`, or ask.

**An empty `vars` result means "not bound", not "no token".** `get_variable_defs` returns only
variables the queried node uses. `{}` means the designer has not applied the variable to that
layer. Ask them to bind it — that is the only way to read it programmatically, and it makes the
mock self-documenting.

**Tailwind output drops alpha on borders.** `border border-solid border-white` usually means a
token with alpha, not opaque white. Cross-check `vars`: a `borders/*` entry in the node's variable
list is the real colour. Plain `border` is 1 px; an explicit width appears as `border-[0.743px]`.

**ARGB in code, RRGGBBAA in Figma.** `Color(0x0DFAFAFA)` is `#FAFAFA` at 5 % alpha. Read the
hex in the wrong order and a near-transparent fill becomes an opaque dark one.

**Node id constraints.** Ids must match `^\d+[:-]\d+$`. Instance-scoped ids such as
`I31:5401;292:6308` are rejected — query the top-level instance. The node must be in the currently
active Figma tab.

### Harness and environment

**`UP-TO-DATE` is not a render.** Without `--rerun` Gradle skips the test task and the previous
PNG stays. The script always passes it; if you call Gradle yourself, so must you.

**Infinite animations freeze.** Under the test clock an infinite transition (shimmer, spinner)
is cancelled and shows its first frame. Finite animations finish before the capture. A placeholder
shimmer therefore renders at its start colour.

**`@Preview` parameters are not applied.** `widthDp`, `heightDp`, `fontScale`, `showBackground`,
`backgroundColor`, `device` only matter to the IDE. The request supplies size, density and font
scale; `flatten` supplies the background.

**An unknown font family is Helvetica on macOS.** A `FontFamily("Missing")` does not fall back to
the system font; Skia resolves it to Helvetica, and the text measures narrower. Bundled fonts
(`Res.font.*`) load synchronously on desktop and render as themselves. A width delta on text is a
font question before it is a layout question.

**A desktop render is not the app.** `commonMain` previews shown in the IDE are Android
(layoutlib) renders; this harness renders with Skia. Goldens are per platform. Text metrics, blur
radius and the Haze fallback differ; the findings that depend on them say so.

**Previews under `androidMain` cannot be rendered**, and neither can anything that needs an
Android API; the desktop compilation does not include them.

**JDK 24 and newer print a native-access warning** from Skiko in the test output. It is
harmless.

**One render at a time.** Two Gradle builds in the same directory contend for the same outputs;
two worktrees share only `~/.gradle`.

## Reporting

Lead with the verdict, then evidence by tier, then differences worst-first. For each difference
give the measurement, its location, and the cause — not the symptom.

```
## Verdict
<match / not a match>, in one sentence

## Render
Skia desktop render on macOS, JDK 25; scene 360 x 200 dp @ density 2 = 720 x 400 px;
flattened onto #000000; Figma 1x export upscaled x2 bicubic
preview: TextPlaceholderComposableRegularPreview (components/core/ktx-compose)

## Geometry
| element | design | declared in code | laid out (nodes) | observed raster |
|---|---|---|---|---|
| card | 254 x 56 at (16, 370) | 254 x 56 | 258 x 56 at (14, 370) | 258 x 56 at (14, 370) |

## Tokens
| property | Figma | code | |
|---|---|---|---|
| fill | background/secondary_03 #FAFAFA08 | backgroundQuaternary03 Color(0x08FAFAFA) | exact |

## Raster colour
comparable / non-comparable, and why
mean |delta| 7.9/255, within ±2 61.7%, crops inspected: /tmp/q_a.png /tmp/q_b.png

## Cause
<layout trace, from source>

## Not measurable
<what, and why: Android text metrics, blur radius on device, androidMain preview, …>
```

For a fix task, add a per-finding table with both renders and the design value. Every row needs
a number; a code-level claim ("whole row is now clickable") is allowed only when the finding is
about behaviour, and must say so.

```
## Before / after
| # | finding | before | after | design | evidence |
|---|---|---|---|---|---|
| 3 | chevron 12 px from edge | 18.5 dp | 13.5 dp | 13.67 dp | glyph ink right edge vs card edge 464 |
| 8 | blur missing on bar | hardEdges=19 | hardEdges=0 | glass | region 100..200 x 50..150 v |
composites: /tmp/<task>-proof/compare-*.png
```

Run project gates **only if you changed code**, and only those the repository's own instructions
require. A read-only audit ends with the report, and `git status` shows no harness and no
dependency edit.

## Related

- `compose-hoisting` — previews are `private`, at the bottom of the file, wrapped in the theme,
  guarded with `LocalInspectionMode`; the harness honours all of that
- The repository's testing and commit rules — the harness is a test file that is never committed
- `ksrc` — reading the Compose, Skiko and Haze sources behind any claim in this skill
- The target repository's own build, test and preview skills take precedence where they define
  stricter workflows
