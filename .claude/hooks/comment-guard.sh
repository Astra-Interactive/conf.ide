#!/bin/bash
# PostToolUse on Write|Edit|MultiEdit: counts comment lines added to a Kotlin or Rust file and
# reminds the agent of the comment rules. It never blocks. Written for bash 3.2.

INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
case "$FILE" in
    *.kt|*.kts|*.rs) ;;
    *) exit 0 ;;
esac

ADDED=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // (.tool_input.edits // [] | map(.new_string) | join("\n")) // empty')
[ -z "$ADDED" ] && exit 0

COUNT=$(printf '%s\n' "$ADDED" | grep -c -E '^[[:space:]]*(//|/\*\*|\*[[:space:]]|///|//!)')
[ "$COUNT" -eq 0 ] && exit 0

case "$FILE" in
    *.rs) RULES="clean-code.rs.md, rustdoc.rs.md" ;;
    *)    RULES="clean-code.kt.md section 8, javadoc.kt.md" ;;
esac

MSG="comment-guard: $COUNT comment line(s) written to ${FILE##*/}. Application code carries no doc comments; a comment says only why, never what ($RULES). Re-read each one now and delete those that restate the code."
printf '%s' "$MSG" | jq -R '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: .}}'
exit 0
