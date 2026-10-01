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

**Most commits are the title alone.** Write a body only when someone who reads the title and the
diff would otherwise undo the change or repeat a mistake: a workaround for a bug outside the
repository, a version pinned on purpose, an obvious approach that does not work. Then the body is
one sentence, two at most, wrapped at 72 columns.

Never in a message:

* what the diff already says: the text of the rule or comment it adds, the list of files or steps;
* the story of the task: how the problem was found, what was tried, eval scores, counts, the
  projects it was tested on;
* build and test results, "This commit…", the title said again.

Three complete messages:

```
[FEAT] Add the package-layout skill
[FIX] Order Kotlin imports the way detekt checks them
[CHORE] Bump Kotlin to 2.2.20
```

A body, because a reader would otherwise put the tests back:

```
[CHORE] Stop repeating the tests on a release

The pull request already ran them on the same commit.
```

Too long: the rule the diff adds already gives the reason, and the count comes from the session
that wrote it. The title alone was the message.

```
[FIX] Name the Rust impl kind imp

impl is a keyword, so a module named after the kind has to be written r#impl in
every path; the NanoLimbo refactor needed it 92 times. imp is the name Rust
crates already use for implementation modules.
```

**Before the final message: commit, then list the commits.**
