#!/bin/bash
# Links every consumer repository under the given directories to this conf.ide checkout:
#   link-consumer.sh <directory> [<directory> ...]
#
# A directory with .git is a repository; the search does not go inside a repository, nor into a
# symlinked directory, node_modules, build, target or vendor. This checkout is skipped.
#
# Runs the generator first, then ensures these absolute-target symlinks in each repository:
#   CLAUDE.md, AGENTS.md
#   .claude/{agents,docs,hooks,rules,skills,settings.json}
#   .codex/{agents,hooks.json}
# Whatever is in the way is replaced: a stale link, a file or a directory, tracked in the consumer's
# git or not. The old AGENTS.kt.md and AGENTS.rs.md links are removed, and their lines dropped from
# the consumer's .gitignore. Idempotent; prints only what it changed. The owner commits each
# consumer. Written for bash 3.2.

set -u

CONF=$(cd "$(dirname "$0")" && pwd)
CONF_PHYSICAL=$(cd "$CONF" && pwd -P)
LINKS="CLAUDE.md AGENTS.md .claude/agents .claude/docs .claude/hooks .claude/rules .claude/skills .claude/settings.json .codex/agents .codex/hooks.json"
STALE="AGENTS.kt.md AGENTS.rs.md"

find_repositories() {
    local directory="$1" child
    if [ -e "$directory/.git" ]; then
        printf '%s\n' "$directory"
        return
    fi
    for child in "$directory"/*/; do
        child="${child%/}"
        [ -d "$child" ] && [ ! -L "$child" ] || continue
        case "${child##*/}" in
            node_modules | build | target | vendor) continue ;;
        esac
        find_repositories "$child"
    done
}

link_repository() {
    local repo="$1" rel target path ignore
    for rel in $LINKS; do
        target="$CONF/$rel"
        path="$repo/$rel"
        [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ] && continue
        rm -rf "$path"
        mkdir -p "$(dirname "$path")"
        ln -s "$target" "$path"
        echo "$repo: $rel -> $target"
    done

    for rel in $STALE; do
        path="$repo/$rel"
        if [ -L "$path" ]; then
            rm "$path"
            echo "$repo: removed $rel"
        fi
        ignore="$repo/.gitignore"
        if [ -f "$ignore" ] && grep -q -x -F "$rel" "$ignore"; then
            # grep exits 1 when no line is left, which is still a successful drop.
            if grep -v -x -F "$rel" "$ignore" > "$ignore.tmp" || [ $? -eq 1 ]; then
                mv "$ignore.tmp" "$ignore"
                echo "$repo: dropped $rel from .gitignore"
            fi
        fi
    done
}

[ $# -ge 1 ] || { echo "usage: $0 <directory> [<directory> ...]" >&2; exit 2; }

bash "$CONF/.claude/hooks/generate.sh" || exit 1

status=0
for directory in "$@"; do
    root=$(cd "$directory" 2>/dev/null && pwd) || { echo "$directory: not a directory" >&2; status=1; continue; }
    found=0
    while IFS= read -r repo; do
        found=1
        [ "$(cd "$repo" && pwd -P)" = "$CONF_PHYSICAL" ] && continue
        link_repository "$repo"
    done < <(find_repositories "$root")
    [ $found -eq 1 ] || { echo "$root: no git repositories" >&2; status=1; }
done
exit $status
