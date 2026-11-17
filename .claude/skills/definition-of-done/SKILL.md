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

Update this same list when the user adds corrections or changes scope. Keep the current constraints and
open items in one external working log for a long task, not a new document for every small edit. Give
workers the applicable current instructions. A later "continue" does not revoke them; task-specific bans
do not become permanent rules for unrelated work. Progress and audit reports are not committed deliverables
unless the user requests that explicitly.

What the document names is the requirement. A stand-in (demo data, a placeholder model, a simpler algorithm,
a "fallback" path) leaves the row open. When the named thing cannot be built, stop and ask before writing
the stand-in.

## 2. Rules

Read every document AGENTS.md lists for the touched language, all of them, the Linter-enforced ones included,
then check the diff against each one. A rule the diff breaks is fixed now.

## 3. The diff as a stranger

Read `git diff <base>...HEAD`, tracked working-tree changes through `git diff HEAD`, and task-related
untracked files as a reviewer who never saw the session. Include staged and unstaged changes even when
base equals HEAD, record scope exclusions, and read final contents without double-counting diff views. Every hunk
traces to a requirement row; a hunk that traces to none is scope creep: revert it, or list it as a
suggestion for the user.

For a correction that applies to analogous places, inspect that pattern throughout the task's changes,
not only the reported example. This does not authorize unrelated repository-wide refactoring. Review the
integration between workers' changes; separate narrow approvals do not prove the integrated result.

## 4. Run it

1. The applicable CI task set: read the repository's CI workflow files and identify the tasks per source set and
   platform, with working directory, toolchain and flags. The main thread delegates execution following
   `.claude/docs/subagents.md`; a worker that starts helpers runs the scoped part through its own runner,
   and any other worker returns the requested commands to its parent. Requested test implementation
   follows the same document's test-writer route. No local check substitute.
2. The entry point the user runs (the CLI command, the app screen, the endpoint, the scheduled job), with
   real input. Quote the output in the report. When it cannot run here, say why and what would run it.

Respect the user's current validation scope. Do not run a forbidden test, tool or publication step under
another name. Record "not run by user instruction" instead of PASS, and continue work that does not depend
on it. When no CI or executable entry point applies to the changed documents, name the actual document
checks rather than inventing a build requirement.

A check counts for the revision and files it actually covered: record base/HEAD, working-tree inclusion,
command and exit code. Recheck affected validation after a relevant edit; if the reviewed code's unchanged
state cannot be established, say so. A scoped pass does not replace a failing broader task. Keep unresolved
analysis diagnostics visible even when the command exits successfully.
Workers return ready for validation until the parent supplies that evidence. The main thread owns final
validation; unavailable execution is blocked validation, never a pass. Operational entry-point verification
in step 2 stays with the responsible specialist.

Distinguish source implementation, static checks/builds, visual comparison and runtime validation. A mock
can establish business behaviour without real accounts; it does not prove a platform dialog or store SDK.
For instruction changes, distinguish edited sources, generated artifacts and instructions actually loaded
by a fresh consumer. Do not equate a source edit with an activated change to the environment.

## 5. Traceability table

End the report with one row per requirement:

| # | requirement | where (file:line) | evidence and scope (command/review, result) | status |
|---|---|---|---|---|

Status is `done`, `partial` or `not done`, the last two with the reason. A row is done only within its stated
scope and evidence. Implementation may be complete while runtime or activation remains unverified; report
those separately. Claim full completion only when every currently required row is done, not because the
remaining work is slow or unavailable.
