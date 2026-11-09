---
name: definition-of-done
description: Prove a coding task is done before saying so. Use before reporting a task finished, before opening a pull request, and from the first edit whenever the task implements a spec, plan, issue or design document. Builds the requirement list, checks the diff against every rule of the language, runs the CI task set and the real entry point, and ends with a traceability table.
version: 1.0.0
---

# Definition of done

Done is a claim with evidence behind every row. Green tests prove the tests; the user runs the program.

## 1. Requirements (before the first edit when there is a source document)

When the task comes from a spec, plan, issue or design document, write its requirements as a numbered list
before editing: one row per behaviour, named library, algorithm, data source, interface or limit the
document states. Without a source document, the rows are the user's request split into checkable parts.

What the document names is the requirement. A stand-in (demo data, a placeholder model, a simpler algorithm,
a "fallback" path) leaves the row open. When the named thing cannot be built, stop and ask before writing
the stand-in.

## 2. Rules

Read every document AGENTS.md lists for the touched language, all of them, then check the diff against each
one. A rule the diff breaks is fixed now.

## 3. The diff as a stranger

Read `git diff <base>...HEAD` plus the untracked files as a reviewer who never saw the session. Every hunk
traces to a requirement row; a hunk that traces to none is scope creep: revert it, or list it as a
suggestion for the user.

## 4. Run it

1. The CI task set: read the repository's CI workflow files and identify the tasks per source set and
   platform, with working directory, toolchain and flags. The main thread delegates execution following
   `.claude/docs/subagents.md`; a worker returns the requested commands to its parent. Requested test
   implementation follows the same document's test-writer route. No nested agents or local check substitute.
2. The entry point the user runs (the CLI command, the app screen, the endpoint, the scheduled job), with
   real input. Quote the output in the report. When it cannot run here, say why and what would run it.

A check counts when it ran after the last edit and its command and exit code are in the report.
Workers return ready for validation until the parent supplies that evidence. The main thread owns final
validation; unavailable execution is blocked validation, never a pass. Operational entry-point verification
in step 2 stays with the responsible specialist.

## 5. Traceability table

End the report with one row per requirement:

| # | requirement | where (file:line) | check (command or test, exit code) | status |
|---|---|---|---|---|

Status is `done`, `partial` or `not done`, the last two with the reason. The task is done when every row
is `done`; anything else is reported as it is.
