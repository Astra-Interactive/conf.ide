## Git commits

**A task that changes files ends with a commit, without being asked.** This rule overrides any
generic harness or tool defaults about whether to commit, branching, pushing, pull requests, and
commit trailers.

### When to commit

* Run `git status` before the first edit, so you know which files already carry the user's work.
* Commit each logical change as soon as it is complete and builds. The last commit is made before
  the final message.
* Do not commit when the user said not to, or when the build or the tests the change touches fail.
* Never stage a file that had uncommitted changes before the task: the user's edits would go in
  with yours. When the change cannot be committed without such a file, commit nothing.
* The final message lists the task's commits, `<hash> <title>` one per line, and every file left
  uncommitted with the reason.

### Where commits go

* Commit into the branch that is already checked out, the default branch included. Never create,
  switch, or rename a branch.
* Never push, and never open a pull request: the user pushes.
* Never amend, rebase or reset a commit that existed before the task, unless asked. A commit the
  task made may be amended while it is the last one and not pushed.

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

**Before the final message: commit, then list the commits.**
