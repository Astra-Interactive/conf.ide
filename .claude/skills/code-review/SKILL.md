---
name: code-review
description: Independently review changes since a fixed point or working state for task coverage, correctness and applicable standards. Reuse current evidence and add specialist review for identified risks or explicit requests.
---

Independent review of the diff between `HEAD` and the supplied fixed point, plus requested working changes:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?
- **Correctness**: do changed paths and affected callers preserve their runtime contracts?

One independent reviewer covers the criteria together under `subagents.md`.

Use the supplied task text, document or issue as the spec. A local brief does not require an issue tracker.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the diff command once: `git diff <fixed-point>...HEAD` (three-dot, so the comparison is against the merge-base). Also note the list of commits via `git log <fixed-point>..HEAD --oneline`.

For working-tree review, also include `git diff HEAD`, `git status --short` and task-related untracked
files. This covers staged and unstaged changes. Record the base/HEAD SHAs, included paths and exclusions;
read final file contents without counting the same change twice across diff representations.

Confirm the fixed point resolves (`git rev-parse <fixed-point>`). A bad ref stops dispatch. An empty
committed diff is not an empty review when tracked or untracked task changes exist, including base=HEAD.
If the entire requested scope is empty, report that directly.

### 2. Identify the spec source

Look for the originating spec, in this order:

Use the current user's supplied brief first. Whichever source supplies the original requirements, include
subsequent user corrections and approved scope changes; an older document or agent handoff cannot override them.

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in the tracker doc.
2. A path the user passed as an argument.
3. A spec file under `docs/`, `specs/`, or `.scratch/` matching the branch name or feature.
4. If the task provides no intent and none can be established from those sources, report the missing criterion and ask only when it prevents the requested verdict.

### 3. Identify the standards sources

Use the repository entry point and applicable rules. Include relevant `CODING_STANDARDS.md` and `CONTRIBUTING.md` when present.

Include the applicable `AGENTS.project.md`. Standards covers architectural requirements as well as syntax:
state ownership, responsibilities, existing mechanisms and necessity of abstractions. A finding against a
documented architectural requirement cites the rule, code and concrete consequence; it need not be a crash.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation.
  Omit duplicate manual checking only when current evidence shows an enabled automated check covered the
  reviewed files. Otherwise inspect the rule manually or report its validation as missing.

These are investigation prompts, not automatic refactoring recipes. A smell does not justify a new wrapper,
dependency bundle, polymorphic hierarchy or file move. Check the project's rules and actual callers first.

- **Mysterious Name**: does the name hide the declaration's responsibility?
- **Duplicated Code**: is this duplicated behaviour, or similar syntax with different reasons to change?
- **Feature Envy**: does the operation belong to the current owner under the project's domain rules?
- **Data Clumps**: do the values form a real concept, or would a bundle merely hide dependencies?
- **Primitive Obsession**: is an invariant or unit missing, rather than just a wrapper type?
- **Repeated Switches**: can the decisions diverge, and is there already one owner for that rule?
- **Shotgun Surgery**: is the spread required by real boundaries, or caused by misplaced responsibility?
- **Divergent Change**: does one class combine unrelated responsibilities? Length alone is not evidence.
- **Speculative Generality**: what current requirement needs each new abstraction, parameter or protocol?
- **Message Chains**: does the caller depend on details outside its responsibility?
- **Middle Man**: is delegation the framework's intended boundary, or an unnecessary extra layer?
- **Refused Bequest**: does the implementation satisfy the contract its callers actually rely on?

### 4. Assign independent review

Use one `code-reviewer` for task coverage, correctness and applicable standards. For instruction-only
changes use `docs-consistency-reviewer`, covering those criteria and dependent document consistency.
Give the reviewer the pinned revision/working-tree scope, current requirements, applicable source
pointers, exclusions and available evidence. The review may start alongside validation once the diff
is stable. The reviewer incorporates current outcomes before its verdict.

Assign additional `agents-md-reviewer` or `task-vs-diff-verifier` only for an identified risk or the
user's explicit request. An existing independent review counts when it covered the same content,
criteria and relevant environment. Re-check affected findings after an edit.

### 5. Report

Report findings by severity with their criterion: task coverage, correctness or standards. A finding
cites the changed code and the failing scenario or violated requirement. Keep heuristic smells
separate from violations. State the reviewed content and missing evidence. An empty result within
that scope is a complete answer. Keep full logs at their existing paths.

## Review criteria

A change can follow the rules and implement the wrong behaviour, or meet the task while violating a
documented constraint. Check both and runtime correctness. Each finding identifies the failed criterion
so a clean result in one area cannot hide a problem in another.
