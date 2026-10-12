#!/usr/bin/env python3
"""Pixel measurement toolkit for comparing a Compose render against a Figma export.

Every coordinate given to or printed by a measurement command is in DP; the
--density option (px per dp) converts it, dp -> px with round-half-up. The
PNG itself is px. Luminance is Pillow's "L" conversion: Rec.601
(0.299 R + 0.587 G + 0.114 B) rounded to an integer 0..255, no gamma.

    measure.py info     <png> [--density D]
    measure.py flatten  <in.png> <out.png> --backdrop RRGGBB
    measure.py crop     <in.png> <out.png> <x0> <y0> <x1> <y1> --density D
    measure.py resize   <in.png> <out.png> (--factor F | --size WxH) [--filter nearest|bilinear|bicubic|lanczos]
    measure.py nodes    <png.nodes.tsv> --density D [--grep TEXT]
    measure.py vscan    <png> <x> <y0> <y1> --density D [--threshold 4]
    measure.py hscan    <png> <y> [<x0> <x1>] --density D [--threshold 4]
    measure.py region   <png> <x0> <y0> <x1> <y1> <h|v> --density D
    measure.py glyph    <png> <x0> <y0> <x1> <y1> --density D [--min-lum 120] [--dark]
    measure.py bands    <a.png> <b.png> --density D [--step 20] [--x0 X] [--x1 X]
    measure.py stats    <a.png> <b.png>
    measure.py sheet    <before.png> <after.png> <out.png> --labels BEFORE AFTER
                        [--zoom x0 y0 x1 y1 --density D] [--factor 4]

A Compose render is transparent where nothing was drawn and a transparent
pixel reads as black: measurement commands refuse an image with partial alpha,
run `flatten` first and state the backdrop in the report.

Edge detection (vscan/hscan) reports a position where |luminance delta| >
--threshold (default 4). A translucent border over a similar backdrop can sit
below that: retry with --threshold 1 before concluding there is no edge.
"""
import argparse
import math
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFont

HARD_EDGE = 20
FILTERS = {
    "nearest": Image.Resampling.NEAREST,
    "bilinear": Image.Resampling.BILINEAR,
    "bicubic": Image.Resampling.BICUBIC,
    "lanczos": Image.Resampling.LANCZOS,
}


def px(dp, density):
    return int(math.floor(dp * density + 0.5))


def dp(pixels, density):
    return pixels / density


def open_image(path):
    try:
        image = Image.open(path)
        image.load()
    except (OSError, ValueError) as error:
        sys.exit(f"cannot read {path}: {error}")
    if image.mode not in ("RGB", "RGBA", "L", "LA"):
        image = image.convert("RGBA")
    return image


def min_alpha(image):
    if "A" not in image.getbands():
        return 255
    return image.getchannel("A").getextrema()[0]


def luminance(path):
    """Grey image of `path`; refuses partial transparency because it would read as black."""
    image = open_image(path)
    if min_alpha(image) < 255:
        sys.exit(f"{path} has transparent pixels; run `measure.py flatten` first and state the backdrop")
    return image.convert("L")


def same_size(a, b):
    if a.size != b.size:
        sys.exit(f"images differ in size: {a.size[0]}x{a.size[1]} vs {b.size[0]}x{b.size[1]}; normalize both first")


def parse_hex(text):
    text = text.lstrip("#")
    if len(text) != 6:
        sys.exit(f"backdrop must be RRGGBB, got {text}")
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def cmd_info(args):
    image = open_image(args.png)
    width, height = image.size
    print(f"image      {width}x{height} px  mode={image.mode}")
    if args.density:
        print(f"           {dp(width, args.density):.1f} x {dp(height, args.density):.1f} dp @ density {args.density}")
    if "A" in image.getbands():
        alpha = image.getchannel("A")
        low, high = alpha.getextrema()
        transparent = alpha.histogram()[0]
        box = alpha.getbbox()
        print(f"alpha      min={low} max={high}  fully transparent px={transparent}")
        if box:
            print(f"content    bbox px (left, top, right, bottom)={box}")
            if args.density:
                print(f"           dp: {dp(box[0], args.density):.1f}, {dp(box[1], args.density):.1f}, "
                      f"{dp(box[2], args.density):.1f}, {dp(box[3], args.density):.1f}")
        if low < 255:
            print("flatten    needed before any luminance measurement (`measure.py flatten`)")
    for key in ("icc_profile", "gamma"):
        if key in image.info:
            print(f"warning    PNG carries {key}; values are read raw, without colour management")


def cmd_flatten(args):
    image = open_image(args.png).convert("RGBA")
    backdrop = Image.new("RGBA", image.size, parse_hex(args.backdrop) + (255,))
    Image.alpha_composite(backdrop, image).convert("RGB").save(args.out)
    print(f"saved {args.out}  backdrop #{args.backdrop.lstrip('#').upper()}")


def cmd_crop(args):
    image = open_image(args.png)
    box = (px(args.x0, args.density), px(args.y0, args.density), px(args.x1, args.density), px(args.y1, args.density))
    if box[0] >= box[2] or box[1] >= box[3]:
        sys.exit(f"empty crop box {box}")
    image.crop(box).save(args.out)
    print(f"saved {args.out}  px box (left, top, right, bottom)={box}  {box[2] - box[0]}x{box[3] - box[1]} px")


def cmd_resize(args):
    image = open_image(args.png)
    if args.size:
        width, height = (int(value) for value in args.size.lower().split("x"))
    else:
        width = int(round(image.size[0] * args.factor))
        height = int(round(image.size[1] * args.factor))
    image.resize((width, height), FILTERS[args.filter]).save(args.out)
    print(f"saved {args.out}  {image.size[0]}x{image.size[1]} -> {width}x{height} px  filter={args.filter}")


def cmd_nodes(args):
    density = args.density
    print("id      x       y       w       h   (dp)  tag  text")
    with open(args.tsv, encoding="utf-8") as handle:
        for line in handle:
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 5:
                continue
            node_id, left, top, right, bottom = fields[0], *(float(value) for value in fields[1:5])
            tag = fields[5] if len(fields) > 5 else ""
            text = fields[6] if len(fields) > 6 else ""
            if args.grep and args.grep not in tag and args.grep not in text:
                continue
            width, height = right - left, bottom - top
            note = "  (zero size)" if width == 0 or height == 0 else ""
            print(f"{node_id:<6}{dp(left, density):8.1f}{dp(top, density):8.1f}"
                  f"{dp(width, density):8.1f}{dp(height, density):8.1f}       {tag}  {text}{note}")


def edges(values, threshold):
    hits = []
    previous = None
    for index, value in enumerate(values):
        if previous is not None and abs(value - previous) > threshold:
            hits.append(index)
        previous = value
    return hits


def format_edges(hits, offset_px, density):
    if not hits:
        return "none  (retry with --threshold 1 before concluding)"
    return ", ".join(f"{dp(offset_px + hit, density):.1f}" for hit in hits) + " dp"


def cmd_vscan(args):
    grey = luminance(args.png)
    x = px(args.x, args.density)
    y0, y1 = px(args.y0, args.density), min(px(args.y1, args.density), grey.size[1])
    if not 0 <= x < grey.size[0] or y0 >= y1:
        sys.exit(f"scan outside the image: x={x}px y={y0}..{y1}px, image {grey.size[0]}x{grey.size[1]}px")
    values = [grey.getpixel((x, y)) for y in range(y0, y1)]
    print(f"x={args.x}dp  thr={args.threshold}  density={args.density}  edges at y: "
          f"{format_edges(edges(values, args.threshold), y0, args.density)}")


def cmd_hscan(args):
    grey = luminance(args.png)
    y = px(args.y, args.density)
    x0 = px(args.x0, args.density) if args.x0 is not None else 0
    x1 = min(px(args.x1, args.density), grey.size[0]) if args.x1 is not None else grey.size[0]
    if not 0 <= y < grey.size[1] or x0 >= x1:
        sys.exit(f"scan outside the image: y={y}px x={x0}..{x1}px, image {grey.size[0]}x{grey.size[1]}px")
    values = [grey.getpixel((x, y)) for x in range(x0, x1)]
    print(f"y={args.y}dp  thr={args.threshold}  density={args.density}  edges at x: "
          f"{format_edges(edges(values, args.threshold), x0, args.density)}")


def cmd_region(args):
    grey = luminance(args.png)
    d = args.density
    x0, y0, x1, y1 = px(args.x0, d), px(args.y0, d), px(args.x1, d), px(args.y1, d)
    if args.direction == "v":
        x = (x0 + x1) // 2
        values = [grey.getpixel((x, y)) for y in range(y0, min(y1, grey.size[1]))]
    else:
        y = (y0 + y1) // 2
        values = [grey.getpixel((x, y)) for x in range(x0, min(x1, grey.size[0]))]
    if len(values) < 2:
        sys.exit("empty region")
    hard = len(edges(values, HARD_EDGE))
    print(f"scan={args.direction}  contrast={max(values) - min(values):3d}  hardEdges={hard:2d}  "
          f"avg={sum(values) / len(values):5.1f}")


def cmd_glyph(args):
    grey = luminance(args.png)
    d = args.density
    x0, y0 = px(args.x0, d), px(args.y0, d)
    x1, y1 = min(px(args.x1, d), grey.size[0]), min(px(args.y1, d), grey.size[1])
    if args.dark:
        ink = grey.crop((x0, y0, x1, y1)).point(lambda value: 255 if value <= args.min_lum else 0)
    else:
        ink = grey.crop((x0, y0, x1, y1)).point(lambda value: 255 if value >= args.min_lum else 0)
    box = ink.getbbox()
    if not box:
        print("none")
        return
    left, top, right, bottom = x0 + box[0], y0 + box[1], x0 + box[2], y0 + box[3]
    rule = f"lum<={args.min_lum}" if args.dark else f"lum>={args.min_lum}"
    print(f"top={dp(top, d):.1f} bottom={dp(bottom, d):.1f} (h={dp(bottom - top, d):.1f})  "
          f"left={dp(left, d):.1f} right={dp(right, d):.1f} (w={dp(right - left, d):.1f}) dp  ink={rule}")


def row_mean(grey, y, x0, x1):
    values = [grey.getpixel((x, y)) for x in range(x0, x1)]
    return sum(values) / len(values) if values else float("nan")


def cmd_bands(args):
    a, b = luminance(args.a), luminance(args.b)
    same_size(a, b)
    d = args.density
    width_dp = dp(a.size[0], d)
    x0 = px(args.x0 if args.x0 is not None else 30, d)
    x1 = px(args.x1 if args.x1 is not None else width_dp - 30, d)
    x0, x1 = max(0, x0), min(a.size[0], x1)
    if x0 >= x1:
        sys.exit("band x-range is empty; pass --x0/--x1 inside the image")
    print("y(dp)      a       b   delta")
    y = args.step / 2
    while px(y, d) < a.size[1]:
        row = px(y, d)
        va, vb = row_mean(a, row, x0, x1), row_mean(b, row, x0, x1)
        delta = va - vb
        flag = " <<<" if abs(delta) > 20 else (" ~" if abs(delta) > 3 else "")
        print(f"{y:5.0f} {va:7.1f} {vb:7.1f} {delta:7.1f}{flag}")
        y += args.step


def cmd_stats(args):
    a, b = luminance(args.a), luminance(args.b)
    same_size(a, b)
    histogram = ImageChops.difference(a, b).histogram()
    total = sum(histogram)
    if total == 0:
        sys.exit("no comparable pixels")
    mean = sum(value * count for value, count in enumerate(histogram)) / total

    def percentile(share):
        target = share * total
        seen = 0
        for value, count in enumerate(histogram):
            seen += count
            if seen >= target:
                return value
        return 255

    maximum = max(value for value, count in enumerate(histogram) if count)
    within = lambda limit: sum(histogram[:limit + 1]) / total * 100
    print(f"pixels        {total}  ({a.size[0]}x{a.size[1]} px)")
    print(f"mean |delta|  {mean:.2f} / 255")
    print(f"median        {percentile(0.5)}    p95 {percentile(0.95)}    max {maximum}")
    print(f"within +-2    {within(2):.1f}%")
    print(f"within +-10   {within(10):.1f}%")


def labelled(image, label, band):
    font = ImageFont.load_default(size=max(14, band // 2))
    canvas = Image.new("RGB", (image.size[0], image.size[1] + band), (34, 34, 34))
    canvas.paste(image.convert("RGB"), (0, band))
    ImageDraw.Draw(canvas).text((12, band // 4), label, fill=(255, 255, 255), font=font)
    return canvas


def cmd_sheet(args):
    before, after = open_image(args.before), open_image(args.after)
    if args.zoom:
        if args.density is None:
            sys.exit("--zoom needs --density")
        box = tuple(px(value, args.density) for value in args.zoom)
        before, after = before.crop(box), after.crop(box)
    if args.factor != 1:
        before = before.resize((int(before.size[0] * args.factor), int(before.size[1] * args.factor)), Image.Resampling.NEAREST)
        after = after.resize((int(after.size[0] * args.factor), int(after.size[1] * args.factor)), Image.Resampling.NEAREST)
    band = max(40, max(before.size[1], after.size[1]) // 12)
    left, right = labelled(before, args.labels[0], band), labelled(after, args.labels[1], band)
    gap = 20
    sheet = Image.new("RGB", (left.size[0] + gap + right.size[0], max(left.size[1], right.size[1])), (34, 34, 34))
    sheet.paste(left, (0, 0))
    sheet.paste(right, (left.size[0] + gap, 0))
    sheet.save(args.out)
    print(f"saved {args.out}  {sheet.size[0]}x{sheet.size[1]} px  zoom={args.zoom or 'none'} factor={args.factor}")


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def density(p, required=True):
        p.add_argument("--density", type=float, required=required, help="px per dp")

    p = sub.add_parser("info"); p.add_argument("png"); density(p, required=False); p.set_defaults(run=cmd_info)
    p = sub.add_parser("flatten"); p.add_argument("png"); p.add_argument("out"); p.add_argument("--backdrop", required=True)
    p.set_defaults(run=cmd_flatten)
    p = sub.add_parser("crop"); p.add_argument("png"); p.add_argument("out")
    for name in ("x0", "y0", "x1", "y1"):
        p.add_argument(name, type=float)
    density(p); p.set_defaults(run=cmd_crop)
    p = sub.add_parser("resize"); p.add_argument("png"); p.add_argument("out")
    group = p.add_mutually_exclusive_group(required=True)
    group.add_argument("--factor", type=float); group.add_argument("--size")
    p.add_argument("--filter", choices=sorted(FILTERS), default="bicubic"); p.set_defaults(run=cmd_resize)
    p = sub.add_parser("nodes"); p.add_argument("tsv"); density(p); p.add_argument("--grep"); p.set_defaults(run=cmd_nodes)
    p = sub.add_parser("vscan"); p.add_argument("png")
    for name in ("x", "y0", "y1"):
        p.add_argument(name, type=float)
    density(p); p.add_argument("--threshold", type=float, default=4); p.set_defaults(run=cmd_vscan)
    p = sub.add_parser("hscan"); p.add_argument("png"); p.add_argument("y", type=float)
    p.add_argument("x0", type=float, nargs="?"); p.add_argument("x1", type=float, nargs="?")
    density(p); p.add_argument("--threshold", type=float, default=4); p.set_defaults(run=cmd_hscan)
    p = sub.add_parser("region"); p.add_argument("png")
    for name in ("x0", "y0", "x1", "y1"):
        p.add_argument(name, type=float)
    p.add_argument("direction", choices=("h", "v")); density(p); p.set_defaults(run=cmd_region)
    p = sub.add_parser("glyph"); p.add_argument("png")
    for name in ("x0", "y0", "x1", "y1"):
        p.add_argument(name, type=float)
    density(p); p.add_argument("--min-lum", type=int, default=120)
    p.add_argument("--dark", action="store_true", help="ink is darker than --min-lum (dark text on light backdrop)")
    p.set_defaults(run=cmd_glyph)
    p = sub.add_parser("bands"); p.add_argument("a"); p.add_argument("b"); density(p)
    p.add_argument("--step", type=float, default=20); p.add_argument("--x0", type=float); p.add_argument("--x1", type=float)
    p.set_defaults(run=cmd_bands)
    p = sub.add_parser("stats"); p.add_argument("a"); p.add_argument("b"); p.set_defaults(run=cmd_stats)
    p = sub.add_parser("sheet"); p.add_argument("before"); p.add_argument("after"); p.add_argument("out")
    p.add_argument("--labels", nargs=2, default=("BEFORE", "AFTER"))
    p.add_argument("--zoom", nargs=4, type=float, metavar=("X0", "Y0", "X1", "Y1"))
    density(p, required=False); p.add_argument("--factor", type=float, default=1); p.set_defaults(run=cmd_sheet)
    return parser


def main():
    args = build_parser().parse_args()
    args.run(args)
    return 0


if __name__ == "__main__":
    sys.exit(main())
