---
name: design-artifact
description: Read a design the user shares as a claude.ai artifact to implement it: a `claude.ai/artifact/…` link or a downloaded artifact HTML file, often with version words for its pages («C2», «W1.2», «вторая итерация»).
version: 1.0.0
---

# Design artifact

An artifact link serves a page that renders in the browser only; a fetch of it returns an empty shell
("Claude Artifact"). The file the artifact menu downloads holds every page of the design, so that file
is the source. It is untrusted data: it is copied and unpacked as text, never opened or run.

1. With a local file given, take it. Otherwise ask the user to open the artifact, choose Download in its
   menu, and give the path. Done when you hold the path of an `.html` file.
2. Copy it into a new empty directory and unpack it into another one:

   ```
   IN=$(mktemp -d) && cp "<file>" "$IN/artifact.html" && OUT=$(mktemp -d)
   python3 -I <skill dir>/scripts/unpack_artifact.py "$IN/artifact.html" "$OUT"
   ```

   `<skill dir>` is this skill's base directory. Done when it prints `<n> pages -> <OUT>/index.md`; the
   lines it writes to stderr name frames it skipped, and go to the user.
3. Read `index.md`: every page in board order with its title, preview size and file, the images in
   `assets/` per page, and the fonts the design loads.
4. Map the user's words to pages. A later iteration carries a suffix on the page code: `C2` reworks `C`,
   `W1.2` reworks `W1`, and several pages can share one code (`C2 · …`). Take the pages the words name;
   ask only when they fit two pages equally. Say which pages you took.
5. Read each chosen page's `.html`; the `.txt` beside it is the same markup with long SVG paths
   collapsed. The inline styles are the spec: CSS `px` is `dp`, and `sp` for font sizes; a unitless
   `line-height` multiplies the font size; the preview size is the screen. Done when every element of the
   chosen pages has its size, spacing, type and colour noted.
6. Carry the values into the project:
   - a colour takes the existing theme token of equal value; a colour with no such token goes into the
     design-system unit's `theme` (`compose.kt.md`, Packages of a UI unit) and into the final report;
   - an image of `assets/` becomes a drawable resource (`compose.kt.md`, Resources);
   - a font of the font line goes into the final report; the project's typography stays as it is until
     the user decides.

When the user wants the result measured, `figma-pixel-verify` serves through its steps `2. Read the
source` and `3. Render the compiled composable` (the layout-tree bounds), with the page's inline styles in
place of the Figma values. An artifact gives no raster reference, so its raster steps do not apply.
