---
name: store-assets
description: Make store listing graphics from the real app: Google Play feature graphic, phone, tablet, Chromebook/desktop and foldable screenshots, app icon, in any listing language. Use for store screenshots, a feature graphic, a new listing language, and refreshing an existing set.
---

# Store assets

Every image is the **real app** captured on a device or the desktop build, framed by an HTML template that
headless Chrome renders. The frames, captions and data come from files in the **workspace**, so a set can be
regenerated, localised or fixed later without redoing the work.

## Workspace

`<project root>/.claude/temp/store-assets/` holds the drafts; results go where the user says (ask once if unsaid).
Before the first file, check `git check-ignore -q .claude/temp/store-assets`; when it is not ignored, add
`.claude/temp/` to `.git/info/exclude` (local, nothing to commit).

- `seed-<lang>.json`: the demo data imported into the app.
- `raw-<lang>/`: window or device captures, named by screen (`list-wide.png`).
- `spec-<lang>.json`: frames for `scripts/make_frames.py`; [`scripts/spec.example.json`](scripts/spec.example.json) shows every field and frame type.
- `out/<locale>/`: the final PNGs only, copied from here to the results path.
- `_build/`: the renderer's HTML, crops and contact sheets.

Write a file into the workspace the moment it exists, before the next step uses it. `/tmp` is cleared and a
session transcript is a poor archive: the workspace is the only copy that survives.

## Steps

1. **Reuse.** Look for an existing workspace, an existing set in the results path, and the session that made it
   (`session-audit` skill). Reuse its seed, spec and style. Done when you know which slots, languages and screens
   already exist.
2. **Slots.** Read [`play-specs.md`](play-specs.md) and list each requested slot with its canvas size. Done when
   every slot has an exact size that passes its rules.
3. **Plan.** Write `spec-<lang>.json` with one frame per image: slug, frame type, the raw screens it uses. Done
   when every slot from step 2 has its frames.
4. **Seed.** Write a realistic seed in the listing language (real names and content; no lorem ipsum) and import it
   through the app's own UI. Done when the app shows the seeded data.
5. **Capture.** Android: [`capture-android.md`](capture-android.md). Compose Desktop on macOS:
   [`capture-desktop-macos.md`](capture-desktop-macos.md). Done when every `img` named in the spec exists in
   `raw-<lang>/`.
6. **Copy.** Write eyebrow, title, subtitle and cards per frame in the listing language. Check each claim against
   its capture: the feature it names is visible and enabled, a quiz does not show its answer, a count matches the
   screen. Done when every caption is true of the image under it.
7. **Render.** `python3 -I <skill dir>/scripts/make_frames.py <workspace>/spec-<lang>.json <workspace>/out/<locale>`,
   then read the contact sheet it prints. Done when every file has its slot's exact canvas size, RGB, under the
   size limit, and no card or caption covers the UI it frames.
8. **Deliver.** Copy `out/<locale>/` to the results path and commit the images under the repository's rules.
   Report: slots filled, the app build captured, captions written by the agent, any screen captured outside its
   real device (a phone frame from a narrow desktop window), and Google's advice against framed, text-heavy
   screenshots (`play-specs.md`).

Done when every requested slot in every requested language has its files, every caption is verified, the
workspace regenerates the set with one command, and the app's shared state is back to its snapshot.

## Template

The frames are dark blue with a dot grid, a caption block, a device or window frame and optional floating cards
(a bold line over a caption line, for the app's own content). Change the palette in `BASE_CSS` of
`make_frames.py` for another brand, inside the workspace copy when one project needs it.
