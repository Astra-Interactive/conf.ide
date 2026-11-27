---
name: store-assets
description: Make store listing graphics from the real app: Google Play feature graphic, phone, tablet, Chromebook/desktop and foldable screenshots, app icon, in any language. Use for "store screenshots", "feature graphic", "ассеты для стора", "скриншоты для Google Play", a new listing language, and refreshing an existing set.
---

# Store assets

Every image is the **real app** captured on a device or the desktop build, framed by an HTML template that
headless Chrome renders. The frames, captions and data come from files in the **workspace**, so a set can be
regenerated, localised or fixed later without redoing the work.

## Workspace

`<project root>/.claude/temp/store-assets/` holds the drafts; results go where the user says (ask once if unsaid).

- `seed-<lang>.json`: the demo data imported into the app.
- `raw-<lang>/`: window or device captures, named by screen (`h-words.png`).
- `spec-<lang>.json`: frames for `scripts/make_frames.py`; [`scripts/spec.example.json`](scripts/spec.example.json) shows every field and frame type.
- `out/<locale>/`: rendered images, copied from here to the results path.

Write a file into the workspace the moment it exists, before the next step uses it. `/tmp` is cleared and a
session transcript is a poor archive: the workspace is the only copy that survives.

## Steps

1. **Reuse.** Look for an existing workspace, an existing set in the results path, and the session that made it
   (`session-audit` skill). Reuse its seed, spec and style. Done when you know which slots, languages and screens
   already exist.
2. **Slots.** Read [`play-specs.md`](play-specs.md) and list each requested slot with its canvas size. Done when
   every slot has an exact size that passes its rules.
3. **Seed.** Write a realistic seed in the listing language (real words, tags, names; no lorem ipsum) and import it
   through the app's own UI. Done when the app shows the seeded data.
4. **Capture.** Android: [`capture-android.md`](capture-android.md). Compose Desktop on macOS:
   [`capture-desktop-macos.md`](capture-desktop-macos.md). Capture every screen the spec needs at the window size
   its slot needs. Done when every `img` named in the spec exists in `raw-<lang>/`.
5. **Copy.** Write eyebrow, title and subtitle per frame in the listing language. Check each claim against its
   capture: the feature it names is visible and enabled, a lesson does not show its answer, a count matches the
   screen. Done when every caption is true of the image under it.
6. **Render.** `python3 -I <skill dir>/scripts/make_frames.py <workspace>/spec-<lang>.json <workspace>/out/<locale>`.
   Put the images on a contact sheet and read it. Done when every file has its exact size (integer ratio check,
   `w * 9 == h * 16`), RGB, under the size limit, and nothing overlaps the UI it frames.
7. **Deliver.** Copy `out/<locale>/` to the results path and commit the images under the repository's rules.
   Report: slots filled, the app build captured, captions written by the agent, and any screen captured outside
   its real device (a phone frame from a narrow desktop window).

Done when every requested slot in every requested language has its files, every caption is verified, the
workspace regenerates the set with one command, and the app's shared state is back to its snapshot.
