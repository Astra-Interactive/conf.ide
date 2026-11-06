#!/bin/bash
# Stop (Claude Code and Codex): refuses to end a turn that leaves this task's files uncommitted. A file is
# the task's when `git status --porcelain=v1 -uall -z` lists it and <scratch>/dirty-<session_id>, the
# session-start baseline of dirty-baseline.sh, does not. The turn ends anyway when <scratch>/no-commit
# exists (written by no-commit-marker.sh, the new-feature skill or the agent; ignored and removed after
# 24 hours), when asked-<session_id> exists, when the baseline is missing, when stop-blocks-<session_id>
# already holds three blocks, or when the last assistant message ends with "?". That message is
# last_assistant_message, otherwise the last "type": "assistant" entry of the transcript_path JSONL
# (Claude Code); when neither is readable the turn ends. A stop inside a subagent (agent_id present) is
# not checked. A block appends a line to stop-blocks-<session_id>, which turn-reset.sh clears, and exits 2
# with the reason on stderr. Exits 0 outside a git repository. Written for bash 3.2.

INPUT=$(cat)
field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }

EVENT=$(field .hook_event_name)
[ -n "$EVENT" ] && [ "$EVENT" != Stop ] && exit 0
[ -n "$(field .agent_id)" ] && exit 0
SESSION=$(field .session_id)
[ -z "$SESSION" ] && exit 0
SESSION=$(printf '%s' "$SESSION" | tr -c 'A-Za-z0-9._-' '_')
CWD=$(field .cwd)
[ -d "$CWD" ] || CWD=.
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
SCRATCH=$(bash "$(dirname "$0")/scratch.sh" "$CWD") || exit 0

MARKER="$SCRATCH/no-commit"
if [ -e "$MARKER" ]; then
    [ -z "$(find "$MARKER" -mmin +1440 2>/dev/null)" ] && exit 0
    rm -f "$MARKER"
fi
[ -e "$SCRATCH/asked-$SESSION" ] && exit 0
[ -e "$SCRATCH/dirty-$SESSION" ] || exit 0
BLOCKS="$SCRATCH/stop-blocks-$SESSION"
[ -e "$BLOCKS" ] && [ "$(wc -l < "$BLOCKS")" -ge 3 ] && exit 0

IFS= read -r -d '' PROGRAM <<'PYTHON'
import json
import os
import subprocess
import sys
import time

LISTED = 50


def last_message(payload):
    message = payload.get("last_assistant_message")
    if isinstance(message, str):
        return message
    path = payload.get("transcript_path")
    if not isinstance(path, str):
        return None
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            lines = handle.readlines()
    except OSError:
        return None
    for line in reversed(lines):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        if not isinstance(entry, dict) or entry.get("type") != "assistant":
            continue
        message = entry.get("message")
        content = message.get("content") if isinstance(message, dict) else None
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            return "".join(block.get("text", "") for block in content
                           if isinstance(block, dict) and block.get("type") == "text")
        return None
    return None


def status_paths(raw):
    entries, paths, i = raw.split(b"\0"), [], 0
    while i < len(entries):
        entry = entries[i]
        i += 1
        if len(entry) < 4:
            continue
        paths.append(entry[3:])
        if b"R" in entry[:2] or b"C" in entry[:2]:
            if i < len(entries):
                paths.append(entries[i])
                i += 1
    return paths


try:
    payload = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
if not isinstance(payload, dict):
    sys.exit(0)
message = last_message(payload)
if message is None or message.rstrip().endswith("?"):
    sys.exit(0)

scratch, session = os.environ["SCRATCH"], os.environ["SESSION"]
with open(os.path.join(scratch, f"dirty-{session}"), "rb") as handle:
    known = set(status_paths(handle.read()))
result = subprocess.run(["git", "-C", os.environ["CWD"], "status", "--porcelain=v1", "-uall", "-z"],
                        capture_output=True)
if result.returncode != 0:
    sys.exit(0)
names = [path.decode("utf-8", "replace") for path in dict.fromkeys(status_paths(result.stdout))
         if path not in known]
if not names:
    sys.exit(0)

listed = ", ".join(names[:LISTED])
if len(names) > LISTED:
    listed += f", and {len(names) - LISTED} more"
with open(os.path.join(scratch, f"stop-blocks-{session}"), "a", encoding="utf-8") as handle:
    handle.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} {len(names)} file(s)\n")
print(f"Uncommitted files from this task: {listed}. Commit through pr-creator, or write the reason into "
      f"{scratch}/no-commit and end the turn.", file=sys.stderr)
sys.exit(2)
PYTHON

printf '%s' "$INPUT" | SCRATCH="$SCRATCH" SESSION="$SESSION" CWD="$CWD" python3 -I -c "$PROGRAM"
