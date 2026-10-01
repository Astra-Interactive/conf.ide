#!/usr/bin/env bash
# Checks the files a task added since BASE against the package-layout rules.
# Run from the repository root, and only when the user asks for it:
#   bash check-layout.sh <BASE commit> [path prefix]
# Every finding names a new file or a new directory. Old files are never reported, so a finding is fixed by
# moving the new file. Exit code 1 when anything was found.

set -u
BASE="${1:?usage: check-layout.sh <BASE commit> [path prefix]}"
PREFIX="${2:-.}"

KINDS='api|model|internal|di|mapping|usecase|command|argument|event|menu|composable|view|viewmodel|config|storage|permission|util|database|network|fake'
PRIVATE_KINDS='internal|mapping|usecase|command|argument|event|menu|composable|view|viewmodel|config|storage|permission|util|database|network|fake'
BANNED='models|entity|entities|types|error|errors|exception|exceptions|failure|impl|implementation|service|services|manager|managers|controller|controllers|handler|handlers|provider|providers|helper|helpers|interfaces|contract|contracts|port|ports|dto|dtos|remote|dao|daos|repository|repositories|persistence|db|table|tables|exposed|krate|prefs|datastore|configuration|settings|properties|translation|translations|messages|ui|gui|screen|screens|compose|component|components|presentation|presenter|state|mapper|mappers|converter|converters|utils|common|misc|ktx|ext|extensions|listener|listeners|events|commands|cmd|argumenttype|arguments|jda|kord'
ENTRY='fun main\(|: *JavaPlugin\(\)|: *Application\(\)|: *Plugin\(\)|ModInitializer|@Mod\('
NOT_WORD='([^A-Za-z0-9_]|$)'
FOUND=0

report() {
    FOUND=1
    printf '%-18s %s\n' "$1" "$2"
}

existed_at_base() {
    git cat-file -e "$BASE:$1" 2>/dev/null
}

crate_root_of() {
    case "$1" in
        "$2"/*) echo . ;;
        *) echo "${1%%/"$2"/*}" ;;
    esac
}

NEW_FILES=$({ git diff --name-only --diff-filter=A "$BASE" -- "$PREFIX"; git ls-files --others --exclude-standard -- "$PREFIX"; } | sort -u)
NEW_SOURCES=$(printf '%s\n' "$NEW_FILES" | grep -E '\.(kt|rs)$' | grep -vE '\.gradle\.kts$|(^|/)build\.rs$')
NEW_KT=$(printf '%s\n' "$NEW_SOURCES" | grep -E '\.kt$')
NEW_RS=$(printf '%s\n' "$NEW_SOURCES" | grep -E '\.rs$')

while read -r line; do
    [ -n "$line" ] && report "OLD-FILE-MOVED" "$line"
done < <(git diff --name-status "$BASE" -- "$PREFIX" | grep -E '^[RD]')

for file in $NEW_SOURCES; do
    dir=$(dirname "$file")
    case "$file" in
        src/lib.rs|src/main.rs|*/src/lib.rs|*/src/main.rs) continue ;;
    esac
    if [ "${file##*.}" = "rs" ] && [ "$(basename "$dir")" = "src" ]; then
        report "LOOSE" "$file (src/ holds only lib.rs and main.rs)"
        continue
    fi
    if [ -n "$(find "$dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
        if [ "${file##*.}" = "kt" ] && grep -qE "$ENTRY" "$file"; then
            continue
        fi
        report "LOOSE" "$file (its package also holds packages)"
    fi
done

NEW_DIRS=$(for file in $NEW_SOURCES; do
    dir=$(dirname "$file")
    while [ "$dir" != "." ] && [ "$dir" != "/" ] && ! existed_at_base "$dir"; do
        echo "$dir"
        dir=$(dirname "$dir")
    done
done | sort -u)

for dir in $NEW_DIRS; do
    name=$(basename "$dir")
    case "$name" in
        src|main|test|tests|kotlin|java|testFixtures|*Main|*Test) continue ;;
    esac
    if printf '%s\n' "$name" | grep -qxE "$BANNED"; then
        report "BANNED-NAME" "$dir (see the replacement table)"
    elif printf '%s\n' "$name" | grep -qE '[A-Z-]'; then
        report "NAME-CASE" "$dir (lowercase, one segment)"
    elif ! printf '%s\n' "$name" | grep -qxE "$KINDS" && [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 -type d)" ]; then
        report "NEW-KIND?" "$dir (a leaf outside the kind table: a reported new kind, or a concept leaf)"
    fi
    for sibling in "$(dirname "$dir")"/*/; do
        sibling_name=$(basename "$sibling")
        [ "$sibling_name" = "$name" ] && continue
        if [ "$sibling_name" = "${name}s" ] \
            || { [ "$name" = "mapping" ] && [ "$sibling_name" = "mapper" ]; } \
            || { [ "$name" = "util" ] && [ "$sibling_name" = "ktx" ]; } \
            || { [ "$name" = "model" ] && [ "$sibling_name" = "exception" ]; }; then
            report "TWIN-SPELLING" "$dir next to the existing $sibling_name/"
        fi
    done
done

for file in $NEW_SOURCES; do
    lines=$(wc -l < "$file" | tr -d ' ')
    if [ "$lines" -gt 400 ]; then
        report "FILE-TOO-LONG" "$file ($lines lines: split by a whole group)"
    fi
done

for dir in $(for file in $NEW_SOURCES; do dirname "$file"; done | sort -u); do
    count=$(find "$dir" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')
    if [ "$count" -gt 20 ]; then
        report "KIND-OVER-20" "$dir ($count files: report it with a suggested split)"
    fi
done

for file in $(printf '%s\n' "$NEW_KT" | grep -E '/src/[A-Za-z]*[Mm]ain/'); do
    while read -r hit; do
        [ -n "$hit" ] && report "NO-MODIFIER" "$file:$hit"
    done < <(grep -nE '^((abstract|annotation|const|data|enum|expect|actual|fun|inline|lateinit|open|operator|sealed|suspend|tailrec|value) )*(class|interface|object|fun|val|var|typealias) ' "$file")
    while read -r hit; do
        [ -n "$hit" ] && report "PUBLIC?" "$file:${hit%%(*} (only the entry point and what another unit uses)"
    done < <(grep -nE '^public ' "$file" | grep -vE "$ENTRY")
done

while IFS="$(printf '\t')" read -r name home; do
    [ -z "$name" ] && continue
    for file in $NEW_KT; do
        [ "$file" = "$home" ] && continue
        if grep -qE "(\)|(class|object) +[A-Za-z0-9_]+) *: *$name$NOT_WORD" "$file"; then
            report "SEALED-SPLIT" "$file declares a variant of $name, which lives in $home"
        fi
    done
done < <(for file in $NEW_KT; do
    grep -oE 'sealed (interface|class) [A-Za-z0-9_]+' "$file" | awk -v file="$file" '{ print $3 "\t" file }'
done)

for file in $NEW_KT; do
    case "$file" in
        src/test/*|*/src/test/*|src/*Test/*|*/src/*Test/*) ;;
        *) continue ;;
    esac
    rel=${file#*/kotlin/}
    source_name=$(basename "$rel" | sed -E 's/Test\.kt$/.kt/')
    [ "$source_name" = "$(basename "$rel")" ] && continue
    root=$(crate_root_of "$file" src)
    if [ -z "$(find "$root/src" -path "*/kotlin/$(dirname "$rel")/$source_name" -not -path '*/test/*' -not -path '*Test/*' 2>/dev/null)" ]; then
        report "TEST-NOT-MIRRORED" "$file (no $(dirname "$rel")/$source_name in a main source set)"
    fi
done

for file in $NEW_RS; do
    [ "$(basename "$file")" = "mod.rs" ] && report "MOD-RS" "$file"
    case "$file" in
        src/lib.rs|src/main.rs|*/src/lib.rs|*/src/main.rs) ;;
        src/*|*/src/*)
            if grep -qE '^[[:space:]]*(pub(\([a-z]+\))? )?mod [a-z_0-9]+;' "$file"; then
                report "MOD-OUTSIDE-LIB" "$file (declare modules in src/lib.rs)"
            fi
            if grep -qE '#\[cfg\(test\)\]|#\[test\]|mod tests' "$file"; then
                report "TEST-IN-SRC" "$file (tests live in test/)"
            fi
            ;;
        test/*|*/test/*)
            base=$(basename "$file" .rs)
            case "$base" in
                fake_*|lib) continue ;;
            esac
            crate=$(crate_root_of "$file" test)
            rel=${file#"$crate"/}
            rel=${rel#test/}
            source_file="$crate/src/$(dirname "$rel")/${base%_test}.rs"
            source_file=$(printf '%s' "$source_file" | sed -e 's#^\./##' -e 's#/\./#/#')
            [ -f "$source_file" ] || report "TEST-NOT-MIRRORED" "$file (no $source_file)"
            ;;
    esac
done

for lib in $({ printf '%s\n' "$NEW_FILES"; git diff --name-only "$BASE" -- "$PREFIX"; } | grep -E '(^|/)src/lib\.rs$' | sort -u); do
    while read -r hit; do
        [ -n "$hit" ] && report "PUB-KIND-MOD" "$lib:$hit (R-V1: this kind is pub(crate) mod)"
    done < <(grep -nE "^[[:space:]]*pub mod ($PRIVATE_KINDS)$NOT_WORD" "$lib")
done

if [ "$FOUND" -eq 0 ]; then
    echo "No findings in the files added since $BASE."
fi
exit "$FOUND"
