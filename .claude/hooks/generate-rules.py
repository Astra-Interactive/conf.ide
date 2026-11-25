#!/usr/bin/env python3
"""Generates .claude/rules/{kotlin,rust,code,xml}.md as conditional pointers.

The documents in .claude/docs are the source of truth; the generated directory is not in git.
AGENTS.md owns loading conditions and .claude/docs owns the rule bodies. Claude Code loads
the pointers when a matching path is read or edited. Codex uses AGENTS.md directly.
generate.sh runs this at session start; a write is a temp file renamed over the target.
"""

import os
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
DOCS = ROOT / ".claude" / "docs"
RULES = ROOT / ".claude" / "rules"
HEADER = "# Generated from AGENTS.md by .claude/hooks/generate-rules.py; edit the index and rerun.\n"

CODE_DOCS = ("arch-package.md", "arch-domain.md", "arch-context.md", "codebase-memory.md", "region.md")
# The linter checks these completely, so AGENTS.md lists them as Linter-enforced instead of path rules.
LINTER_DOCS = (
    "data-class-default-values.kt.md",
    "imports.kt.md",
    "no-it.kt.md",
    "serial-name.kt.md",
    "closure-naming.rs.md",
    "imports.rs.md",
)

GROUPS = {
    "kotlin": (["**/*.{kt,kts}"], lambda p: p.name.endswith(".kt.md")),
    "rust": (["**/*.rs", "**/Cargo.toml"], lambda p: p.name.endswith(".rs.md")),
    "code": (["**/*.{kt,kts,rs}", "**/Cargo.toml"], lambda p: p.name in CODE_DOCS),
    "xml": (["**/*.xml"], lambda p: p.name == "xmlstarlet.md"),
}


def render(paths: list[str], docs: list[Path], pointers: dict[str, str]) -> str:
    out = ["---\n", "paths:\n"]
    out.extend(f'  - "{pattern}"\n' for pattern in paths)
    out.append("---\n")
    out.append(HEADER)
    out.append("\nRead the linked rule sources whose conditions match the task. "
               "Reuse unchanged instructions already read in this agent.\n")
    for doc in docs:
        out.append(pointers[doc.name] + "\n")
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
    index = (ROOT / "AGENTS.md").read_text()
    pointers = {}
    for line in index.splitlines():
        match = re.match(r"^- \[.*?\]\(\.claude/docs/([^/]+\.md)\) — (.+)$", line)
        if match:
            pointers[match.group(1)] = line
    RULES.mkdir(parents=True, exist_ok=True)
    for name, (paths, belongs) in GROUPS.items():
        docs = sorted(p for p in DOCS.glob("*.md") if belongs(p) and p.name not in LINTER_DOCS)
        if not docs:
            print(f"no documents for group {name}", file=sys.stderr)
            return 1
        missing = [doc.name for doc in docs if doc.name not in pointers]
        if missing:
            print(f"missing AGENTS.md loading conditions: {', '.join(missing)}", file=sys.stderr)
            return 1
        target = RULES / f"{name}.md"
        if write_atomic(target, render(paths, docs, pointers)):
            print(f"wrote {target.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
