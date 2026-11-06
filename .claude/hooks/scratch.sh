#!/bin/bash
# Not a hook: prints the scratch directory of a git repository and creates it,
# ${TMPDIR:-/tmp}/conf-ide/<sha1 of the repository's top-level path>.
# Usage: scratch.sh [a directory inside the repository; default the current directory].
# The hooks keep their state there (dirty-, asked-, stop-blocks- and window- files, no-commit); the
# new-feature skill and the agents write no-commit there. It is keyed by repository, not by session, so
# every caller finds the same path without a session id; a worktree has its own top level and its own
# directory. Exits 1 outside a git repository. Written for bash 3.2.

DIR="${1:-.}"
TOP=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 1
[ -z "$TOP" ] && exit 1
BASE="${TMPDIR:-/tmp}"
SCRATCH="${BASE%/}/conf-ide/$(printf '%s' "$TOP" | shasum -a 1 | cut -d' ' -f1)"
mkdir -p "$SCRATCH" || exit 1
printf '%s\n' "$SCRATCH"
