#!/usr/bin/env bash
# Render one Compose @Preview to a PNG, headlessly, through a throwaway desktopTest.
#
#   render_preview.sh <sourceFile> <previewFunction> <out.png> [options]
#
#   sourceFile       Kotlin file holding the preview, under src/commonMain or src/desktopMain
#                    of a module with a jvm("desktop") target (androidMain cannot be rendered)
#   previewFunction  zero-parameter @Preview function in that file; private is fine
#   out.png          destination; <out.png>.nodes.tsv (semantics bounds, px) is written next to it
#
#   --width DP        scene width in dp (default 360)
#   --height DP       scene height in dp (default 800)
#   --density D       px per dp (default 2); the PNG is width*D x height*D px
#   --font-scale F    Density.fontScale (default 1)
#   --inspection B    LocalInspectionMode value (default true, as in the IDE preview)
#   --module PATH     Gradle project path (default: derived from the file path, ':a:b:c')
#   --facade CLASS    JVM facade class (default: <package>.<FileName>Kt, or @file:JvmName)
#
# The harness is copied into <module>/src/desktopTest/kotlin/figmaverify/, run with
# `./gradlew <module>:desktopTest --tests figmaverify.FigmaPreviewRenderTest --rerun`, and
# removed again on exit, success or failure. Without --rerun Gradle reports UP-TO-DATE and
# writes nothing. Run one render at a time.
set -euo pipefail

usage() { sed -n '2,24p' "$0" >&2; exit 1; }
[ $# -ge 3 ] || usage

src="$1"; fn="$2"; out="$3"; shift 3
width=360; height=800; density=2; fontScale=1; inspection=true; module=""; facade=""
while [ $# -gt 0 ]; do
  case "$1" in
    --width) width="$2"; shift 2 ;;
    --height) height="$2"; shift 2 ;;
    --density) density="$2"; shift 2 ;;
    --font-scale) fontScale="$2"; shift 2 ;;
    --inspection) inspection="$2"; shift 2 ;;
    --module) module="$2"; shift 2 ;;
    --facade) facade="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; usage ;;
  esac
done

fail() { echo "render_preview.sh: $1" >&2; exit 1; }

[ -f "$src" ] || fail "source file not found: $src"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
src="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
root="$(git -C "$(dirname "$src")" rev-parse --show-toplevel 2>/dev/null)" || fail "$src is not inside a git repository"
rel="${src#"$root"/}"

case "$rel" in
  */src/commonMain/*|*/src/desktopMain/*) ;;
  *) fail "$rel is not under src/commonMain or src/desktopMain; a desktop harness cannot render it" ;;
esac

moduleDir="${rel%%/src/*}"
[ -f "$root/$moduleDir/build.gradle.kts" ] || fail "no build.gradle.kts in $moduleDir"
[ -n "$module" ] || module=":$(printf '%s' "$moduleDir" | tr '/' ':')"

# One zero-parameter function of that name: the harness invokes it as (Composer, Int).
defs="$(grep -cE "fun[[:space:]]+$fn[[:space:]]*[(]" "$src" || true)"
[ "$defs" -eq 1 ] || fail "expected one 'fun $fn(' in $rel, found $defs"
grep -qE "fun[[:space:]]+$fn[[:space:]]*[(][[:space:]]*[)]" "$src" \
  || fail "$fn has parameters; render a zero-parameter preview, or wrap the call in a temporary private preview"
grep -qE '^[[:space:]]*@Preview' "$src" || echo "warning: no @Preview annotation found in $rel" >&2

if [ -z "$facade" ]; then
  pkg="$(grep -E '^package ' "$src" | head -1 | awk '{print $2}')"
  [ -n "$pkg" ] || fail "no package declaration in $rel"
  jvmName="$( { grep -oE '@file:JvmName[(]"[^"]+"[)]' "$src" || true; } | head -1 | sed -E 's/.*[(]"([^"]+)"[)]/\1/')"
  base="$(basename "$src" .kt)"
  facade="$pkg.${jvmName:-${base}Kt}"
fi

buildFile="$root/$moduleDir/build.gradle.kts"
for dep in "compose.ui.test" "coroutines.test" "kotlin.test"; do
  grep -q "$dep" "$buildFile" || fail "$moduleDir/build.gradle.kts lacks a test dependency matching '$dep'.
Add temporarily (and never commit):
  commonTestDependencies {
      implementation(libs.kotlin.test)
      implementation(libs.kotlin.coroutines.test)
      implementation(libs.jetbrains.compose.ui.test)
  }"
done

harnessDir="$root/$moduleDir/src/desktopTest/kotlin/figmaverify"
harness="$harnessDir/FigmaPreviewRenderTest.kt"
template="$(cd "$(dirname "$0")" && pwd)/FigmaPreviewRenderTest.kt.template"
[ -f "$template" ] || fail "template missing: $template"
[ ! -e "$harness" ] || fail "$harness already exists: a previous run did not clean up, or the project has its own; remove it first"
if git -C "$root" ls-files --error-unmatch "$harness" >/dev/null 2>&1; then
  fail "$harness is tracked by git; refusing to overwrite"
fi

# Directories the run creates, deepest first, so cleanup can remove exactly those (bash 3.2 safe).
created=""
dir="$harnessDir"
while [ ! -d "$dir" ]; do created="$created$dir
"; dir="$(dirname "$dir")"; done
cleanup() {
  rm -f "$harness"
  printf '%s' "$created" | while IFS= read -r dir; do [ -n "$dir" ] && rmdir "$dir" 2>/dev/null || true; done
}
trap cleanup EXIT

work=/tmp/figma-compose-verify
mkdir -p "$work"
rm -f "$work/render.png" "$work/render.png.nodes.tsv" "$out"
cat > "$work/request.properties" <<REQ
facadeClass=$facade
functionName=$fn
widthDp=$width
heightDp=$height
density=$density
fontScale=$fontScale
inspectionMode=$inspection
outputPng=$work/render.png
REQ

mkdir -p "$harnessDir"
cp "$template" "$harness"

log="$work/gradle.log"
echo "module $module  facade $facade  preview $fn" >&2
echo "scene ${width} x ${height} dp @ density $density  (log: $log)" >&2
status=0
(cd "$root" && ./gradlew "$module:desktopTest" --tests figmaverify.FigmaPreviewRenderTest --rerun --console=plain >"$log" 2>&1) || status=$?

if [ "$status" -ne 0 ] || [ ! -f "$work/render.png" ]; then
  echo "render failed (gradle exit $status); last lines of $log:" >&2
  tail -40 "$log" >&2
  report="$(find "$root/$moduleDir/build/test-results" -name 'TEST-figmaverify.FigmaPreviewRenderTest.xml' 2>/dev/null | head -1)"
  [ -n "$report" ] && grep -m1 -A12 '<failure' "$report" >&2
  exit 1
fi

cp "$work/render.png" "$out"
cp "$work/render.png.nodes.tsv" "$out.nodes.tsv"
echo "$out"
echo "nodes: $out.nodes.tsv  (px at density $density; Skia desktop render on $(uname -s), JDK $(java -version 2>&1 | grep -m1 -i ' version ' | sed -E 's/.*"([^"]+)".*/\1/'))" >&2
