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
    "git [ -C path ] status|log|diff|show|blame|rev-parse|ls-files without --output, git branch --show-current, "
    "git symbolic-ref [--short] [one ref], git remote -v, git worktree list [--porcelain|-v|-z]; "
    "gh pr view|list|checks|diff, gh issue view|list, gh run view|list, gh api with GET only (no -X or --method "
    "other than GET, no -f, -F, --field, --raw-field or --input); ksrc; head, tail, wc, cut, jq, tr; sort without "
    "-o, --output or --compress-program; uniq with at most one file; sed -n '<N>p' or '<N>,<M>p' [files]; "
    "awk [-F sep] [-v var=value] '<program>' [files], the program without system, getline, close, fflush, |, > "
    "or @; ls, pwd, which, echo, true; date [+format] [-u] without -s or --set"
)
READONLY_SYNTAX = (
    "Options are checked after quote removal. A $NAME or ${NAME} parameter or an unquoted *, ?, [ or leading ^ "
    "appears only in the arguments of echo, ls, head, tail, wc, grep, cut, tr, jq and which; other ${...} forms "
    "and variable assignments are not allowed. |, ||, &&, ; and newlines inside quotes do not separate commands. "
    "No $(...), backticks, <(...), >(...), =(...), unquoted ( ) { }, # comment, here-document (<<) or lone &. "
    "No output redirection except 2>&1 and >&2 as whole words, no tee, nothing else."
)
PROJECT_ROOT_CD = (
    "cd <project root> only directly before && {command}, the root being the git top level of this repository, "
    "a worktree or another repository, written out as git -C <directory> rev-parse --show-toplevel prints it, "
    "quoted when it holds spaces or glob characters; no other cd"
)
READONLY_MODES = {
    "research": "",
    "gradle": "; ./gradlew, and <project root>/gradlew from a directory of that root's working tree, without -I, "
    "--init-script, -p, --project-dir, -c, --settings-file, -b, --build-file, -g, --gradle-user-home, "
    "--include-build or --project-cache-dir; "
    + PROJECT_ROOT_CD.format(command="./gradlew")
    + "; rg (without --pre or --hostname-bin) and grep",
    "cargo": "; cargo [ +toolchain ] build|check|test|clippy|klibs-rules, cargo [ +toolchain ] fmt --check, with no "
    "argument starting with --fix, --config, --manifest-path, --target-dir, --artifact-dir, --out-dir or -Z; "
    + PROJECT_ROOT_CD.format(command="cargo")
    + "; rg (without --pre or --hostname-bin) and grep",
    "docker": "; docker compose config (without -o or --output), docker compose ps, docker ps|logs|inspect, "
    "docker network ls|inspect",
    "docs": "; rg (without --pre or --hostname-bin), grep, and find without -exec, -execdir, -ok, -okdir, "
    "-delete, -fprint, -fprint0, -fprintf or -fls",
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
    "Agent": "the multi-agent tools (spawn_agent, wait_agent, send_message, followup_task, list_agents, "
             "interrupt_agent), for the helpers the helper ownership policy in subagents.md "
             "gives this agent and no other role",
    "SendMessage": "messages to its helpers",
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
            f"{READONLY_COMMANDS}{extra}. {READONLY_SYNTAX}"
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
