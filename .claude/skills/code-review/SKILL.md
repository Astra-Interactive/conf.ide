---
name: code-review
description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes: Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."
---

Two-axis review of the diff between `HEAD` and a fixed point the user supplies:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

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
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Search the repo for every file that documents how code should be written. When `CODING_STANDARDS.md` or `CONTRIBUTING.md` exists, it must be on the list.

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

### 4. Spawn both sub-agents in parallel

Issue both sub-agent calls together, in the foreground, and aggregate the reports they return.

Use the existing `agents-md-reviewer` and `task-vs-diff-verifier` roles, subject to `subagents.md`'s
capacity and current user instructions. Send both the exact revision/working-tree scope, current
requirements and exclusions. This two-axis review does not replace correctness review required elsewhere.
Both get the runner's lint output for the reviewed revision; when there is none, request a runner pass
first (`subagents.md`, Tests and validation).

**Standards sub-agent prompt** should include:

- The full diff command and commit list.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full (the sub-agent has no other access to it).
- The brief: "Report every documented-standard violation with its rule and source evidence, including
  architectural requirements. Separate heuristic smells from violations. Omit duplicate manual checks
  only where current evidence establishes enabled tooling coverage of these files; otherwise inspect
  manually or mark validation missing. Keep findings concise without dropping them for a word limit."

**Spec sub-agent prompt** should include:

- The diff command and commit list.
- The path or fetched contents of the spec.
- The brief: "Report missing/partial requirements, unrequested behaviour and apparently implemented but
  incorrect requirements. Include explicit architecture constraints and later user corrections. Quote
  the requirement and its evidence. Keep findings concise without dropping them for a word limit."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the two axes are deliberately separate (see _Why two axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

State the reviewed revision, working-tree scope and missing validation. A narrow or severity-filtered
result is not a full approval. Read-only workers return complete findings inline; the parent may archive
them separately rather than asking a worker to write outside its permissions.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.
