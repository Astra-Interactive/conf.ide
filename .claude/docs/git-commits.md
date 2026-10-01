## Git commits

This rule overrides any generic harness or tool defaults about branching, pushing, pull requests,
and commit trailers.

### Where commits go

* Commit into the branch that is already checked out. Never create, switch, or rename a branch.
* Never push, and never open a pull request. Committing is the last step; the user pushes.
* Never rewrite published history (`commit --amend`, `rebase`, `reset --hard`) unless asked.

### Authorship

The commit author and committer are whoever `git config user.name`/`user.email` resolves to,
and nobody else.

* Do not pass `--author`.
* Do not add `Co-authored-by:` trailers.
* Do not add a "Generated with Claude Code" line, a tool footer, or an emoji trailer.

### One commit per change

* Each commit is a single logical change that stands on its own and builds on its own.
* Stage explicitly: `git add <paths>`. Never `git add -A`, `git add .`, or `commit -a` — the tree
  usually carries unrelated work in progress.
* Never fold refactoring, formatting, or a version bump into a feature commit; they are their own
  commits, ordered before the change that needs them.
* Leave files you did not touch unstaged, and say so rather than sweeping them in.

### Title

`[TAG] Imperative summary of the change`, up to 72 characters, capitalised, no trailing period.

Say what the change does, not which files moved.

Default tags: `[FEAT]`, `[FIX]`, `[CHORE]`, `[DOCS]`, `[TEST]`. The list is open — add your own
(`[PERF]`, `[REFACTOR]`, `[BUILD]`, whatever the change needs) when none of these fits. Keep one
word per meaning: do not add a second spelling of a tag that is already in use.

### Body

Short. One paragraph, three or four lines, wrapped at 80 columns — and only when the title leaves a
real question open. A self-evident change ships with no body at all.

Write down the *why* a reader cannot recover from the diff: the constraint that forced the approach,
the alternative that was rejected, the trap the next person would fall into. Never an inventory of
the files, never a restatement of the title, never a bullet list of everything in the diff.

If the body needs more than one paragraph, that is a sign the commit needs splitting.

The whole shape, title and body together:

```
[CHORE] Stop repeating the tests on a release

They gate the pull request, which is where a change is reviewed. Running them
again on the push to master doubles the slowest part of a release without a
second opinion to show for it.
```
