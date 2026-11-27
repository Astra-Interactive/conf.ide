#!/bin/bash
# PreToolUse guard for Bash during app and screen captures: keeps other apps' secrets out of the transcript.
# 1. The macOS domain com.apple.java.util.prefs is shared by every JVM app and holds their tokens. A command that
#    runs defaults, plutil or a file reader on it may only export it to a file or import it
#    ("defaults export|import com.apple.java.util.prefs <file>").
# 2. screencapture records whatever is on screen unless it is limited to one window: every screencapture run needs
#    -l<window id>.
# Only the command word of each segment is checked, so text that merely names them (grep, git commit -m) passes.
# Segments split on ; | & and newlines without quote parsing: a quoted string holding one of them and then the
# word screencapture reads as a run; pass such text through a file.
# Exit 2 blocks the call and sends stderr to the agent. Written for bash 3.2.

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

DOMAIN='com\.apple\.java\.util\.prefs'
READERS='defaults|plutil|cat|less|more|head|tail|strings|xxd|hexdump|od|bat|open'

printf '%s\n' "$COMMAND" | tr ';|&\n' '\n\n\n\n' | while IFS= read -r SEGMENT; do
    # The command word: the first word after env assignments, sudo, env, exec, time, nohup or a subshell paren.
    read -r -a WORDS <<< "$SEGMENT"
    WORD=""
    for CANDIDATE in "${WORDS[@]}"; do
        CANDIDATE=${CANDIDATE#(}
        case "$CANDIDATE" in
            ""|sudo|env|exec|time|nohup|command|*=*) continue ;;
        esac
        WORD=${CANDIDATE##*/}
        break
    done
    case "$WORD" in
        screencapture)
            if ! printf '%s' "$SEGMENT" | grep -Eq '(^|[[:space:]])-[A-Za-z]*l'; then
                echo "BLOCKED by capture-guard: screencapture without -l<window id> records other windows; capture one window." >&2
                exit 2
            fi
            ;;
    esac
    if printf '%s' "$WORD" | grep -Eqx "$READERS" && printf '%s' "$SEGMENT" | grep -Eq "$DOMAIN"; then
        REST=$(printf '%s' "$SEGMENT" | sed -E "s#defaults[[:space:]]+(export|import)[[:space:]]+$DOMAIN[[:space:]]+[^[:space:]-][^[:space:]]*##g")
        if printf '%s' "$REST" | grep -Eq "$DOMAIN"; then
            echo "BLOCKED by capture-guard: the shared JVM preferences domain may only be exported to a file or imported; diff the files and print key names only." >&2
            exit 2
        fi
    fi
done || exit 2
exit 0
