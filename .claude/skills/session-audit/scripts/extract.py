"""Turn every Claude Code, Codex and Kimi session on this machine into a compact markdown digest.

Usage: python3 -I extract.py <out_dir> [--claude-root DIR] [--codex-root DIR] [--kimi-root DIR]
Writes <out_dir>/digests/<tool>/<name>.md and <out_dir>/manifest.tsv. The roots default to where each
tool keeps its sessions under the home directory. Raw session files are only read.
"""
import argparse
import glob
import json
import os
import re
from datetime import datetime, timezone

HOME = os.path.expanduser("~")
CLAUDE_ROOT = os.path.join(HOME, ".claude", "projects")
CODEX_ROOT = os.path.join(HOME, ".codex", "sessions")
KIMI_ROOT = os.path.join(HOME, ".kimi-code", "sessions")
USER_LIMIT = 2500
ASSISTANT_LIMIT = 280
FINAL_LIMIT = 1500
TOOL_ARG_LIMIT = 140
ERROR_LIMIT = 260
SUBAGENT_PROMPT_LIMIT = 1500

# (pattern, keeps its first group): a kept group is the label in front of the secret.
SECRET_PATTERNS = [
    (re.compile(r"(sk-[A-Za-z0-9_\-]{16,})"), False),
    (re.compile(r"(gh[pousr]_[A-Za-z0-9]{20,})"), False),
    (re.compile(r"(xox[abprs]-[A-Za-z0-9\-]{10,})"), False),
    (re.compile(r"(sntrys_[A-Za-z0-9_\-]{20,})"), False),
    (re.compile(r"(?i)(bearer\s+)[A-Za-z0-9._\-]{20,}"), True),
    (re.compile(r"(?i)((?:password|passwd|token|secret|api[_-]?key)\s*[=:]\s*)[^\s\"',]{6,}"), True),
]
NOISE_BLOCKS = [
    re.compile(r"<system-reminder>.*?</system-reminder>", re.S),
    re.compile(r"<hook_result[^>]*>.*?</hook_result>", re.S),
    re.compile(r"<INSTRUCTIONS>.*?</INSTRUCTIONS>", re.S),
    re.compile(r"<environment_context>.*?</environment_context>", re.S),
    re.compile(r"<user_instructions>.*?</user_instructions>", re.S),
    re.compile(r"<permissions instructions>.*?</permissions instructions>", re.S),
]
# A shell startup file that sources a missing file prints this line before every command's output.
SHELL_STARTUP_NOISE = re.compile(
    r"[^\s:\"']*/\.(?:zprofile|zshrc|zshenv|zlogin|bash_profile|bashrc|profile):[^\n\"']*?"
    r"no such file or directory: [^\s\"'\\]+(?:\\n|\n)?"
)
COMMAND_TEXT = re.compile(r"\A\s*<(?:command-name|local-command-stdout)>")
COMMAND_NAME = re.compile(r"<command-name>\s*([^<\s]+)\s*</command-name>")
EXIT_NONZERO = re.compile(r'"exit_code"\s*:\s*[1-9]|Process exited with code [1-9]')
ERROR_HINT = re.compile(
    r"(?i)(^error|\berror:|exit code:? [1-9]|exited with code [1-9]|command failed|failed with|"
    r"permission denied|not permitted|denied|rejected|traceback|exception|no such file|"
    r"doesn't want to proceed|was blocked|blocked by|timed out|BUILD FAILED|FAILURE:)"
)


def redact(text):
    for pattern, keeps_label in SECRET_PATTERNS:
        if keeps_label:
            text = pattern.sub(lambda m: m.group(1) + "<redacted>", text)
        else:
            text = pattern.sub("<redacted>", text)
    return text


def clean(text):
    for block in NOISE_BLOCKS:
        text = block.sub("", text)
    return text.strip()


def cut(text, limit):
    text = redact(text.strip())
    if len(text) > limit:
        return text[:limit] + f" …[+{len(text) - limit} chars]"
    return text


def one_line(text, limit):
    return cut(" ".join(text.split()), limit)


def iso(ts):
    if ts is None:
        return ""
    if isinstance(ts, (int, float)):
        if ts > 1e12:
            ts = ts / 1000
        return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M")
    return str(ts)[:16]


def tool_call_line(name, args):
    if isinstance(args, str):
        try:
            args = json.loads(args)
        except (ValueError, TypeError):
            return f"{name}: {one_line(args, TOOL_ARG_LIMIT)}"
    if not isinstance(args, dict):
        return name
    if name in ("Agent", "Task"):
        keys = ("subagent_type", "model", "description", "run_in_background")
        head = " ".join(f"{k}={args.get(k)}" for k in keys if args.get(k) is not None)
        return f"{name}({head}) prompt: {one_line(str(args.get('prompt', '')), 300)}"
    if name == "Skill":
        return f"Skill({args.get('skill')}) {one_line(str(args.get('args', '')), 100)}"
    for key in ("command", "cmd", "file_path", "path", "pattern", "query", "url", "skill", "questions"):
        if key in args:
            return f"{name}: {one_line(str(args[key]), TOOL_ARG_LIMIT)}"
    return f"{name}: {one_line(json.dumps(args, ensure_ascii=False), TOOL_ARG_LIMIT)}"


class Digest:
    def __init__(self, tool, source, kind):
        self.tool = tool
        self.source = source
        self.kind = kind
        self.cwd = ""
        self.session_id = ""
        self.started = ""
        self.ended = ""
        self.lines = []
        self.user_count = 0
        self.error_count = 0
        self.interrupt_count = 0
        self.api_error_count = 0
        self.tool_counts = {}
        self.subagents = []
        self.skills = []
        self.first_prompt = ""
        self.last_assistant = ""
        self.title = ""
        self.run = []
        self.handback = ""
        self.note = ""
        self.command_names = []
        self.has_typed_prompt = False

    def flush(self):
        if not self.run:
            return
        names = {}
        for name, _ in self.run:
            names[name] = names.get(name, 0) + 1
        summary = ", ".join(f"{k}×{v}" if v > 1 else k for k, v in names.items())
        tail = " | ".join(one_line(line, 90) for _, line in self.run[-2:])
        self.lines.append(f"  - T [{summary}] {tail}")
        self.run = []

    def add(self, line):
        self.flush()
        self.lines.append(line)

    def touch(self, ts):
        if not ts:
            return
        stamp = iso(ts)
        if not self.started:
            self.started = stamp
        self.ended = stamp

    def user(self, text, ts=None, label="USER"):
        text = clean(text)
        if not text:
            return
        self.user_count += 1
        if COMMAND_TEXT.match(text):
            self.command_names.extend(COMMAND_NAME.findall(text))
        else:
            self.has_typed_prompt = True
        if not self.first_prompt:
            self.first_prompt = text
        if "[Request interrupted by user" in text:
            self.interrupt_count += 1
        self.add(f"\n**{label}** {iso(ts)}\n> " + cut(text, USER_LIMIT).replace("\n", "\n> "))

    def assistant(self, text):
        text = clean(text)
        if not text:
            return
        self.last_assistant = text
        self.add(f"- A: {one_line(text, ASSISTANT_LIMIT)}")

    def call(self, name, args):
        self.tool_counts[name] = self.tool_counts.get(name, 0) + 1
        line = tool_call_line(name, args)
        if name in ("Agent", "Task"):
            self.subagents.append(line[:200])
        if name == "Skill":
            self.skills.append(line[:120])
        if name == "SubagentHandback" and isinstance(args, dict):
            self.handback = str(args.get("message") or args.get("report") or json.dumps(args, ensure_ascii=False))
        if name in ("Agent", "Task", "Skill", "AskUserQuestion", "ExitPlanMode", "EnterPlanMode"):
            self.add(f"  - T {line}")
        else:
            self.run.append((name, line))

    def error(self, text, label="ERR"):
        self.error_count += 1
        line = f"  - **{label}** {one_line(clean(text), ERROR_LIMIT)}"
        if self.lines and self.lines[-1] == line and not self.run:
            self.lines[-1] = line + " (repeated)"
            return
        self.add(line)

    def event(self, text):
        self.add(f"  - **{text}**")

    def render(self):
        self.flush()
        tools = ", ".join(f"{k}×{v}" for k, v in sorted(self.tool_counts.items(), key=lambda kv: -kv[1])[:15])
        size_kb = os.path.getsize(self.source) // 1024 if os.path.exists(self.source) else 0
        head = [
            f"# {self.tool} {self.kind} {self.session_id}",
            f"- source: {self.source.replace(HOME, '~')}",
            f"- cwd: {self.cwd.replace(HOME, '~')}",
            f"- time: {self.started} → {self.ended} (UTC)",
            f"- size: {size_kb} KB; user msgs: {self.user_count}; tool errors: {self.error_count}; "
            f"interrupts: {self.interrupt_count}; api errors/retries: {self.api_error_count}",
        ]
        if self.title:
            head.append(f"- title: {self.title}")
        if self.note:
            head.append(f"- note: {self.note}")
        if tools:
            head.append(f"- tools: {tools}")
        if self.skills:
            head.append(f"- skills: {'; '.join(sorted(set(self.skills)))[:600]}")
        if self.kind == "subagent":
            body = [
                "\n## Prompt\n> " + cut(self.first_prompt, SUBAGENT_PROMPT_LIMIT).replace("\n", "\n> "),
                "\n## Errors and events",
                *[
                    line.replace("\n", " ")[:400]
                    for line in self.lines
                    if any(tag in line for tag in ("**ERR", "**API", "**INTERRUPT", "**REJECTED", "**SUBAGENT-FAILED"))
                    or "[Request interrupted" in line
                    or (line.startswith("\n**USER") and line is not self.lines[0])
                ],
                ("\n## Handback (SubagentHandback)\n> " + cut(self.handback, 3000).replace("\n", "\n> "))
                if self.handback
                else "\n## Final answer (last assistant text; no handback call)\n> "
                + cut(self.last_assistant, FINAL_LIMIT).replace("\n", "\n> "),
            ]
        else:
            body = ["\n## Timeline", *self.lines]
            if self.last_assistant:
                body.append("\n## Last assistant message\n> " + cut(self.last_assistant, FINAL_LIMIT).replace("\n", "\n> "))
        return "\n".join(head + body) + "\n"


def parse_claude(path, kind):
    digest = Digest("claude", path, kind)
    digest.session_id = os.path.basename(path).replace(".jsonl", "")
    for raw in open(path, errors="replace"):
        try:
            record = json.loads(raw)
        except ValueError:
            continue
        kind_ = record.get("type")
        if record.get("cwd") and not digest.cwd:
            digest.cwd = record["cwd"]
        if kind_ == "ai-title" and record.get("aiTitle"):
            digest.title = one_line(str(record.get("aiTitle")), 120)
        if kind_ == "summary" and record.get("summary"):
            digest.title = one_line(str(record.get("summary")), 120)
        ts = record.get("timestamp")
        if kind_ == "system":
            subtype = record.get("subtype", "")
            if subtype in ("api_error",) or record.get("level") == "error":
                digest.api_error_count += 1
                digest.error(str(record.get("content") or record.get("error") or subtype), "API")
            elif subtype == "compact_boundary":
                digest.event("COMPACTED")
            continue
        if kind_ not in ("user", "assistant"):
            continue
        digest.touch(ts)
        message = record.get("message") or {}
        content = message.get("content")
        if kind_ == "user":
            if record.get("isMeta"):
                continue
            if isinstance(content, str):
                digest.user(content, ts)
                continue
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "text":
                    digest.user(block.get("text", ""), ts)
                elif block.get("type") == "tool_result":
                    result = block.get("content")
                    if isinstance(result, list):
                        result = " ".join(x.get("text", "") for x in result if isinstance(x, dict))
                    result = str(result or "")
                    if block.get("is_error"):
                        label = "REJECTED" if "doesn't want to proceed" in result or "rejected" in result else "ERR"
                        digest.error(result, label)
        else:
            if record.get("isApiErrorMessage"):
                digest.api_error_count += 1
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "text":
                    text = block.get("text", "")
                    if record.get("isApiErrorMessage"):
                        digest.error(text, "API")
                    else:
                        digest.assistant(text)
                elif block.get("type") == "tool_use":
                    digest.call(block.get("name", "?"), block.get("input"))
    no_reply = not digest.last_assistant and not digest.tool_counts
    if kind == "session" and digest.command_names and not digest.has_typed_prompt and no_reply:
        digest.kind = "command-only"
        names = ", ".join(sorted(set(digest.command_names)))
        digest.note = f"only slash commands ({names}) and no reply; a script that polls a command leaves these"
    return digest


def codex_text(content):
    parts = []
    for block in content or []:
        if isinstance(block, dict) and block.get("type") in ("input_text", "output_text", "text"):
            parts.append(block.get("text", ""))
    return "\n".join(parts)


def parse_codex(path):
    digest = Digest("codex", path, "session")
    for raw in open(path, errors="replace"):
        try:
            record = json.loads(raw)
        except ValueError:
            continue
        kind_ = record.get("type")
        payload = record.get("payload") or {}
        ts = record.get("timestamp")
        if kind_ == "session_meta":
            if not digest.cwd:
                digest.cwd = payload.get("cwd", "")
            source = payload.get("source")
            if isinstance(source, dict) and "subagent" in source:
                digest.kind = "subagent"
            continue
        if kind_ != "response_item" and kind_ != "event_msg":
            continue
        digest.touch(ts)
        ptype = payload.get("type")
        if kind_ == "event_msg":
            if ptype == "turn_aborted":
                digest.interrupt_count += 1
                digest.event(f"INTERRUPT ({payload.get('reason')})")
            elif ptype == "error" or ptype == "stream_error":
                digest.api_error_count += 1
                digest.error(str(payload.get("message", "")), "API")
            continue
        if ptype == "message":
            role = payload.get("role")
            text = codex_text(payload.get("content"))
            if role == "user":
                stripped = text.lstrip()
                if stripped.startswith("# AGENTS.md instructions") or stripped.startswith("<environment_context>"):
                    continue
                digest.user(text, ts)
            elif role == "assistant":
                digest.assistant(text)
        elif ptype in ("function_call", "custom_tool_call"):
            digest.call(payload.get("name", "?"), payload.get("arguments") or payload.get("input"))
        elif ptype in ("function_call_output", "custom_tool_call_output"):
            output = payload.get("output")
            if isinstance(output, dict):
                output = output.get("content") or json.dumps(output)
            if isinstance(output, list):
                output = " ".join(x.get("text", "") for x in output if isinstance(x, dict))
            output = SHELL_STARTUP_NOISE.sub("", str(output or ""))
            if EXIT_NONZERO.search(output[:2000]) or ERROR_HINT.search(output[:600]):
                digest.error(output[:600])
        elif ptype == "agent_message":
            digest.call("agent_message", {"query": codex_text(payload.get("content"))[:200]})
    digest.session_id = os.path.basename(path).replace(".jsonl", "").split("-", 6)[-1]
    if not digest.lines and not digest.first_prompt:
        digest.kind = "unreadable"
        digest.note = "no readable content: the file holds only session_meta and an encrypted compaction record"
    return digest


def kimi_text(content, key="text"):
    parts = []
    for block in content or []:
        if isinstance(block, dict) and block.get("type") == "text":
            parts.append(block.get(key, ""))
    return "\n".join(parts)


def parse_kimi(path):
    parts = path.split(os.sep)
    agent = parts[-2]
    digest = Digest("kimi", path, "session" if agent == "main" else "subagent")
    digest.session_id = parts[-4] + ("" if agent == "main" else f"/{agent}")
    state = os.path.join(os.sep.join(parts[:-3]), "state.json")
    if os.path.exists(state):
        try:
            data = json.load(open(state))
            digest.cwd = data.get("cwd") or data.get("workDir") or data.get("workspace", {}).get("path", "") or parts[-5]
            digest.title = one_line(str(data.get("title") or ""), 120)
        except (ValueError, AttributeError):
            digest.cwd = parts[-5]
    else:
        digest.cwd = parts[-5]
    for raw in open(path, errors="replace"):
        try:
            record = json.loads(raw)
        except ValueError:
            continue
        kind_ = record.get("type")
        ts = record.get("time")
        if kind_ == "turn.prompt":
            digest.touch(ts)
            digest.user(kimi_text(record.get("input")), ts)
        elif kind_ == "turn.steer":
            text = kimi_text(record.get("input"))
            if text.startswith("Skill tool loaded instructions"):
                match = re.search(r'skill-loaded name="([^"]+)"', text)
                digest.skills.append(f"Skill({match.group(1) if match else '?'})")
            else:
                digest.user(text, ts, "USER (mid-turn)")
        elif kind_ == "turn.cancel":
            digest.interrupt_count += 1
            digest.event(f"INTERRUPT ({record.get('reason')})")
        elif kind_ == "turn.step.retrying":
            digest.api_error_count += 1
        elif kind_ in ("subagent.failed",):
            digest.error(json.dumps(record)[:300], "SUBAGENT-FAILED")
        elif kind_ == "interaction.request":
            request = record.get("request") or {}
            digest.event(f"APPROVAL? {request.get('toolName')}: {one_line(str(request.get('action', '')), 120)}")
        elif kind_ == "agent.message.appended":
            message = (record.get("message") or {}).get("message") or {}
            role = message.get("role")
            digest.touch(ts)
            if role == "assistant":
                digest.assistant(kimi_text(message.get("content")))
                for call in message.get("toolCalls") or []:
                    digest.call(call.get("name", "?"), call.get("arguments"))
            elif role == "tool":
                text = kimi_text(message.get("content"))
                if ERROR_HINT.search(text[:600]):
                    digest.error(text[:600])
    return digest


def safe_name(text):
    return re.sub(r"[^A-Za-z0-9._-]+", "_", text)[-150:]


def parse_args():
    parser = argparse.ArgumentParser(description="Turn Claude Code, Codex and Kimi sessions into markdown digests.")
    parser.add_argument("out_dir", help="audit folder; receives digests/<tool>/ and manifest.tsv")
    parser.add_argument("--claude-root", default=CLAUDE_ROOT, help=f"default {CLAUDE_ROOT}")
    parser.add_argument("--codex-root", default=CODEX_ROOT, help=f"default {CODEX_ROOT}")
    parser.add_argument("--kimi-root", default=KIMI_ROOT, help=f"default {KIMI_ROOT}")
    return parser.parse_args()


def main():
    args = parse_args()
    out = os.path.abspath(args.out_dir)
    manifest = []
    jobs = []
    for path in sorted(glob.glob(os.path.join(args.claude_root, "*", "*.jsonl"))):
        jobs.append(("claude", path, lambda p: parse_claude(p, "session")))
    for path in sorted(glob.glob(os.path.join(args.claude_root, "*", "*", "subagents", "*.jsonl"))):
        jobs.append(("claude", path, lambda p: parse_claude(p, "subagent")))
    for path in sorted(glob.glob(os.path.join(args.codex_root, "**", "*.jsonl"), recursive=True)):
        jobs.append(("codex", path, parse_codex))
    for path in sorted(glob.glob(os.path.join(args.kimi_root, "*", "*", "agents", "*", "wire.jsonl"))):
        jobs.append(("kimi", path, parse_kimi))
    for tool, path, parser in jobs:
        try:
            digest = parser(path)
        except Exception as error:  # a broken file is listed, not silently dropped
            manifest.append([tool, "broken", path.replace(HOME, "~"), "", "", "0", "0", "0", "0", repr(error)[:80]])
            continue
        if digest.kind == "subagent" and tool == "claude":
            rel = os.path.relpath(path, args.claude_root)
            name = safe_name(rel.replace(".jsonl", ""))
        else:
            name = safe_name(f"{os.path.basename(digest.cwd) or 'nocwd'}__{digest.started[:10]}__{digest.session_id}")
        target_dir = os.path.join(out, "digests", tool)
        os.makedirs(target_dir, exist_ok=True)
        target = os.path.join(target_dir, name + ".md")
        text = digest.render()
        with open(target, "w") as handle:
            handle.write(text)
        manifest.append([
            tool, digest.kind, os.path.relpath(target, out), digest.cwd.replace(HOME, "~"), digest.started,
            str(len(text) // 1024), str(digest.user_count), str(digest.error_count), str(digest.interrupt_count),
            digest.title,
        ])
    os.makedirs(out, exist_ok=True)
    with open(os.path.join(out, "manifest.tsv"), "w") as handle:
        handle.write("tool\tkind\tdigest\tcwd\tstarted\tdigest_kb\tuser_msgs\terrors\tinterrupts\ttitle\n")
        for row in manifest:
            handle.write("\t".join(row) + "\n")
    kinds = {}
    for row in manifest:
        kinds[row[1]] = kinds.get(row[1], 0) + 1
    print(f"{len(manifest)} sessions: " + ", ".join(f"{kind} {count}" for kind, count in sorted(kinds.items())))


if __name__ == "__main__":
    main()
