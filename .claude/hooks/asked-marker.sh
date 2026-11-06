#!/bin/bash
# PreToolUse on AskUserQuestion (Claude Code only; Codex has no such tool): touches
# <scratch>/asked-<session_id>, so that stop-guard.sh lets a turn that asked the user a question end with
# uncommitted files. turn-reset.sh deletes the marker at the next prompt. Never blocks; exits 0 outside a
# git repository. Written for bash 3.2.

INPUT=$(cat)
field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }

EVENT=$(field .hook_event_name)
[ -n "$EVENT" ] && [ "$EVENT" != PreToolUse ] && exit 0
TOOL=$(field .tool_name)
[ -n "$TOOL" ] && [ "$TOOL" != AskUserQuestion ] && exit 0
SESSION=$(field .session_id)
[ -z "$SESSION" ] && exit 0
SESSION=$(printf '%s' "$SESSION" | tr -c 'A-Za-z0-9._-' '_')
CWD=$(field .cwd)
[ -d "$CWD" ] || CWD=.

SCRATCH=$(bash "$(dirname "$0")/scratch.sh" "$CWD") || exit 0
touch "$SCRATCH/asked-$SESSION"
exit 0
