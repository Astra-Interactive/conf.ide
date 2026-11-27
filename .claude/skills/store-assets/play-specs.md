# Google Play listing graphics

Canvas sizes that `make_frames.py` renders and the slot each one fills.

| Slot | Rule | Frame type → file size |
|---|---|---|
| App icon | 512×512, 32-bit PNG with alpha, ≤1 MB | not rendered: the project's Play icon (`ic_launcher-playstore.png`) |
| Feature graphic | exactly 1024×500, PNG/JPEG, no alpha, ≤15 MB | `feature` → 1024×500 |
| Phone | 2–8, 16:9 or 9:16, sides 320–3840 | `phone` → 1080×1920 |
| 7" tablet | up to 8, 16:9 or 9:16, sides 320–3840 | `desktop` → 2560×1440 |
| 10" tablet | up to 8, 16:9 or 9:16, sides 1080–7680 | `desktop` → 2560×1440 |
| Chromebook / desktop | 4–8, 16:9 or 9:16, sides 1080–7680, ≤8 MB | `desktop`, `desktop-duo` → 2560×1440 |
| Foldable | 3–8, sides 960–3840, ≤8 MB: one unfolded 1:1, one unfolded 4:3, one outer folded 10:16 portrait; extras in 4:3, 3:4, 16:10, 10:16, 1:1, 16:9, 9:16 | `fold-1x1` → 2160², `fold-4x3` → 2880×2160, `fold-10x16` → 1350×2160 |

One 2560×1440 set satisfies the 7", 10" and desktop slots at once.

Google advises screenshots that show the app itself with little text; frames and overlay text pass upload but
can count against featuring. Say so when delivering.
