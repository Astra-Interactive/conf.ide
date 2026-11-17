"""Unpack a claude.ai artifact saved as one HTML file into page markup an agent can read.

Usage: python3 -I unpack_artifact.py <artifact.html> <output_dir>

The saved file is a bundle: a JSON manifest of base64 entries (gzip or raw deflate when compressed), a
page order, and a template. A board's template holds one <iframe src="about:blank#<uuid>"> per page; each
page entry is again a bundle whose template holds the page markup after </helmet>. A file without such
frames, or whose frames all fail to resolve, is unpacked as one page. The output directory must be new or
empty. It gets index.md (pages in board order with title, preview size and file names),
NN-<slug>.html per page (the markup with its non-font CSS, no scripts, no fonts), NN-<slug>.txt (the
same markup with long SVG path data collapsed) and assets/NN-<id>.<ext> for images a page references.
Frames and images that do not resolve are reported on stderr. Pages are written as they are rendered, so
a run stopped by a limit leaves the pages written before it.

The input is untrusted: it is scanned as text in linear time, nothing in it is executed or fetched, and
its size, page count, decoded bytes and output bytes are capped.
"""
from __future__ import annotations

import argparse
import base64
import html
import json
import mimetypes
import re
import string
import sys
import zlib
from dataclasses import dataclass
from pathlib import Path

MAX_INPUT_BYTES = 128 * 1024 * 1024
MAX_ENTRY_BYTES = 64 * 1024 * 1024
MAX_TOTAL_BYTES = 256 * 1024 * 1024
MAX_OUTPUT_BYTES = 256 * 1024 * 1024
MAX_PAGES = 200
MAX_DIMENSION = 100_000
LONG_VALUE = 80
SLUG_LENGTH = 48
CAMEL_PREFIX = "sc-camel-"
CSP = "default-src 'none'; img-src data: 'self'; style-src 'unsafe-inline'"

ASCII_LOWER = str.maketrans(string.ascii_uppercase, string.ascii_lowercase)
TAG_STOP = re.compile(r"[\"'>]")
TAG_NAME = re.compile(r"[A-Za-z][A-Za-z0-9:_-]*")
ATTRIBUTE_GAP = re.compile(r"[\s/]*")
ATTRIBUTE_NAME = re.compile(r"[^\s\"'<>/=]+")
SPACE = re.compile(r"\s*")
UNQUOTED_VALUE = re.compile(r"[^\s>]+")
FONT_FAMILY = re.compile(r"font-family\s*:\s*['\"]?([^;'\"}]+)", re.I)
FONT_WEIGHT = re.compile(r"font-weight\s*:\s*([^;}]+)", re.I)
ENTRY_ID = re.compile(r"[0-9A-Za-z-]{1,64}")
DIMENSION = re.compile(r"[0-9]{1,6}")
TAG_BOUNDARY = frozenset(" \t\n\r\f/>")
DROPPED_ELEMENTS = frozenset({"script", "style", "noscript", "helmet"})
DROPPED_TAGS = frozenset({"link", "base", "meta", "x-dc"}) | DROPPED_ELEMENTS
REFERENCE_ATTRIBUTES = frozenset({"src", "href", "xlink:href", "poster", "data"})
COLLAPSED_ATTRIBUTES = frozenset({"d", "points"})


class ArtifactError(Exception):
    pass


class LimitError(ArtifactError):
    pass


@dataclass
class Element:
    open_tag: str
    content: str


@dataclass
class Attribute:
    name: str
    value: str | None


@dataclass
class Frame:
    entry_id: str
    title: str
    width: int | None
    height: int | None


@dataclass
class Page:
    title: str
    template: str
    manifest: Manifest
    width: int | None
    height: int | None


@dataclass
class Rendered:
    base: str
    title: str
    html: str
    text: str
    preview: str
    fonts: dict
    assets: dict


class Budget:
    def __init__(self):
        self.spent = 0

    def decode(self, entry):
        if not isinstance(entry, dict) or not isinstance(entry.get("data"), str):
            raise ArtifactError("the entry has no base64 data string")
        try:
            data = base64.b64decode(entry["data"])
        except ValueError as error:
            raise ArtifactError(f"the entry is not valid base64: {error}") from error
        if entry.get("compressed"):
            data = inflate(data, max(1, min(MAX_ENTRY_BYTES, MAX_TOTAL_BYTES - self.spent)))
        self.spent += len(data)
        if self.spent > MAX_TOTAL_BYTES:
            raise LimitError(f"the entries decode past {MAX_TOTAL_BYTES} bytes in total")
        return data


class Manifest:
    def __init__(self, entries, budget):
        self.entries = entries if isinstance(entries, dict) else {}
        self.budget = budget
        self.cache = {}

    def mime(self, entry_id):
        entry = self.entries.get(entry_id)
        if not isinstance(entry, dict) or not isinstance(entry.get("mime"), str):
            return ""
        return entry["mime"].split(";")[0].strip().lower()

    def read(self, entry_id, keep=True):
        if entry_id in self.cache:
            return self.cache[entry_id]
        data = self.budget.decode(self.entries.get(entry_id))
        if keep:
            self.cache[entry_id] = data
        return data


class References:
    def __init__(self, manifest, assets, label):
        self.manifest = manifest
        self.assets = assets
        self.label = label
        self.files = {}
        self.failed = set()

    def target(self, token):
        entry_id = token.strip()
        file_name = self.assets.get(entry_id)
        if file_name is None or entry_id in self.failed:
            return None
        if file_name not in self.files:
            try:
                self.files[file_name] = self.manifest.read(entry_id, keep=False)
            except LimitError:
                raise
            except ArtifactError as error:
                self.failed.add(entry_id)
                report(f"{self.label}: image {entry_id}: {error}; its reference stays as it is")
                return None
        return f"assets/{file_name}"

    def rewrite_urls(self, css):
        lower = ascii_lower(css)
        pieces = []
        position = 0
        while True:
            start = lower.find("url(", position)
            end = css.find(")", start + 4) if start >= 0 else -1
            if end < 0:
                pieces.append(css[position:])
                return "".join(pieces)
            target = self.target(css[start + 4:end].strip().strip("\"'"))
            if target is None:
                pieces.append(css[position:end + 1])
            else:
                pieces.append(f'{css[position:start]}url("{target}")')
            position = end + 1

    def rewrite_srcset(self, srcset):
        candidates = []
        for candidate in srcset.split(","):
            parts = candidate.split(None, 1)
            target = self.target(parts[0]) if parts else None
            candidates.append(" ".join([target, *parts[1:]]) if target else candidate.strip())
        return ", ".join(candidates)

    def rewrite_value(self, name, value):
        unescaped = html.unescape(value)
        if name in REFERENCE_ATTRIBUTES:
            rewritten = self.target(unescaped) or unescaped
        elif name == "srcset":
            rewritten = self.rewrite_srcset(unescaped)
        elif name == "style":
            rewritten = self.rewrite_urls(unescaped)
        else:
            return value
        return value if rewritten == unescaped else html.escape(rewritten, quote=True)

    def rewrite_tag(self, tag):
        name = TAG_NAME.match(tag, 1)
        if name is None:
            raise ArtifactError(f"a tag without a name: {table_cell(tag[:40])}")
        full = [f"<{name.group()}"]
        compact = [f"<{name.group()}"]
        for attribute in parse_attributes(tag, name.end()):
            lowered = attribute.name.lower()
            if lowered.startswith("on"):
                continue
            output_name = attribute.name
            if lowered.startswith(CAMEL_PREFIX):
                output_name = camel(lowered[len(CAMEL_PREFIX):])
            value = attribute.value
            if value is not None:
                value = self.rewrite_value(lowered, value)
            full.append(attribute_text(output_name, value))
            compact.append(attribute_text(output_name, compact_value(lowered, value)))
        ending = " />" if self_closing(tag) else ">"
        return "".join(full) + ending, "".join(compact) + ending


class Writer:
    def __init__(self, output):
        self.output = output
        self.written = 0
        self.rows = []
        self.asset_lines = []
        self.fonts = {}
        output.mkdir(parents=True, exist_ok=True)

    def write(self, relative, data):
        self.written += len(data)
        if self.written > MAX_OUTPUT_BYTES:
            raise LimitError(f"the output passes {MAX_OUTPUT_BYTES} bytes")
        path = self.output / relative
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(data)

    def add(self, page):
        self.write(f"{page.base}.html", page.html.encode("utf-8", "replace"))
        self.write(f"{page.base}.txt", page.text.encode("utf-8", "replace"))
        for file_name, data in page.assets.items():
            self.write(f"assets/{file_name}", data)
        for family, weights in page.fonts.items():
            self.fonts.setdefault(family, set()).update(weights)
        number = page.base.split("-", 1)[0]
        self.rows.append(f"| {number} | {table_cell(page.title)} | {table_cell(page.preview)} | {page.base}.html |")
        if page.assets:
            self.asset_lines.append(f"- {page.base}.html: " + ", ".join(f"assets/{name}" for name in page.assets))

    def finish(self, source_name, board_title):
        font_line = "; ".join(
            f"{table_cell(family)} {', '.join(table_cell(weight) for weight in sorted(weights))}"
            for family, weights in sorted(self.fonts.items())
        )
        index = [
            f"# {table_cell(board_title)}",
            "",
            f"Source: {table_cell(source_name)}. Pages in board order; preview is the page's design size in CSS px.",
            "Each NN-<slug>.txt beside its .html holds the same markup with long SVG path data collapsed.",
            "",
            "| # | title | preview | file |",
            "|---|---|---|---|",
            *self.rows,
            "",
            *(["Images the pages reference:", *self.asset_lines, ""] if self.asset_lines else []),
            f"Fonts the pages load (files not unpacked): {font_line or 'none'}.",
            "",
        ]
        self.write("index.md", "\n".join(index).encode("utf-8", "replace"))


def parse_args():
    parser = argparse.ArgumentParser(description="Unpack a saved claude.ai artifact into readable page markup.")
    parser.add_argument("artifact", help="the artifact HTML file saved from claude.ai")
    parser.add_argument("output", help="a new or empty directory for index.md and the pages")
    return parser.parse_args()


def report(message):
    print(message, file=sys.stderr)


def clean(text):
    return text.encode("utf-8", "replace").decode("utf-8")


def ascii_lower(text):
    return text.translate(ASCII_LOWER)


def table_cell(text):
    printable = "".join(char if char.isprintable() else " " for char in text)
    return " ".join(printable.split()).replace("|", "\\|")


def inflate(data, limit):
    for wbits in (zlib.MAX_WBITS | 32, -zlib.MAX_WBITS):
        inflater = zlib.decompressobj(wbits=wbits)
        try:
            inflated = inflater.decompress(data, limit)
        except zlib.error:
            continue
        if inflater.eof:
            return inflated
        if inflater.unconsumed_tail or len(inflated) >= limit:
            raise LimitError(f"an entry inflates past {limit} bytes, the per-entry cap or what remains of the total")
    raise ArtifactError("a compressed entry is truncated, or neither gzip nor raw deflate")


def load_json(text, what):
    try:
        return json.loads(text)
    except (ValueError, RecursionError) as error:
        raise ArtifactError(f"{what} is not valid JSON: {error}") from error


def find_tag(lower, marker, position):
    while True:
        found = lower.find(marker, position)
        if found < 0:
            return -1
        after = found + len(marker)
        if after == len(lower) or lower[after] in TAG_BOUNDARY:
            return found
        position = after


def tag_end(text, position):
    while True:
        stop = TAG_STOP.search(text, position)
        if stop is None:
            return -1
        if stop.group() == ">":
            return stop.end()
        closing = text.find(stop.group(), stop.end())
        if closing < 0:
            bracket = text.find(">", stop.end())
            return bracket + 1 if bracket >= 0 else -1
        position = closing + 1


def self_closing(tag):
    return tag[:-1].rstrip().endswith("/")


def element_bounds(text, lower, name, start):
    open_end = tag_end(text, start + 1 + len(name))
    if open_end < 0:
        return None
    if self_closing(text[start:open_end]):
        return open_end, open_end, open_end
    close = find_tag(lower, "</" + name, open_end)
    close_end = text.find(">", close) if close >= 0 else -1
    if close_end < 0:
        return None
    return open_end, close, close_end + 1


def open_tags(text, name):
    lower = ascii_lower(text)
    position = 0
    while True:
        start = find_tag(lower, "<" + name, position)
        end = tag_end(text, start + 1 + len(name)) if start >= 0 else -1
        if end < 0:
            return
        yield text[start:end]
        position = end


def elements(text, name):
    lower = ascii_lower(text)
    start = find_tag(lower, "<" + name, 0)
    next_script = find_tag(lower, "<script", 0) if name != "script" else -1
    while start >= 0:
        if 0 <= next_script < start:
            bounds = element_bounds(text, lower, "script", next_script)
            if bounds is None:
                return
            position = bounds[2]
            next_script = find_tag(lower, "<script", position)
            if start < position:
                start = find_tag(lower, "<" + name, position)
            continue
        bounds = element_bounds(text, lower, name, start)
        if bounds is None:
            return
        open_end, close, position = bounds
        yield Element(text[start:open_end], text[open_end:close])
        start = find_tag(lower, "<" + name, position)
        if 0 <= next_script < position:
            next_script = find_tag(lower, "<script", position)


def skip(pattern, text, position, end):
    match = pattern.match(text, position, end)
    return match.end() if match else position


def parse_attributes(tag, position):
    end = len(tag) - 1
    found = []
    while True:
        position = skip(ATTRIBUTE_GAP, tag, position, end)
        if position >= end:
            return found
        name = ATTRIBUTE_NAME.match(tag, position, end)
        if name is None:
            position += 1
            continue
        position = skip(SPACE, tag, name.end(), end)
        if position >= end or tag[position] != "=":
            found.append(Attribute(name.group(), None))
            continue
        position = skip(SPACE, tag, position + 1, end)
        if position < end and tag[position] in "\"'":
            closing = tag.find(tag[position], position + 1, end)
            closing = end if closing < 0 else closing
            found.append(Attribute(name.group(), tag[position + 1:closing]))
            position = closing + 1
            continue
        value = UNQUOTED_VALUE.match(tag, position, end)
        found.append(Attribute(name.group(), value.group() if value else ""))
        position = value.end() if value else position + 1


def tag_attributes(tag):
    name = TAG_NAME.match(tag, 1)
    found = {}
    for attribute in parse_attributes(tag, name.end()) if name else []:
        found.setdefault(attribute.name.lower(), html.unescape(attribute.value or ""))
    return found


def camel(name):
    head, *rest = name.split("-")
    return head + "".join(word.capitalize() for word in rest)


def attribute_text(name, value):
    if value is None:
        return f" {name}"
    return f' {name}="{value.replace(chr(34), "&quot;")}"'


def compact_value(name, value):
    if value is None or len(value) <= LONG_VALUE:
        return value
    if name in COLLAPSED_ATTRIBUTES or ascii_lower(value.lstrip()[:5]) == "data:":
        return f"…{len(value)} chars"
    return value


def dimension(value):
    if isinstance(value, bool):
        return None
    if isinstance(value, str) and DIMENSION.fullmatch(value.strip()):
        value = int(value.strip())
    if isinstance(value, int) and 0 < value <= MAX_DIMENSION:
        return value
    return None


def parse_bundle(document, budget):
    blocks = {}
    for element in elements(document, "script"):
        kind = tag_attributes(element.open_tag).get("type", "")
        if kind in ("__bundler/manifest", "__bundler/template"):
            blocks.setdefault(kind, element.content)
    if len(blocks) < 2:
        return None
    manifest = load_json(blocks["__bundler/manifest"], "__bundler/manifest")
    template = load_json(blocks["__bundler/template"], "__bundler/template")
    if not isinstance(manifest, dict) or not isinstance(template, str):
        raise ArtifactError("the bundle's manifest is not an object or its template is not a string")
    return Manifest(manifest, budget), clean(template)


def document_title(document):
    for element in elements(document, "title"):
        return " ".join(html.unescape(element.content).split())
    return ""


def board_frames(template):
    frames = []
    seen = set()
    repeats = 0
    for tag in open_tags(template, "iframe"):
        attributes = tag_attributes(tag)
        source = attributes.get("src", "")
        if not source.startswith("about:blank#"):
            continue
        entry_id = source.split("#", 1)[1]
        if entry_id in seen:
            repeats += 1
            continue
        if len(frames) == MAX_PAGES:
            raise LimitError(f"the board has more than {MAX_PAGES} pages")
        seen.add(entry_id)
        title = " ".join(attributes.get("title", "").split())
        frames.append(Frame(entry_id, title, dimension(attributes.get("width")), dimension(attributes.get("height"))))
    if repeats:
        report(f"{repeats} frames repeat a page already listed; each page is unpacked once")
    return frames


def resolve_frame(manifest, frame, budget):
    name = f"frame '{table_cell(frame.title)}' ({table_cell(frame.entry_id[:80])})"
    mime = manifest.mime(frame.entry_id)
    if mime != "text/html":
        report(f"{name}: {f'entry is {table_cell(mime)}' if mime else 'no manifest entry'}, skipped")
        return None
    try:
        document = clean(manifest.read(frame.entry_id, keep=False).decode("utf-8", errors="replace"))
        bundle = parse_bundle(document, budget)
    except LimitError:
        raise
    except ArtifactError as error:
        report(f"{name}: {error}, skipped")
        return None
    page_manifest, template = bundle or (Manifest({}, budget), document)
    title = frame.title or document_title(template) or "page"
    return Page(title, template, page_manifest, frame.width, frame.height)


def body_content(template):
    lower = ascii_lower(template)
    start = find_tag(lower, "<body", 0)
    open_end = tag_end(template, start + 5) if start >= 0 else -1
    if open_end < 0:
        return template
    close = lower.rfind("</body")
    return template[open_end:close] if close >= open_end else template[open_end:]


def clean_markup(body, references):
    lower = ascii_lower(body)
    full = []
    compact = []
    position = 0
    while position < len(body):
        start = body.find("<", position)
        if start < 0:
            start = len(body)
        full.append(body[position:start])
        compact.append(body[position:start])
        if start == len(body):
            break
        if body.startswith("<!--", start):
            close = body.find("-->", start + 4)
            position = len(body) if close < 0 else close + 3
            continue
        closing = body.startswith("</", start)
        name = TAG_NAME.match(body, start + (2 if closing else 1))
        if name is None:
            if body.startswith(("<!", "<?"), start):
                bracket = body.find(">", start)
                position = len(body) if bracket < 0 else bracket + 1
            else:
                full.append("<")
                compact.append("<")
                position = start + 1
            continue
        tag_name = ascii_lower(name.group())
        end = tag_end(body, name.end())
        if end < 0:
            break
        position = end
        if closing:
            if tag_name not in DROPPED_TAGS:
                full.append(f"</{name.group()}>")
                compact.append(f"</{name.group()}>")
            continue
        if tag_name in DROPPED_ELEMENTS:
            bounds = element_bounds(body, lower, tag_name, start)
            position = len(body) if bounds is None else bounds[2]
            continue
        if tag_name in DROPPED_TAGS:
            continue
        tag_full, tag_compact = references.rewrite_tag(body[start:end])
        full.append(tag_full)
        compact.append(tag_compact)
    return tidy("".join(full)), tidy("".join(compact))


def tidy(markup):
    lines = (line.rstrip() for line in markup.splitlines())
    return "\n".join(line for line in lines if line.strip())


def strip_comments(css):
    pieces = []
    position = 0
    while True:
        start = css.find("/*", position)
        if start < 0:
            pieces.append(css[position:])
            return "".join(pieces)
        pieces.append(css[position:start])
        end = css.find("*/", start + 2)
        if end < 0:
            return "".join(pieces)
        position = end + 2


def split_font_faces(css, fonts):
    lower = ascii_lower(css)
    pieces = []
    position = 0
    while True:
        start = lower.find("@font-face", position)
        if start < 0:
            pieces.append(css[position:])
            return "".join(pieces)
        pieces.append(css[position:start])
        brace = css.find("{", start)
        close = css.find("}", brace) if brace >= 0 else -1
        if close < 0:
            return "".join(pieces)
        block = css[brace + 1:close]
        family = FONT_FAMILY.search(block)
        weight = FONT_WEIGHT.search(block)
        if family:
            fonts.setdefault(family.group(1).strip(), set()).add(weight.group(1).strip() if weight else "normal")
        position = close + 1


def preview_size(page):
    for element in elements(page.template, "script"):
        attributes = tag_attributes(element.open_tag)
        if attributes.get("type", "").strip().lower() != "text/x-dc" or not attributes.get("data-props"):
            continue
        try:
            props = json.loads(attributes["data-props"])
        except (ValueError, RecursionError):
            continue
        preview = props.get("$preview") if isinstance(props, dict) else None
        if isinstance(preview, dict):
            width, height = dimension(preview.get("width")), dimension(preview.get("height"))
            if width and height:
                return f"{width}×{height}"
    if page.width and page.height:
        return f"{page.width}×{page.height} (frame)"
    return "unknown"


def image_assets(manifest, prefix):
    assets = {}
    taken = set()
    for entry_id in manifest.entries:
        mime = manifest.mime(entry_id)
        if not (isinstance(entry_id, str) and ENTRY_ID.fullmatch(entry_id) and mime.startswith("image/")):
            continue
        stem = f"{prefix}-{entry_id}"
        extension = mimetypes.guess_extension(mime) or ".bin"
        file_name = f"{stem}{extension}"
        counter = 2
        while file_name.casefold() in taken:
            file_name = f"{stem}-{counter}{extension}"
            counter += 1
        taken.add(file_name.casefold())
        assets[entry_id] = file_name
    return assets


def slug(title):
    words = re.findall(r"\w+", title.lower())
    return "-".join(words)[:SLUG_LENGTH].strip("-_") or "page"


def render(number, width, page):
    prefix = f"{number:0{width}d}"
    fonts = {}
    css = "\n".join(split_font_faces(strip_comments(element.content), fonts) for element in elements(page.template, "style"))
    references = References(page.manifest, image_assets(page.manifest, prefix), f"page '{table_cell(page.title)}'")
    css = "\n".join(line.strip() for line in references.rewrite_urls(css).splitlines() if line.strip())
    css = css.replace("</", "<\\/")
    markup, compact = clean_markup(body_content(page.template), references)
    preview = preview_size(page)
    page_html = (
        "<!DOCTYPE html>\n<html><head>\n<meta charset=\"utf-8\">\n"
        f"<meta http-equiv=\"Content-Security-Policy\" content=\"{CSP}\">\n"
        f"<title>{html.escape(page.title)}</title>\n<style>\n{css}\n</style>\n</head>\n<body>\n{markup}\n</body></html>\n"
    )
    page_text = f"{page.title}\npreview: {preview}\n\n<style>\n{css}\n</style>\n\n{compact}\n"
    return Rendered(f"{prefix}-{slug(page.title)}", page.title, page_html, page_text, preview, fonts, references.files)


def unpack(document, artifact, output):
    budget = Budget()
    bundle = parse_bundle(document, budget)
    manifest, template = bundle or (Manifest({}, budget), document)
    board_title = document_title(template) or artifact.stem
    frames = board_frames(template)
    writer = Writer(output)
    width = max(2, len(str(len(frames))))
    for frame in frames:
        page = resolve_frame(manifest, frame, budget)
        if page is not None:
            writer.add(render(len(writer.rows) + 1, width, page))
    if not writer.rows:
        if frames:
            report("no frame resolved; the board itself is unpacked as one page")
        writer.add(render(1, width, Page(board_title or "page", template, manifest, None, None)))
    writer.finish(artifact.name, board_title)
    return len(writer.rows)


def input_problem(artifact):
    try:
        if not artifact.exists():
            return "no such file"
        if not artifact.is_file():
            return "not a regular file"
        size = artifact.stat().st_size
    except OSError as error:
        return str(error)
    if size > MAX_INPUT_BYTES:
        return f"larger than {MAX_INPUT_BYTES} bytes"
    return None


def main():
    args = parse_args()
    artifact = Path(args.artifact)
    output = Path(args.output)
    problem = input_problem(artifact)
    if problem:
        report(f"{artifact}: {problem}")
        return 2
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        report(f"{output}: give a new or empty directory")
        return 2
    try:
        document = artifact.read_bytes().decode("utf-8", errors="replace")
        count = unpack(document, artifact, output)
    except (OSError, ArtifactError) as error:
        report(f"{artifact}: {error}")
        return 1
    print(f"{count} pages -> {output / 'index.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
