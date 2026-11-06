#!/usr/bin/env python3
"""Generates .claude/rules/{kotlin,rust,code,xml}.md from .claude/docs.

The documents in .claude/docs are the source of truth; the generated directory is not in git.
Each rules file is a `paths:` frontmatter followed by its group's documents, concatenated in
alphabetical order under a heading with the file name. Claude Code loads a file when a matching
path is read or edited; the Codex docs-context.sh hook serves the same file with the frontmatter
stripped. generate.sh runs this at session start; a write is a temp file renamed over the target.
"""

import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
DOCS = ROOT / ".claude" / "docs"
RULES = ROOT / ".claude" / "rules"
HEADER = "# Generated from .claude/docs by .claude/hooks/generate-rules.py; edit the docs and rerun.\n"

CODE_DOCS = ("arch-package.md", "arch-domain.md", "arch-context.md", "codebase-memory.md", "region.md")

GROUPS = {
    "kotlin": (["**/*.{kt,kts}"], lambda p: p.name.endswith(".kt.md")),
    "rust": (["**/*.rs", "**/Cargo.toml"], lambda p: p.name.endswith(".rs.md")),
    "code": (["**/*.{kt,kts,rs}", "**/Cargo.toml"], lambda p: p.name in CODE_DOCS),
    "xml": (["**/*.xml"], lambda p: p.name == "xmlstarlet.md"),
}


def render(paths: list[str], docs: list[Path]) -> str:
    out = ["---\n", "paths:\n"]
    out.extend(f'  - "{pattern}"\n' for pattern in paths)
    out.append("---\n")
    out.append(HEADER)
    for doc in docs:
        out.append(f"\n# {doc.name}\n\n")
        out.append(doc.read_text())
        if not out[-1].endswith("\n"):
            out.append("\n")
    return "".join(out)


def write_atomic(target: Path, content: str) -> bool:
    if target.exists() and target.read_text() == content:
        return False
    fd, tmp = tempfile.mkstemp(dir=target.parent, prefix=f".{target.name}.", suffix=".tmp")
    with os.fdopen(fd, "w") as handle:
        handle.write(content)
    os.chmod(tmp, 0o644)
    os.replace(tmp, target)
    return True


def main() -> int:
    RULES.mkdir(parents=True, exist_ok=True)
    for name, (paths, belongs) in GROUPS.items():
        docs = sorted(p for p in DOCS.glob("*.md") if belongs(p))
        if not docs:
            print(f"no documents for group {name}", file=sys.stderr)
            return 1
        target = RULES / f"{name}.md"
        if write_atomic(target, render(paths, docs)):
            print(f"wrote {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
