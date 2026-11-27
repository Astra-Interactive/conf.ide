#!/usr/bin/env python3
"""Render store listing frames from raw app captures, one HTML page per frame, through headless Chrome.

Usage: python3 -I make_frames.py <spec.json> <out-dir> [slug-filter]
The spec names the raw-capture directory (relative to the spec), the title-bar height to crop, the brand
wordmark for the feature graphic and the frames. See spec.example.json beside this script for every field.
Each frame renders at 2x and is checked against its exact size; frames with a "final" size are downscaled.
"""
import html
import json
import pathlib
import subprocess
import sys

from PIL import Image

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SCALE = 2

BASE_CSS = """
html, body { margin: 0; padding: 0; width: %(w)dpx; height: %(h)dpx; overflow: hidden; }
body {
  font-family: -apple-system, "SF Pro Display", "Helvetica Neue", Arial, sans-serif;
  background:
    radial-gradient(%(gw)dpx %(gh)dpx at 50%% -10%%, rgba(43,107,224,0.38), rgba(43,107,224,0) 62%%),
    radial-gradient(%(gw)dpx %(gh)dpx at 50%% 115%%, rgba(43,107,224,0.18), rgba(43,107,224,0) 62%%),
    linear-gradient(180deg, #0B0F16 0%%, #0D121B 52%%, #090D13 100%%);
  color: #fff; position: relative;
}
.dots {
  position: absolute; inset: 0;
  background-image: radial-gradient(rgba(255,255,255,0.055) 1px, transparent 1px);
  background-size: 30px 30px;
  -webkit-mask-image: radial-gradient(%(mw)dpx %(mh)dpx at 50%% 45%%, #000 0%%, transparent 78%%);
}
.eyebrow { font-weight: 700; letter-spacing: 0.30em; color: #6FA8FF; text-transform: uppercase; }
h1 { margin: 0; font-weight: 800; letter-spacing: -0.022em; color: #FFFFFF; line-height: 1.04; }
.sub { color: #A7B2C3; font-weight: 400; line-height: 1.4; }
.win {
  position: absolute; border-radius: 18px; overflow: hidden; background: #0E1218;
  border: 1px solid rgba(255,255,255,0.12);
  box-shadow: 0 40px 110px rgba(0,0,0,0.70), 0 0 120px rgba(43,107,224,0.22);
}
.win .bar { height: 30px; background: #1A1F28; display: flex; align-items: center; padding-left: 14px; gap: 8px;
  border-bottom: 1px solid rgba(255,255,255,0.06); }
.win .bar i { width: 12px; height: 12px; border-radius: 50%%; display: block; }
.win .bar i:nth-child(1) { background: #FF5F57; } .win .bar i:nth-child(2) { background: #FEBC2E; }
.win .bar i:nth-child(3) { background: #28C840; }
.win.light { background: #F4F6F9; border-color: rgba(255,255,255,0.35); }
.win.light .bar { background: #E6E9EE; border-bottom-color: rgba(0,0,0,0.06); }
.win img { display: block; width: 100%%; }
.device {
  position: absolute; padding: 12px; background: #05070B; box-sizing: border-box;
  border: 2px solid rgba(255,255,255,0.10);
  box-shadow: 0 40px 110px rgba(0,0,0,0.70), 0 0 0 1px rgba(255,255,255,0.03), 0 0 130px rgba(43,107,224,0.22);
}
.device img { display: block; width: 100%%; }
.device .hinge { position: absolute; top: 12px; bottom: 12px; left: 50%%; width: 26px; transform: translateX(-50%%);
  background: linear-gradient(90deg, rgba(0,0,0,0) 0%%, rgba(0,0,0,0.22) 45%%, rgba(255,255,255,0.05) 52%%, rgba(0,0,0,0) 100%%); }
.glow { position: absolute; transform: translate(-50%%, -50%%);
  background: radial-gradient(closest-side, rgba(43,107,224,0.30), rgba(43,107,224,0) 70%%); }
.chip {
  position: absolute; z-index: 6; background: rgba(22,28,38,0.82);
  border: 1px solid rgba(255,255,255,0.12); border-radius: 18px; padding: 12px 18px 14px;
  box-shadow: 0 18px 50px rgba(0,0,0,0.50); backdrop-filter: blur(14px); text-align: left;
}
.chip .w { font-size: 28px; font-weight: 700; color: #FFFFFF; line-height: 1.1; }
.chip .t { font-size: 18px; color: #8FB4F5; margin-top: 4px; }
"""

PHONE_CHIP_CSS = ".chip .w { font-size: 34px; } .chip .t { font-size: 24px; } .chip { padding: 16px 22px 18px; border-radius: 22px; }"


def page(w, h, body, extra_css=""):
    css = BASE_CSS % {"w": w, "h": h, "gw": int(w * 1.1), "gh": int(h * 0.75), "mw": int(w * 0.9), "mh": int(h * 0.9)}
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{css}{extra_css}</style></head><body><div class="dots"></div>{body}</body></html>'


def chips_html(chips):
    return "".join(
        f'<div class="chip" style="{style}"><div class="w">{html.escape(word)}</div><div class="t">{html.escape(meaning)}</div></div>'
        for word, meaning, style in chips
    )


def window(img, style, light=False):
    cls = "win light" if light else "win"
    return f'<div class="{cls}" style="{style}"><div class="bar"><i></i><i></i><i></i></div><img src="{img.as_uri()}"></div>'


def caption(f, style, sizes):
    eb, ti, su = sizes
    return (f'<div style="position:absolute;z-index:5;{style}">'
            f'<div class="eyebrow" style="font-size:{eb}px;margin-bottom:{int(eb*0.9)}px">{html.escape(f["eyebrow"])}</div>'
            f'<h1 style="font-size:{ti}px">{f["title"]}</h1>'
            f'<div class="sub" style="font-size:{su}px;margin-top:{int(su*0.8)}px">{f["sub"]}</div></div>')


def desktop(f, img):
    w, h, win_w = 1280, 720, f.get("win_w", 1040)
    body = caption(f, "top:46px;left:0;right:0;text-align:center", (15, 50, 21))
    body += '<div class="glow" style="left:50%;top:560px;width:1200px;height:700px"></div>'
    body += window(img[0], f"left:{(w - win_w) // 2}px;top:236px;width:{win_w}px", f.get("light", False))
    return w, h, page(w, h, body + chips_html(f.get("chips", [])))


def desktop_duo(f, img):
    w, h = 1280, 720
    body = caption(f, "top:46px;left:0;right:0;text-align:center", (15, 50, 21))
    body += '<div class="glow" style="left:50%;top:560px;width:1200px;height:700px"></div>'
    body += window(img[0], "left:70px;top:236px;width:820px")
    body += window(img[1], "left:390px;top:310px;width:820px;z-index:3", light=True)
    return w, h, page(w, h, body)


def phone(f, img):
    w, h = 1080, 1920
    body = caption(f, "top:96px;left:0;right:0;text-align:center", (23, 86, 33))
    body += '<div class="glow" style="left:50%;top:1160px;width:900px;height:900px"></div>'
    body += (f'<div class="device" style="left:209px;top:560px;width:662px;border-radius:64px;padding:15px;z-index:3">'
             f'<img src="{img[0].as_uri()}" style="border-radius:50px"></div>')
    return w, h, page(w, h, body + chips_html(f.get("chips", [])), PHONE_CHIP_CSS)


FOLD_LAYOUTS = {
    "fold-1x1": (1080, 1080, "left:70px;top:262px;width:940px", "top:64px;left:0;right:0;text-align:center", (16, 60, 26), 34, True),
    "fold-4x3": (1440, 1080, "left:580px;top:218px;width:820px", "top:330px;left:80px;width:500px;text-align:left", (16, 60, 26), 34, True),
    "fold-10x16": (675, 1080, "left:107px;top:330px;width:460px", "top:56px;left:0;right:0;text-align:center", (13, 48, 20), 44, False),
}


def fold(f, img):
    w, h, device_style, cap_style, sizes, radius, hinge = FOLD_LAYOUTS[f["type"]]
    body = caption(f, cap_style, sizes)
    body += f'<div class="glow" style="left:50%;top:{int(h*0.62)}px;width:{int(w*1.1)}px;height:{int(h*0.8)}px"></div>'
    hinge_html = '<div class="hinge"></div>' if hinge else ""
    body += (f'<div class="device" style="{device_style};border-radius:{radius}px">'
             f'<img src="{img[0].as_uri()}" style="border-radius:{radius-12}px">{hinge_html}</div>')
    return w, h, page(w, h, body + chips_html(f.get("chips", [])))


def feature(f, img, brand):
    w, h = 1024, 500
    body = '<div class="glow" style="left:760px;top:250px;width:900px;height:620px"></div>'
    icon = f.get("icon")
    icon_html = (f'<img src="{icon.as_uri()}" style="width:58px;height:58px;border-radius:14px">' if icon else "")
    body += (f'<div style="position:absolute;left:56px;top:92px;z-index:5;width:420px">'
             f'<div style="display:flex;align-items:center;gap:14px;margin-bottom:26px">{icon_html}'
             f'<div style="font-size:26px;font-weight:700;letter-spacing:-0.01em">{html.escape(brand)}</div></div>'
             f'<h1 style="font-size:54px">{f["title"]}</h1>'
             f'<div class="sub" style="font-size:19px;margin-top:18px">{f["sub"]}</div></div>')
    body += window(img[0], "left:520px;top:70px;width:640px")
    body += (f'<div class="device" style="left:470px;top:150px;width:200px;border-radius:30px;padding:8px;z-index:4">'
             f'<img src="{img[1].as_uri()}" style="border-radius:22px"></div>')
    return w, h, page(w, h, body)


FINAL = {"feature": (1024, 500), "phone": (1080, 1920)}


def render(slug, w, h, doc, out: pathlib.Path, final_size):
    tmp = out / "_build"
    tmp.mkdir(parents=True, exist_ok=True)
    name = slug.replace("/", "__")
    html_path = tmp / f"{name}.html"
    html_path.write_text(doc, encoding="utf-8")
    shot = tmp / f"{name}@2x.png"
    shot.unlink(missing_ok=True)
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    f"--user-data-dir={tmp / 'chrome-profile'}",
                    f"--force-device-scale-factor={SCALE}", f"--window-size={w},{h}", f"--screenshot={shot}",
                    html_path.as_uri()], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not shot.exists():
        raise SystemExit(f"{slug}: Chrome wrote no screenshot")
    im = Image.open(shot).convert("RGB")
    if im.size != (w * SCALE, h * SCALE):
        raise SystemExit(f"{slug}: capture {im.size} != {(w * SCALE, h * SCALE)}")
    if final_size and final_size != im.size:
        im = im.resize(final_size, Image.Resampling.LANCZOS)
    dest = out / f"{slug}.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, optimize=True)
    return dest, im.size


def main():
    spec_path, out = pathlib.Path(sys.argv[1]).resolve(), pathlib.Path(sys.argv[2]).resolve()
    only = sys.argv[3] if len(sys.argv) > 3 else None
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    raw = (spec_path.parent / spec["raw"]).resolve()
    crops = raw.parent / f"crops-{raw.name}"
    crops.mkdir(exist_ok=True)
    title_px = spec.get("title_px", 0)

    def crop(name):
        dest = crops / f"{name}.png"
        src = Image.open(raw / f"{name}.png").convert("RGB")
        src.crop((0, title_px, src.width, src.height)).save(dest)
        return dest

    for f in spec["frames"]:
        if only and only not in f["slug"]:
            continue
        img = [crop(n) for n in f["img"]]
        if f.get("icon"):
            f["icon"] = (spec_path.parent / f["icon"]).resolve()
        kind = f["type"]
        if kind == "desktop":
            w, h, doc = desktop(f, img)
        elif kind == "desktop-duo":
            w, h, doc = desktop_duo(f, img)
        elif kind == "phone":
            w, h, doc = phone(f, img)
        elif kind.startswith("fold-"):
            w, h, doc = fold(f, img)
        elif kind == "feature":
            w, h, doc = feature(f, img, spec["brand"])
        else:
            raise SystemExit(f"{f['slug']}: unknown frame type {kind}")
        print(*render(f["slug"], w, h, doc, out, FINAL.get(kind)))


if __name__ == "__main__":
    main()
