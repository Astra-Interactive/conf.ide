#!/bin/bash
# PostToolUse on Write|Edit|MultiEdit (Claude Code) and on apply_patch (Codex): counts comment lines
# added to Kotlin or Rust files and reminds the agent of the comment rules. It never blocks.
# Written for bash 3.2.

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')

# FOUND holds one "path<TAB>count" line per file that received comment lines.
if [ "$TOOL" = apply_patch ]; then
    PATCH=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .tool_input.patch // .tool_input.input // empty')
    FOUND=$(printf '%s\n' "$PATCH" | awk '
        /^\*\*\* (Update|Add) File: / { sub(/^\*\*\* (Update|Add) File: /, ""); file = $0; next }
        /^\*\*\* / { next }
        /^\+/ && file ~ /\.(kt|kts|rs)$/ {
            line = substr($0, 2)
            if (line ~ /^[[:space:]]*(\/\/|\/\*\*|\*[[:space:]]|\/\/\/|\/\/!)/) n[file]++
        }
        END { for (f in n) printf "%s\t%d\n", f, n[f] }')
else
    FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
    case "$FILE" in
        *.kt|*.kts|*.rs) ;;
        *) exit 0 ;;
    esac
    ADDED=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // (.tool_input.edits // [] | map(.new_string) | join("\n")) // empty')
    [ -z "$ADDED" ] && exit 0
    COUNT=$(printf '%s\n' "$ADDED" | grep -c -E '^[[:space:]]*(//|/\*\*|\*[[:space:]]|///|//!)')
    FOUND=""
    [ "$COUNT" -gt 0 ] && FOUND=$(printf '%s\t%s' "$FILE" "$COUNT")
fi
[ -z "$FOUND" ] && exit 0

TOTAL=0
NAMES=""
RULES=""
while IFS=$'\t' read -r path count; do
    [ -z "$path" ] && continue
    TOTAL=$((TOTAL + count))
    NAMES="$NAMES, ${path##*/}"
    case "$path" in
        *.rs) case "$RULES" in *rustdoc*) ;; *) RULES="$RULES; clean-code.rs.md, rustdoc.rs.md" ;; esac ;;
        *)    case "$RULES" in *javadoc*) ;; *) RULES="$RULES; clean-code.kt.md section 8, javadoc.kt.md" ;; esac ;;
    esac
done <<EOF
$FOUND
EOF

MSG="comment-guard: $TOTAL comment line(s) written to ${NAMES#, }. Application code carries no doc comments; a comment says only why, never what (${RULES#; }). Re-read each one now and delete those that restate the code."
printf '%s' "$MSG" | jq -R '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: .}}'
exit 0
