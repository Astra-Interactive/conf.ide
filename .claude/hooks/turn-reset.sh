#!/bin/bash
# UserPromptSubmit (Claude Code and Codex): starts a new turn for stop-guard.sh by deleting
# <scratch>/asked-<session_id> and <scratch>/stop-blocks-<session_id>. A prompt that carries stop-guard's
# own block message is left alone: Codex turns a Stop block into a continuation prompt, and resetting the
# counter on it would let stop-guard block forever. Never blocks; exits 0 outside a git repository.
# Written for bash 3.2.

INPUT=$(cat)
field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }

EVENT=$(field .hook_event_name)
[ -n "$EVENT" ] && [ "$EVENT" != UserPromptSubmit ] && exit 0
SESSION=$(field .session_id)
[ -z "$SESSION" ] && exit 0
SESSION=$(printf '%s' "$SESSION" | tr -c 'A-Za-z0-9._-' '_')
case "$(field .prompt)" in
    *"Uncommitted files from this task:"*) exit 0 ;;
esac
CWD=$(field .cwd)
[ -d "$CWD" ] || CWD=.

SCRATCH=$(bash "$(dirname "$0")/scratch.sh" "$CWD") || exit 0
rm -f "$SCRATCH/asked-$SESSION" "$SCRATCH/stop-blocks-$SESSION"
exit 0
