#!/bin/bash
# UserPromptSubmit (Claude Code and Codex): keeps <scratch>/no-commit in step with what the user says about
# committing. Each line of the prompt is classified in Python, because bash grep is locale-bound for
# Cyrillic: negative when it says not to commit ("не коммить", "don't commit", "without committing",
# "no commits"), positive when it asks for a commit ("закоммить", "commit it", "commit now") and is not
# negative, otherwise ignored. The last classified line wins: a negative one writes no-commit with that
# line as the reason, a positive one deletes it. stop-guard.sh reads the marker. Never blocks; exits 0
# outside a git repository. Written for bash 3.2.

INPUT=$(cat)
EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)
[ -n "$EVENT" ] && [ "$EVENT" != UserPromptSubmit ] && exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -d "$CWD" ] || CWD=.

SCRATCH=$(bash "$(dirname "$0")/scratch.sh" "$CWD") || exit 0

IFS= read -r -d '' PROGRAM <<'PYTHON'
import json
import os
import re
import sys

NEGATIVE = re.compile(
    r"не\s+(за)?коммит|don[’']?t commit|do not commit|without commit(ting)?|no commits?(\s|$)",
    re.IGNORECASE,
)
POSITIVE = re.compile(r"(^|\W)(закоммить|закоммитить|commit (it|now|this|the))", re.IGNORECASE)

try:
    prompt = json.load(sys.stdin).get("prompt")
except ValueError:
    sys.exit(0)
if not isinstance(prompt, str):
    sys.exit(0)

verdict = None
for line in prompt.splitlines():
    if NEGATIVE.search(line):
        verdict = ("negative", line.strip())
    elif POSITIVE.search(line):
        verdict = ("positive", line.strip())

marker = os.path.join(os.environ["SCRATCH"], "no-commit")
if verdict is None:
    sys.exit(0)
if verdict[0] == "negative":
    with open(marker, "w", encoding="utf-8") as handle:
        handle.write(f"user: {verdict[1]}\n")
elif os.path.exists(marker):
    os.remove(marker)
PYTHON

printf '%s' "$INPUT" | SCRATCH="$SCRATCH" python3 -I -c "$PROGRAM"
exit 0
