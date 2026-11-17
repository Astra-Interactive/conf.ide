#!/bin/bash
# PreToolUse guard for read-only agents: lets Bash run inspection commands only.
# Usage in agent frontmatter: readonly-guard.sh [research|gradle|cargo|docker|docs]
# docs is research plus rg, grep and find for searching documents; find may not run, write or delete.
# Exit 2 blocks the call and sends stderr to the agent. Written for bash 3.2; the command it checks runs in bash
# or zsh. The command is split into parts and words the way the shell quotes them, and every option check reads
# the word after quote removal. A word that expands a parameter or holds an unquoted glob character passes only
# in the arguments of echo, ls, head, tail, wc, grep, cut, tr, jq and which. gradle runs ./gradlew, or
# <project root>/gradlew when the call's working directory is in that root's working tree; gradle and cargo allow
# "cd <project root> && ./gradlew|cargo ..." with the root written out. A project root is the git top level of
# any working tree: this repository, a worktree or another repository. The allowlist is repeated as text in
# .codex/generate-agents.py; change both together.

MODE="${1:-research}"
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$COMMAND" ] && exit 0
# The directory the command starts in: the call's cwd, or the hook's own when the input names none.
CALL_DIR=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CALL_DIR" ] || CALL_DIR="$PWD"

block() {
    echo "BLOCKED by readonly-guard ($MODE): '$1'. This agent only inspects; it does not change files, git state or servers." >&2
    exit 2
}

# Command and process substitution, in bash and zsh, run commands that the checks below never see.
case "$COMMAND" in
    *'$('*|*'`'*|*'<('*|*'>('*|*'=('*) block "$COMMAND" ;;
esac

# Redirections write files. 2>&1 and >&2 are the only ones allowed, each as a whole word: >&2x writes the file 2x.
STRIPPED=$(printf '%s' "$COMMAND" | sed -E 's/(2>&1|>&2)([[:space:];|&]|$)/\2/g')
case "$STRIPPED" in
    *">"*|*"tee "*) block "$COMMAND" ;;
esac

# A lone & starts a background command. && is the only allowed use of &.
case "$(printf '%s' "$STRIPPED" | sed 's/&&//g')" in
    *"&"*) block "$COMMAND" ;;
esac

# A here-document body is text the shell does not run but the scanner below would read as commands. A
# here-string (<<<) is one word.
case "${COMMAND//<<</}" in
    *'<<'*) block "$COMMAND" ;;
esac

# Parameters expand only as $NAME or ${NAME}. The other ${...} forms assign (${x:=y}, zsh ${x::=y}), take zsh
# flags (${(e)x}) or nest quotes.
case "$(printf '%s' "$COMMAND" | sed -E 's/[$][{][A-Za-z_][A-Za-z0-9_]*[}]//g')" in
    *'${'*) block "$COMMAND" ;;
esac

# Prints the git top level of the working tree that holds directory $1. GIT_DIR and GIT_WORK_TREE are dropped:
# with them git names any directory a top level.
top_level() {
    env -u GIT_DIR -u GIT_WORK_TREE git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

# True when $1 is a project root: an absolute path that git prints as the top level of its working tree. A
# worktree or another repository passes; a subfolder, a symlink, a path with .. or a trailing slash and a
# directory outside git do not.
is_project_root() {
    case "$1" in
        /*) ;;
        *) return 1 ;;
    esac
    [ "$(top_level "$1")" = "$1" ]
}

BRACED_NAME_RE='^[$][{][A-Za-z_][A-Za-z0-9_]*[}]'
NAME_RE='^[$][A-Za-z_][A-Za-z0-9_]*'

# Ends the word being read, when there is one, and files it under the current part.
end_word() {
    if [ "$in_word" = 1 ]; then
        WORD_VALUE[${#WORD_VALUE[@]}]="$word"
        WORD_FLAGS[${#WORD_FLAGS[@]}]="$flags"
        WORD_PART[${#WORD_PART[@]}]=${#PARTS[@]}
    fi
    word=""
    in_word=0
    flags=""
}

# Ends the part that started at $part_start, without its leading whitespace, and the separator $1 after it.
end_part() {
    end_word
    local text_of_part="${text:part_start:index-part_start}"
    PARTS[${#PARTS[@]}]="${text_of_part#"${text_of_part%%[![:space:]]*}"}"
    SEPS[${#SEPS[@]}]="$1"
}

# Reads the $ at $index outside single quotes. $NAME, ${NAME}, $1, $@ and the like expand a parameter (flag d);
# a $ before whitespace, a separator, a closing quote or the end is a plain character.
read_dollar() {
    local rest="${text:index}"
    in_word=1
    if [[ "$rest" =~ $BRACED_NAME_RE ]] || [[ "$rest" =~ $NAME_RE ]]; then
        flags="${flags}d"
        step=${#BASH_REMATCH[0]}
        return
    fi
    case "$next" in
        ''|[[:space:]]|';'|'|'|'&'|'"') word="$word\$" ;;
        [0-9@*#?\$!-]) flags="${flags}d"; step=2 ;;
        *) flags="${flags}d"; word="$word\$" ;;
    esac
}

# Splits $1 into PARTS on |, ||, &&, ; and newline outside quotes (SEPS[i] is the separator after PARTS[i]) and
# into words: WORD_VALUE is a word after quote removal, WORD_PART its part, WORD_FLAGS holds d when it expands a
# parameter, g when it has an unquoted * ? [ or a leading ^, and q when it has quotes or escapes. Quotes
# follow the shell: '...' is literal, $'...' and "..." take backslash escapes, a backslash outside quotes
# escapes the next character. Returns 1 for what the guard does not model: an unclosed quote, an unquoted
# ( ) { }, a # that can start a comment, and a > or & outside 2>&1, >&2 and &&.
scan_command() {
    local text="$1" length=${#1} index=0 step char next previous separator quote="" part_start=0
    local word="" in_word=0 flags=""
    PARTS=()
    SEPS=()
    WORD_VALUE=()
    WORD_FLAGS=()
    WORD_PART=()
    while [ "$index" -lt "$length" ]; do
        char="${text:index:1}"
        next="${text:index+1:1}"
        step=1
        case "$quote" in
            single)
                if [ "$char" = "'" ]; then quote=""; else word="$word$char"; fi
                ;;
            ansi)
                if [ "$char" = '\' ]; then
                    word="$word$char$next"
                    flags="${flags}d"
                    step=2
                elif [ "$char" = "'" ]; then
                    quote=""
                else
                    word="$word$char"
                fi
                ;;
            double)
                if [ "$char" = '\' ]; then
                    case "$next" in
                        '$'|'`'|'"'|'\') word="$word$next"; step=2 ;;
                        $'\n') step=2 ;;
                        *) word="$word$char" ;;
                    esac
                elif [ "$char" = '"' ]; then
                    quote=""
                elif [ "$char" = '$' ]; then
                    read_dollar
                else
                    word="$word$char"
                fi
                ;;
            *)
                case "$char" in
                    ' '|$'\t')
                        end_word
                        ;;
                    $'\n'|';')
                        end_part "$char"
                        part_start=$((index + 1))
                        ;;
                    '|')
                        separator='|'
                        [ "$next" = '|' ] && separator='||'
                        end_part "$separator"
                        step=${#separator}
                        part_start=$((index + step))
                        ;;
                    '&')
                        [ "$next" = '&' ] || return 1
                        end_part '&&'
                        step=2
                        part_start=$((index + 2))
                        ;;
                    '>')
                        [ "$next" = '&' ] || return 1
                        case "${text:index+2:1}" in
                            1|2) ;;
                            *) return 1 ;;
                        esac
                        # Plain digits right before > name the descriptor; they are no argument.
                        if [ "$in_word" = 1 ] && [ -z "$flags" ] && [[ "$word" =~ ^[0-9]+$ ]]; then
                            in_word=0
                        fi
                        end_word
                        step=3
                        ;;
                    '<')
                        end_word
                        ;;
                    '('|')'|'{'|'}')
                        return 1
                        ;;
                    '#')
                        [ "$in_word" = 1 ] || return 1
                        previous="${text:index-1:1}"
                        case "$previous" in
                            [[:space:]]|';'|'|'|'&'|'<'|'>') return 1 ;;
                        esac
                        word="$word$char"
                        ;;
                    "'")
                        quote=single
                        flags="${flags}q"
                        in_word=1
                        ;;
                    '"')
                        quote=double
                        flags="${flags}q"
                        in_word=1
                        ;;
                    '\')
                        if [ "$next" != $'\n' ]; then
                            word="$word$next"
                            flags="${flags}q"
                            in_word=1
                        fi
                        step=2
                        ;;
                    '$')
                        case "$next" in
                            "'") quote=ansi; flags="${flags}q"; in_word=1; step=2 ;;
                            '"') quote=double; flags="${flags}q"; in_word=1; step=2 ;;
                            *) read_dollar ;;
                        esac
                        ;;
                    '*'|'?'|'[')
                        word="$word$char"
                        flags="${flags}g"
                        in_word=1
                        ;;
                    '^')
                        [ "$in_word" = 1 ] || flags="${flags}g"
                        word="$word$char"
                        in_word=1
                        ;;
                    *)
                        word="$word$char"
                        in_word=1
                        ;;
                esac
                ;;
        esac
        index=$((index + step))
    done
    [ -z "$quote" ] || return 1
    end_part ""
}

# W and WF: the words of part $1 and their flags.
part_words() {
    local k
    W=()
    WF=()
    for ((k = 0; k < ${#WORD_VALUE[@]}; k++)); do
        if [ "${WORD_PART[$k]}" = "$1" ]; then
            W[${#W[@]}]="${WORD_VALUE[$k]}"
            WF[${#WF[@]}]="${WORD_FLAGS[$k]}"
        fi
    done
}

# True when $1 is a cluster of short options (-abc) holding one of the letters in $2.
short_has() {
    case "$1" in
        --*|-) return 1 ;;
        -*)
            case "${1#-}" in
                *["$2"]*) return 0 ;;
            esac
            ;;
    esac
    return 1
}

# Every word literal: no parameter and no unquoted glob character, so the checks below see what the program sees.
require_static() {
    local k
    for ((k = 0; k < ${#W[@]}; k++)); do
        case "${WF[$k]}" in
            *d*|*g*) block "$part" ;;
        esac
    done
}

require_mode() {
    local allowed
    for allowed in "$@"; do
        [ "$MODE" = "$allowed" ] && return
    done
    block "$part"
}

# cd <project root> && ./gradlew|cargo: the root written out, the separator &&, and the mode's build command next.
check_cd() {
    require_mode gradle cargo
    [ "${#W[@]}" -eq 2 ] && is_project_root "${W[1]}" || block "$part"
    [ "${SEPS[$i]}" = '&&' ] || block "$part"
    part_words $((i + 1))
    case "$MODE:${W[0]:-}:${WF[0]:-}" in
        gradle:./gradlew:|gradle:./gradlew:q|cargo:cargo:|cargo:cargo:q) ;;
        *) block "$part" ;;
    esac
}

check_git() {
    local k=1 refs=0
    if [ "${W[1]:-}" = -C ]; then
        case "${W[2]:-}" in
            ''|-*) block "$part" ;;
        esac
        k=3
    fi
    local sub="${W[$k]:-}"
    k=$((k + 1))
    case "$sub" in
        status|log|diff|show|blame|rev-parse|ls-files)
            for ((; k < ${#W[@]}; k++)); do
                case "${W[$k]}" in
                    --output-indicator-*|--ours) ;;
                    --ou*) block "$part" ;;
                esac
            done
            ;;
        branch)
            [ "${#W[@]}" -eq $((k + 1)) ] && [ "${W[$k]}" = --show-current ] || block "$part"
            ;;
        symbolic-ref)
            for ((; k < ${#W[@]}; k++)); do
                case "${W[$k]}" in
                    --short) ;;
                    -*) block "$part" ;;
                    *) refs=$((refs + 1)) ;;
                esac
            done
            [ "$refs" -le 1 ] || block "$part"
            ;;
        remote)
            [ "${#W[@]}" -eq $((k + 1)) ] && [ "${W[$k]}" = -v ] || block "$part"
            ;;
        worktree)
            [ "${W[$k]:-}" = list ] || block "$part"
            for ((k = k + 1; k < ${#W[@]}; k++)); do
                case "${W[$k]}" in
                    --porcelain|-v|--verbose|-z) ;;
                    *) block "$part" ;;
                esac
            done
            ;;
        *)
            block "$part"
            ;;
    esac
}

# gh api reads only: GET, and no field or input that would send a body.
check_gh() {
    case "${W[1]:-} ${W[2]:-}" in
        "pr view"|"pr list"|"pr checks"|"pr diff"|"issue view"|"issue list"|"run view"|"run list") return ;;
    esac
    [ "${W[1]:-}" = api ] || block "$part"
    local k word method checks_method
    for ((k = 2; k < ${#W[@]}; k++)); do
        word="${W[$k]}"
        checks_method=0
        case "$word" in
            --field|--field=*|--raw-field|--raw-field=*|--input|--input=*)
                block "$part"
                ;;
            --method=*)
                method="${word#--method=}"
                checks_method=1
                ;;
            --method)
                k=$((k + 1))
                method="${W[$k]:-}"
                checks_method=1
                ;;
            --*)
                ;;
            -*)
                short_has "$word" fF && block "$part"
                if short_has "$word" X; then
                    method="${word#*X}"
                    if [ -z "$method" ]; then
                        k=$((k + 1))
                        method="${W[$k]:-}"
                    fi
                    checks_method=1
                fi
                ;;
        esac
        if [ "$checks_method" = 1 ]; then
            case "$method" in
                GET|get) ;;
                *) block "$part" ;;
            esac
        fi
    done
}

check_sort() {
    local k
    for ((k = 1; k < ${#W[@]}; k++)); do
        case "${W[$k]}" in
            --o*|--co*) block "$part" ;;
        esac
        short_has "${W[$k]}" o && block "$part"
    done
}

# uniq [options] [input]: a second operand is the output file.
check_uniq() {
    local k files=0 options=1
    for ((k = 1; k < ${#W[@]}; k++)); do
        if [ "$options" = 1 ]; then
            case "${W[$k]}" in
                --) options=0; continue ;;
                -f|-s|-w|--skip-fields|--skip-chars|--check-chars) k=$((k + 1)); continue ;;
                -?*) continue ;;
            esac
        fi
        files=$((files + 1))
    done
    [ "$files" -le 1 ] || block "$part"
}

SED_RANGE_RE='^[0-9]+(,([0-9]+|[$]))?p$'

# sed -n '<N>p' or '<N>,<M>p' [files]: a sed script can write (w, W) and run commands (e).
check_sed() {
    local k
    [ "${#W[@]}" -ge 3 ] && [ "${W[1]}" = -n ] && [[ "${W[2]}" =~ $SED_RANGE_RE ]] || block "$part"
    for ((k = 3; k < ${#W[@]}; k++)); do
        case "${W[$k]}" in
            -*) block "$part" ;;
        esac
    done
}

# awk [-F sep] [-v var=value] '<program>' [operands]: the program may not run commands, pipe, write or load.
check_awk() {
    local k=1
    while [ "$k" -lt "${#W[@]}" ]; do
        case "${W[$k]}" in
            --) k=$((k + 1)); break ;;
            -F|-v) k=$((k + 2)) ;;
            -F?*|-v?*) k=$((k + 1)) ;;
            -*) block "$part" ;;
            *) break ;;
        esac
    done
    [ "$k" -lt "${#W[@]}" ] || block "$part"
    case "${W[$k]}" in
        *system*|*getline*|*close*|*fflush*|*'|'*|*'>'*|*'@'*) block "$part" ;;
    esac
    for ((k = k + 1; k < ${#W[@]}; k++)); do
        case "${W[$k]}" in
            -?*) block "$part" ;;
        esac
    done
}

# date prints; -s and --set change the clock, and a bare operand sets it on BSD.
check_date() {
    local k
    for ((k = 1; k < ${#W[@]}; k++)); do
        case "${W[$k]}" in
            --s*) block "$part" ;;
            +*) ;;
            -*) short_has "${W[$k]}" s && block "$part" ;;
            *) block "$part" ;;
        esac
    done
}

check_rg() {
    local k
    for ((k = 1; k < ${#W[@]}; k++)); do
        case "${W[$k]}" in
            --pre*|--hostname-bin*) block "$part" ;;
        esac
    done
}

check_find() {
    local k
    for ((k = 1; k < ${#W[@]}; k++)); do
        case "${W[$k]}" in
            -exec*|-ok*|-delete|-fprint*|-fls) block "$part" ;;
        esac
    done
}

# Gradle options that load another build, init script, settings file or Gradle home.
check_gradle() {
    local k
    for ((k = 1; k < ${#W[@]}; k++)); do
        case "${W[$k]}" in
            --init-script*|--project-dir*|--settings-file*|--build-file*|--gradle-user-home*|--include-build*|--project-cache-dir*)
                block "$part"
                ;;
            --*|-D*|-P*) ;;
            -*) short_has "${W[$k]}" Ipcbg && block "$part" ;;
        esac
    done
}

check_cargo() {
    local k=1 check=0
    case "${W[1]:-}" in
        +*)
            [[ "${W[1]}" =~ ^[+][A-Za-z0-9._-]+$ ]] || block "$part"
            k=2
            ;;
    esac
    local sub="${W[$k]:-}"
    for ((k = k + 1; k < ${#W[@]}; k++)); do
        case "${W[$k]}" in
            --fix*|--config*|--manifest-path*|--target-dir*|--artifact-dir*|--out-dir*|-Z*) block "$part" ;;
            --check) check=1 ;;
        esac
    done
    case "$sub" in
        build|check|test|clippy|klibs-rules) ;;
        fmt) [ "$check" = 1 ] || block "$part" ;;
        *) block "$part" ;;
    esac
}

check_docker() {
    local k
    case "${W[1]:-} ${W[2]:-}" in
        "compose config")
            for ((k = 3; k < ${#W[@]}; k++)); do
                case "${W[$k]}" in
                    --output|--output=*) block "$part" ;;
                esac
                short_has "${W[$k]}" o && block "$part"
            done
            ;;
        "compose ps"|"network ls"|"network inspect") ;;
        *)
            case "${W[1]:-}" in
                ps|logs|inspect) ;;
                *) block "$part" ;;
            esac
            ;;
    esac
}

scan_command "$COMMAND" || block "$COMMAND"
for ((i = 0; i < ${#PARTS[@]}; i++)); do
    part="${PARTS[$i]}"
    part_words "$i"
    [ "${#W[@]}" -eq 0 ] && continue
    case "${WF[0]}" in
        *d*|*g*) block "$part" ;;
    esac
    case "${W[0]}" in
        echo|ls|head|tail|wc|cut|tr|jq|which|pwd|true) continue ;;
        grep) require_mode gradle cargo docs; continue ;;
    esac
    require_static
    case "${W[0]}" in
        /*/gradlew)
            require_mode gradle
            # Gradle builds the directory it starts in, whichever wrapper runs it: the wrapper is the one of
            # the tree the call starts in.
            if [ "$(top_level "$CALL_DIR")" = "${W[0]%/gradlew}" ]; then
                check_gradle
                continue
            fi
            ;;
    esac
    case "${W[0]}" in
        cd) check_cd ;;
        git) check_git ;;
        gh) check_gh ;;
        ksrc) ;;
        sort) check_sort ;;
        uniq) check_uniq ;;
        sed) check_sed ;;
        awk) check_awk ;;
        date) check_date ;;
        rg) require_mode gradle cargo docs; check_rg ;;
        find) require_mode docs; check_find ;;
        ./gradlew) require_mode gradle; check_gradle ;;
        cargo) require_mode cargo; check_cargo ;;
        docker) require_mode docker; check_docker ;;
        *) block "$part" ;;
    esac
done
exit 0
