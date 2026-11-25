---
name: definition-of-done
description: Establish evidence that a changed artifact meets the task. Use from the first edit through final review or publication. Select checks by affected behaviour and consumers, reuse current evidence and state remaining validation precisely.
version: 2.0.0
---

# Definition of done

## Outcome and scope

Before editing, state the expected behaviour and acceptance evidence. For a specification with several
independent requirements, keep a numbered list. Add current user corrections to that same list. A small
task needs a short acceptance statement. A consequential decision needs one example that could refute
the proposed solution before implementation becomes expensive.

Read applicable rules through `AGENTS.md`. The task owns scope. Preserve named contracts and actual
callers, and account for each change in the final diff, including staged, unstaged and task-related new
files. Read the final contents and integration between writers. A sourced research answer without an
artifact change is complete when it answers the requested question and states material uncertainty.

## Evidence selection

The orchestrator chooses evidence with the executor and assigns execution through `subagents.md`.
Inspect relevant existing CI once to understand actual coverage. For ordinary changes, run local checks
covering changed behaviour and affected consumers. A check may be resource generation, compilation,
lint, a regression test, a script fixture, or document/reference validation, according to the failure
the task could introduce. Explain omitted relevant coverage and preserve failing results.

Run the applicable full local set when the change affects shared build infrastructure, a shared or
cross-platform contract, the boundary of impact is unknown, CI is absent or inadequate, or the user
requires it. Otherwise the complete matrix may run in PR CI. Required PR CI must pass before merge.
Opening a PR and a merge-ready result have different evidence states. Report each accurately and
respect the user's requested completion condition.

Run the real entry point when the result depends on runtime integration, device/platform behaviour,
external services or a visual property that cheaper evidence cannot establish. Name the behaviour to
verify, assign its owner and use an available appropriate environment. After an infrastructure failure,
retry when new diagnostic evidence justifies the attempt. Record an unavailable required check as
pending and complete independent authorized work. Device setup itself needs a task-relevant purpose.

For instructions, check source consistency, generated artifacts and a fresh consumer's relevant route.
State which of those were actually verified. A file edit alone proves no activation or performance gain.

## Reuse and completion

One accepted result serves all agents for the content and relevant environment it covered. Record the
repository and base/HEAD, working-tree inclusion or content identity, command, environment, exit code,
coverage and report pointer. Identify cached/up-to-date evidence as reused. After an edit, repeat only
checks whose conclusions it could change, including affected consumers. Re-run broader checks when new
failures or uncertainty widen the known impact.

Review a stable diff independently while checks run. Incorporate their results before the verdict.
The orchestrator owns final acceptance and can accept an implementer's runner evidence. Build, static,
runtime and visual claims need their own relevant support. Keep analysis diagnostics visible even when
the command exits successfully. Unavailable execution and forbidden checks are reported with their
actual limits and never as passes.

The final handoff states delivered behaviour, changed paths/revision, evidence and unresolved blockers.
For several independent requirements, include a compact table with requirement, location, evidence and
status (`done`, `partial` or `not done`). Full completion requires the evidence promised for the task's
current completion condition. Keep working logs and transcripts outside committed deliverables unless
requested.
