#!/usr/bin/env python3
"""Checks that every reference from one instruction document to another resolves.

A reference is a document name in backticks (`arch-package.md`), optionally followed by a section
name and an item number (`arch-package.md`, Units 4). Numbered items and section names are the
stable ids of the rules: an item's number is never reused or shifted, so a reference that stops
resolving means a rule was renumbered, renamed or removed. Run from anywhere:
    python3 .claude/hooks/check-refs.py [more files or directories to scan ...]
Scans .claude/docs, .claude/skills, .claude/agents, CLAUDE.md and AGENTS.md of this checkout plus
the given paths (a linter README, a decision record). Exit 1 lists each reference that does not
resolve.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
DOCS = ROOT / ".claude" / "docs"
REFERENCE = re.compile(r"`(?P<doc>[a-z0-9][a-z0-9.-]*\.md)`(?P<comma>,\s+)?")
NUMBER = re.compile(r"\s+(\d+)(?:[–-](\d+))?")
HEADING = re.compile(r"^#{2,4}\s+(.*?)\s*$")
ITEM = re.compile(r"^(\d+)\.\s")


def sections_of(document: Path) -> dict[str, set[int]]:
    sections: dict[str, set[int]] = {}
    current = None
    for line in document.read_text().splitlines():
        heading = HEADING.match(line)
        if heading:
            current = heading.group(1).replace("`", "")
            sections[current] = set()
            continue
        item = ITEM.match(line)
        if item and current is not None:
            sections[current].add(int(item.group(1)))
    return sections


def find_section(sections: dict[str, set[int]], tail: str) -> str | None:
    matching = [name for name in sections if tail.startswith(name)]
    return max(matching, key=len) if matching else None


def scanned_files(extra: list[str]) -> list[Path]:
    roots = [DOCS, ROOT / ".claude" / "skills", ROOT / ".claude" / "agents", ROOT / "CLAUDE.md", ROOT / "AGENTS.md"]
    roots.extend(Path(path) for path in extra)
    files: list[Path] = []
    for root in roots:
        if root.is_dir():
            files.extend(sorted(root.rglob("*.md")))
        elif root.is_file():
            files.append(root)
    return files


def main() -> int:
    known = {document.name: sections_of(document) for document in DOCS.glob("*.md")}
    problems: list[str] = []
    for file in scanned_files(sys.argv[1:]):
        text = file.read_text()
        strict = DOCS in file.parents or "skills" in file.parts
        for match in REFERENCE.finditer(text):
            line = text.count("\n", 0, match.start()) + 1
            where = f"{file}:{line}"
            document = match.group("doc")
            if document not in known:
                if strict and re.search(r"\.(kt|rs)\.md$|^arch-", document):
                    problems.append(f"{where}: `{document}` is not a document of .claude/docs")
                continue
            if not match.group("comma"):
                continue
            tail = " ".join(text[match.end():match.end() + 120].replace("`", "").split())
            section = find_section(known[document], tail)
            if section is None:
                word = tail.split(" ", 1)[0].strip(".,;:)")
                if word[:1].isupper() and word in {name.split()[0] for name in known[document]}:
                    problems.append(f"{where}: `{document}` has no section that starts \"{tail[:40]}\"")
                continue
            number = NUMBER.match(tail[len(section):])
            if not number or not known[document][section]:
                continue
            first = int(number.group(1))
            last = int(number.group(2) or first)
            missing = [item for item in range(first, last + 1) if item not in known[document][section]]
            if missing:
                gone = ", ".join(str(item) for item in missing)
                problems.append(f"{where}: `{document}`, {section} has no item {gone}")
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
