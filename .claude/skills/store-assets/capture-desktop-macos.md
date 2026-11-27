# Capture a Compose Desktop build on macOS

## Isolate the app's data

Run the built app (`build/compose/binaries/main-release/app/<App>.app/Contents/MacOS/<App>`, or a fresh
`createReleaseDistributable`; note the version it shows) with
`JAVA_TOOL_OPTIONS="-Djava.io.tmpdir=<ws>/tmpdir -Duser.home=<ws>/home -Duser.language=<lang> -Duser.country=<CC>"`.
Find which stores follow `java.io.tmpdir` and `user.home` in the project before trusting this.

`java.util.prefs` on macOS ignores `user.home`: the domain `com.apple.java.util.prefs` is shared by every JVM
app on the machine and holds their tokens. Keep its copies in a
`mktemp -d` directory outside the repository, `chmod 600`:

1. Before launch: `defaults export com.apple.java.util.prefs <tmp>/before.plist`.
2. After the app quits: export `<tmp>/after.plist`; with `plistlib`, list the keys that differ (print key names
   only), then write `<tmp>/fixed.plist` = after with exactly those keys reverted to before (removed when before
   lacks them). Other apps' changes made meanwhile stay.
3. `defaults import com.apple.java.util.prefs <tmp>/fixed.plist`, export again, check it equals before, delete
   `<tmp>`.

The `capture-guard` hook allows only `defaults export|import` of the domain to a file.

## Drive the window

- Window id and frame: `scripts/windows.swift [owner]` (id is the CG window id). With yabai the id is the same:
  `yabai -m window <id> --toggle float`, `--display <retina>`, `--move abs:x:y`, `--resize abs:w:h`; read the frame
  back (yabai clamps `y` under the menu bar). Without yabai, size the window with System Events
  (`osascript -e 'tell application "System Events" to set size of window 1 of process "<App>" to {w, h}'`).
- Capture on the Retina display, window only: `screencapture -x -o -l<id> <file>`. A full-screen capture records
  other apps' windows; the hook blocks it.
- Clicks: `swiftc -O <skill dir>/scripts/click.swift -o <tmp>/click` (same for `move.swift`, `windows.swift`);
  `click <x> <y>` and `move <x> <y>` take screen points. They need Accessibility for the terminal host; when
  macOS asks, stop and ask the user to grant it. Focus the window before each click
  (`yabai -m window <id> --focus`); screen point = window frame origin + capture pixel ÷ 2.
- Move the pointer off the window before a capture, or the hovered card is highlighted.
- The title bar is 28 pt (`title_px: 58` at 2x, the dark separator row included); set it per frame when one spec
  mixes desktop and device captures.
- Native file dialogs open tiled and huge: put the seed file in the isolated `user.home` so it is the only entry.

## Window size per slot

The size picks the layout; check the app's width breakpoint and capture each slot at the layout it advertises.

| Slot | Window (pt, title bar included) |
|---|---|
| desktop 16:9 | width above the wide-layout breakpoint, content 16:9 (1280×748) |
| sparse screens (a quiz, an empty state) | smaller window so the UI reads larger (960×568) |
| foldable unfolded 1:1 / 4:3 | content 4:3 at the wide layout (1120×868) |
| foldable outer 10:16 | 420×700 |
| phone frame | 400×820 (content ≈ 1:1.98); say it is the desktop build |
