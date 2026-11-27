#!/bin/bash
# PreToolUse guard for Bash during app and screen captures: keeps other apps' secrets out of the transcript.
# 1. The macOS domain com.apple.java.util.prefs is shared by every JVM app and holds their tokens. A command that
#    names it may only export it to a file or import it ("defaults export|import com.apple.java.util.prefs <file>").
# 2. screencapture records whatever is on screen unless it is limited to one window: every screencapture in the
#    command needs -l<window id>.
# Exit 2 blocks the call and sends stderr to the agent. Written for bash 3.2.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

block() {
    echo "BLOCKED by capture-guard: $1" >&2
    exit 2
}

DOMAIN='com\.apple\.java\.util\.prefs'
if printf '%s' "$COMMAND" | grep -Eq "$DOMAIN"; then
    REST=$(printf '%s' "$COMMAND" | sed -E "s#defaults[[:space:]]+(export|import)[[:space:]]+$DOMAIN[[:space:]]+[^[:space:];|&-][^[:space:];|&]*##g")
    if printf '%s' "$REST" | grep -Eq "$DOMAIN"; then
        block "the shared JVM preferences domain may only be exported to a file or imported; diff the files and print key names only."
    fi
fi

# Each command segment that runs screencapture must carry -l (alone or in a flag group, e.g. -xol123).
printf '%s\n' "$COMMAND" | tr ';|&' '\n\n\n' | while IFS= read -r SEGMENT; do
    case "$SEGMENT" in
        *screencapture*)
            if ! printf '%s' "$SEGMENT" | grep -Eq '(^|[[:space:]])-[A-Za-z]*l'; then
                echo "BLOCKED by capture-guard: screencapture without -l<window id> records other windows; capture one window." >&2
                exit 2
            fi
            ;;
    esac
done || exit 2
exit 0
