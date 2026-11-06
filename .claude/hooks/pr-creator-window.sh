#!/bin/bash
# SubagentStart and SubagentStop (Codex only; Claude Code names the agent in every PreToolUse input):
# opens and closes the window in which git-guard.sh lets a Codex session commit or push, because Codex
# gives PreToolUse no agent field. Writes <scratch>/window-<agent_type>-<session_id> when the agent starts
# and deletes it when it stops; git-guard.sh ignores a window older than 2 hours, the backstop for a stop
# that never fires. The matcher in .codex/hooks.json names the committing agents of
# .claude/docs/subagents.md; change them together. Never blocks; exits 0 outside a git repository.
# Written for bash 3.2.

INPUT=$(cat)
field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }

EVENT=$(field .hook_event_name)
case "$EVENT" in
    SubagentStart|SubagentStop) ;;
    *) exit 0 ;;
esac
AGENT=$(field .agent_type)
SESSION=$(field .session_id)
[ -z "$AGENT" ] || [ -z "$SESSION" ] && exit 0
AGENT=$(printf '%s' "$AGENT" | tr -c 'A-Za-z0-9._-' '_')
SESSION=$(printf '%s' "$SESSION" | tr -c 'A-Za-z0-9._-' '_')
CWD=$(field .cwd)
[ -d "$CWD" ] || CWD=.

SCRATCH=$(bash "$(dirname "$0")/scratch.sh" "$CWD") || exit 0
WINDOW="$SCRATCH/window-$AGENT-$SESSION"
if [ "$EVENT" = SubagentStart ]; then
    touch "$WINDOW"
else
    rm -f "$WINDOW"
fi
exit 0
