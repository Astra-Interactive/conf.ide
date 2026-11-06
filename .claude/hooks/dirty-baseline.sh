#!/bin/bash
# SessionStart (Claude Code and Codex): records what is already dirty when the session starts, so that
# stop-guard.sh blames the task only for files that turn dirty later. Writes the output of
# `git status --porcelain=v1 -uall -z` (paths relative to the top level) to <scratch>/dirty-<session_id>,
# and only when that file is absent: a resumed session keeps its first baseline, so the agent's leftovers
# never become the user's. Never blocks; exits 0 outside a git repository. Written for bash 3.2.

INPUT=$(cat)
field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }

EVENT=$(field .hook_event_name)
[ -n "$EVENT" ] && [ "$EVENT" != SessionStart ] && exit 0
SESSION=$(field .session_id)
[ -z "$SESSION" ] && exit 0
SESSION=$(printf '%s' "$SESSION" | tr -c 'A-Za-z0-9._-' '_')
CWD=$(field .cwd)
[ -d "$CWD" ] || CWD=.

SCRATCH=$(bash "$(dirname "$0")/scratch.sh" "$CWD") || exit 0
BASELINE="$SCRATCH/dirty-$SESSION"
[ -e "$BASELINE" ] && exit 0

TMP="$BASELINE.$$"
if git -C "$CWD" status --porcelain=v1 -uall -z > "$TMP" 2>/dev/null; then
    mv -n "$TMP" "$BASELINE"
fi
rm -f "$TMP"
exit 0
