#!/usr/bin/env python3
"""Generates .codex/agents/*.toml from .claude/agents/*.md.

The markdown agents are the source of truth; the generated directory is not in git. The SessionStart
hook .claude/hooks/generate.sh runs this (and .claude/hooks/generate-rules.py for the rules) at every
session start and link-consumer.sh runs it before linking a repository.
Codex has no per-agent tool list, hooks or sandbox, so the guards a Claude agent gets from its
frontmatter (block-edits.sh, readonly-guard.sh, tools) are written into developer_instructions as
text. The allowlist below mirrors .claude/hooks/readonly-guard.sh; change both together.
"""

import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / ".claude" / "agents"
TARGET = ROOT / ".codex" / "agents"
HEADER = "# Generated from .claude/agents/{name}.md by .codex/generate-agents.py; edit the .md and rerun.\n"

MODELS = {
    "opus": "gpt-6-astra",
    "claude-opus-5-5": "gpt-6-astra",
    "claude-fable-5-1": "gpt-6-astra",
    "sonnet": "gpt-6.1-sol",
    "haiku": "gpt-6-luna",
    "inherit": None,
}

READONLY_COMMANDS = (
    "git [ -C path ] status, log, diff, show, blame, rev-parse, ls-files, branch --show-current, symbolic-ref, "
    "remote -v, worktree list; a plain NAME=value variable assignment on its own (not before a command, not "
    "PATH, IFS, HOME, SHELL, ENV, BASH_ENV, PAGER, EDITOR, VISUAL, PROMPT_COMMAND, PS4, BASHOPTS, SHELLOPTS, "
    "GIT_*, LD_*, DYLD_*, CARGO*, RUST*); no $(...), backticks, <(...) or lone &; gh pr view|list|checks|diff, gh issue view|list, gh run view|list, gh api; "
    "ksrc; head, tail, wc, sort, uniq, cut, jq, tr, awk, sed -n, sed -E; ls, pwd, which, echo, date, true"
)
READONLY_MODES = {
    "research": "",
    "gradle": "; ./gradlew, rg (without --pre) and grep",
    "cargo": "; cargo [ +toolchain ] build|check|test|clippy, cargo [ +toolchain ] fmt --check (all Cargo commands reject arguments containing --fix, including --fix=...); rg (without --pre) and grep",
    "docker": "; docker compose config|ps, docker ps|logs|inspect, docker network ls|inspect",
    "docs": "; rg (without --pre), grep, and find without -exec, -execdir, -ok, -okdir, -delete, -fprint or -fls",
}

TOOL_NAMES = {
    "Read": "file reads",
    "Edit": "apply_patch",
    "Write": "apply_patch",
    "MultiEdit": "apply_patch",
    "Bash": "shell",
    "LSP": "the lsp MCP server",
    "WebSearch": "web search",
    "WebFetch": "web fetch",
}
MCP_SERVERS = {
    "codebase-memory-mcp": "codebase-memory-mcp",
    "claude_ai_Atlassian_Rovo": "atlassian",
}


def split_frontmatter(text: str) -> tuple[str, str]:
    match = re.match(r"\A---\n(.*?)\n---\n(.*)\Z", text, re.DOTALL)
    if not match:
        raise ValueError("no frontmatter")
    return match.group(1), match.group(2)


def top_level_fields(frontmatter: str) -> dict[str, str]:
    fields = {}
    for line in frontmatter.splitlines():
        match = re.match(r"^([A-Za-z]+):\s*(.*)$", line)
        if match:
            fields[match.group(1)] = unquote(match.group(2).strip())
    return fields


def unquote(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        inner = value[1:-1]
        return inner.replace('\\"', '"') if value[0] == '"' else inner
    return value


def tool_scope(tools: str) -> str:
    plain, servers = [], {}
    for tool in [t.strip() for t in tools.split(",") if t.strip()]:
        match = re.match(r"^mcp__([^_].*?)__(.+)$", tool)
        if match:
            server = MCP_SERVERS.get(match.group(1), match.group(1))
            servers.setdefault(server, []).append(match.group(2))
        else:
            name = TOOL_NAMES.get(tool, tool)
            if name not in plain:
                plain.append(name)
    parts = plain + [f"{server} ({', '.join(names)})" for server, names in servers.items()]
    return ", ".join(parts)


def guards(fields: dict[str, str], frontmatter: str) -> list[str]:
    lines = []
    if "block-edits.sh" in frontmatter:
        lines.append(
            "- You do not create, edit, delete or move files. apply_patch is off limits; "
            "you report, and another agent applies."
        )
    mode = re.search(r"readonly-guard\.sh\"?\s+(\w+)", frontmatter)
    if mode:
        extra = READONLY_MODES.get(mode.group(1), "")
        lines.append(
            "- The shell is for inspection only. Allowed commands: "
            f"{READONLY_COMMANDS}{extra}. No output redirection except 2>&1, no tee, nothing else."
        )
    if "tools" in fields:
        lines.append(
            f"- Tool scope: {tool_scope(fields['tools'])}. Use nothing outside this scope, "
            "even when the harness offers more."
        )
    skills = fields.get("skills")
    if skills:
        names = ", ".join(s.strip() for s in skills.strip("[]").split(","))
        lines.append(f"- Skills to use: {names} (installed under .agents/skills).")
    return lines


def toml_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render(name: str, fields: dict[str, str], frontmatter: str, body: str) -> str:
    model = fields.get("model", "inherit")
    if model not in MODELS:
        raise ValueError(f"unknown model {model!r}")
    guard_lines = guards(fields, frontmatter)
    instructions = body.strip() + "\n"
    if guard_lines:
        instructions = (
            "Codex runs this agent in the parent's sandbox. The guards below are instructions, "
            "not a sandbox, and they bind you all the same:\n\n" + "\n".join(guard_lines) + "\n\n" + instructions
        )
    if "'''" in instructions:
        raise ValueError("body contains ''' which cannot be embedded in a TOML literal string")
    out = [HEADER.format(name=name)]
    out.append(f"name = {toml_string(name)}\n")
    out.append(f"description = {toml_string(fields['description'])}\n")
    if MODELS[model]:
        out.append(f"model = {toml_string(MODELS[model])}\n")
    if "effort" in fields:
        out.append(f"model_reasoning_effort = {toml_string(fields['effort'])}\n")
    out.append(f"developer_instructions = '''\n{instructions}'''\n")
    tools = fields.get("tools", "")
    if tools and "Bash" not in [t.strip() for t in tools.split(",")]:
        out.append("\n[features]\nshell_tool = false\n")
    return "".join(out)


def main() -> int:
    TARGET.mkdir(parents=True, exist_ok=True)
    generated = set()
    for source in sorted(SOURCE.glob("*.md")):
        frontmatter, body = split_frontmatter(source.read_text())
        fields = top_level_fields(frontmatter)
        name = fields["name"]
        content = render(name, fields, frontmatter, body)
        tomllib.loads(content)
        target = TARGET / f"{name}.toml"
        if not target.exists() or target.read_text() != content:
            target.write_text(content)
            print(f"wrote {target.relative_to(ROOT)}")
        generated.add(target)
    for stale in TARGET.glob("*.toml"):
        if stale not in generated and stale.read_text().startswith("# Generated from .claude/agents/"):
            stale.unlink()
            print(f"removed {stale.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
