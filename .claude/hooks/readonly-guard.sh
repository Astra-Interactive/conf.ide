#!/bin/bash
# PreToolUse guard for read-only agents: lets Bash run inspection commands only.
# Usage in agent frontmatter: readonly-guard.sh [research|gradle|cargo|docker|docs]
# docs is research plus rg, grep and find for searching documents; find may not run, write or delete.
# Exit 2 blocks the call and sends stderr to the agent. Written for bash 3.2.
# A lone & (background command) is blocked. git also runs as "git -C <path> <subcommand>" for the same subcommands; a plain NAME=value part (no command
# on it) is allowed except for names that change how later commands run. The allowlist is repeated as text in
# .codex/generate-agents.py; change both together.

MODE="${1:-research}"
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0

block() {
    echo "BLOCKED by readonly-guard ($MODE): '$1'. This agent only inspects; it does not change files, git state or servers." >&2
    exit 2
}

# Command and process substitution run commands that the allowlist below never sees.
case "$COMMAND" in
    *'$('*|*'`'*|*'<('*|*'>('*) block "$COMMAND" ;;
esac

# Redirections write files. 2>&1 and >&2 are the only ones allowed.
STRIPPED=$(printf '%s' "$COMMAND" | sed -e 's/2>&1//g' -e 's/>&2//g')
case "$STRIPPED" in
    *">"*|*"tee "*) block "$COMMAND" ;;
esac

# A lone & starts a background command the splitter below would not see. && is the only allowed use of &.
case "$(printf '%s' "$STRIPPED" | sed 's/&&//g')" in
    *"&"*) block "$COMMAND" ;;
esac

is_readonly_git() {
    case "$1" in
        git\ status*|git\ log*|git\ diff*|git\ show*|git\ blame*|git\ rev-parse*|git\ ls-files*|git\ branch\ --show-current*|git\ symbolic-ref*|git\ remote\ -v*|git\ worktree\ list*) return 0 ;;
    esac
    return 1
}

# NAME=value, value a plain word or one quoted string, no command after it.
ASSIGNMENT_RE='^([A-Za-z_][A-Za-z0-9_]*)=([A-Za-z0-9_./:@%+,=~$\{\}-]*|"[^"&]*"|'"'"'[^'"'"'&]*'"'"')$'
# git -C <path> <rest>: the path is one word that does not start with a dash.
GIT_C_RE='^git[[:space:]]+-C[[:space:]]+[^-[:space:]][^[:space:]]*[[:space:]]+(.*)$'

OLD_IFS="$IFS"
IFS=$'\n'
for part in $(printf '%s' "$COMMAND" | sed -E 's/\|\||&&|;|\|/\n/g'); do
    part=$(printf '%s' "$part" | sed -E 's/^[[:space:]]+//')
    [ -z "$part" ] && continue
    if [[ "$part" =~ $GIT_C_RE ]]; then
        is_readonly_git "git ${BASH_REMATCH[1]}" || block "$part"
        continue
    fi
    if [[ "$part" =~ $ASSIGNMENT_RE ]]; then
        case "${BASH_REMATCH[1]}" in
            PATH|IFS|HOME|SHELL|ENV|BASH_ENV|PAGER|EDITOR|VISUAL|PROMPT_COMMAND|PS4|BASHOPTS|SHELLOPTS|GIT_*|LD_*|DYLD_*|CARGO*|RUST*) block "$part" ;;
        esac
        continue
    fi
    case "$part" in
        git\ *) is_readonly_git "$part" || block "$part" ;;
        gh\ pr\ view*|gh\ pr\ list*|gh\ pr\ checks*|gh\ pr\ diff*|gh\ issue\ view*|gh\ issue\ list*|gh\ run\ view*|gh\ run\ list*|gh\ api\ *) ;;
        ksrc\ *|ksrc) ;;
        head|head\ *|tail|tail\ *|wc|wc\ *|sort|sort\ *|uniq|uniq\ *|cut\ *|jq|jq\ *|tr\ *|awk\ *|sed\ -n*|sed\ -E\ *) ;;
        ls\ *|ls|pwd|which\ *|echo\ *|date*|true) ;;
        ./gradlew*|gradle\ *) [ "$MODE" = gradle ] || block "$part" ;;
        cargo\ *)
            [ "$MODE" = cargo ] || block "$part"
            case "$part" in
                *--fix*) block "$part" ;;
            esac
            cargo_args="${part#cargo }"
            case "$cargo_args" in
                +*) cargo_args="${cargo_args#* }" ;;
            esac
            case "$cargo_args" in
                build|build\ *|check|check\ *|test|test\ *|clippy|clippy\ *) ;;
                fmt\ *)
                    case " $cargo_args " in
                        *" --check "*) ;;
                        *) block "$part" ;;
                    esac
                    ;;
                *) block "$part" ;;
            esac
            ;;
        rg\ *|grep\ *)
            case "$part" in
                rg\ *--pre*) block "$part" ;;
            esac
            [ "$MODE" = gradle ] || [ "$MODE" = cargo ] || [ "$MODE" = docs ] || block "$part"
            ;;
        find\ *)
            case "$part" in
                *-exec*|*-ok*|*-delete*|*-fprint*|*-fls*) block "$part" ;;
            esac
            [ "$MODE" = docs ] || block "$part"
            ;;
        docker\ compose\ config*|docker\ compose\ ps*|docker\ ps*|docker\ logs*|docker\ inspect*|docker\ network\ ls*|docker\ network\ inspect*) [ "$MODE" = docker ] || block "$part" ;;
        *) block "$part" ;;
    esac
done
IFS="$OLD_IFS"
exit 0
