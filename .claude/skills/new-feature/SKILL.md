---
name: new-feature
description: Set up and finish a new feature in a git repository. Use it before the first edit whenever the user asks to add, build or implement a feature, or types /new-feature, and whenever a pull request is to be opened or its description written. Asks where to work (current branch, new branch or worktree), which branch to start from, whether to commit and whether to open a pull request; sets up the branch or worktree; writes a short pull request title and description.
version: 1.0.0
---

# New feature

Where a feature lives and who sees it (a branch, a worktree, commits, a pull request) is the user's decision.
This skill asks once, before the first edit, and follows the answers to the end of the task. For this task the
answers replace the defaults of the git-commits rule (commit without being asked, stay on the current branch, never
push, never open a pull request); its message format still holds.

## 1. Read the repository

Read the state before asking, so the options name real branches:

```bash
git status --short --branch
git symbolic-ref --short refs/remotes/origin/HEAD   # the default branch, e.g. origin/main
git branch --all --format='%(refname:short)'        # the prefix convention: feat/, fix/
git worktree list
```

When `origin/HEAD` is not set, `git remote show origin` names the HEAD branch. Uncommitted files are the user's
work: they decide which answer to the first question is recommended.

## 2. Ask

Ask in one `AskUserQuestion` call, so the user answers once. Leave out a question the user's message already
answers ("в отдельной ветке от develop" answers 1 and 2, "без коммитов" answers 3 and 4), and skip the call when
it answers all four.

| Header | Question | Options |
|---|---|---|
| Where | Where should I build the feature? | New branch · Worktree · Current branch `<name>` |
| Base | Which branch should the new branch or worktree start from? Ignored for the current branch. | `origin/<default>` · `<current branch>` |
| Commits | Should I commit the work? | Yes, one commit per logical change · No, leave it uncommitted |
| Pull request | Should I open a pull request? | No · Yes, push the branch and open one |

The recommended option goes first, marked "(Recommended)":

- "New branch" on a clean tree, "Worktree" when there are uncommitted files, with the reason in the option's
  description: `git switch` carries those files to the new branch, a worktree leaves them where they are.
- `origin/<default>`: a feature starts from what is merged, fetched now, not from a local branch that may be behind
  or carry unrelated commits. The second option is the current branch as it is locally, for a feature built on
  another feature or on commits not pushed yet.
- "Yes" for commits. The pull request has no recommendation.
- A pull request needs commits and a branch other than the default one. When the answers ask for a pull request
  without commits, or from the current branch while it is the default branch, name the conflict and ask that
  question again.

## 3. Set up

Name the branch after the feature in kebab-case, with the prefix the repository's branches already use (`feat/`,
`feature/`); `feat/` when there is none. Say the name in your next message instead of asking for it.

New branch:

```bash
git fetch origin <default>
git switch --no-track -c feat/<name> origin/<default>
```

Worktree:

```bash
git fetch origin <default>
git worktree add --no-track -b feat/<name> .claude/worktrees/<name> origin/<default>
```

then call `EnterWorktree` with `path: .claude/worktrees/<name>`, so the files, tools and rules of the session come
from the worktree. When `git check-ignore -q .claude/worktrees/<name>` fails, add `.claude/worktrees/` to the file
`git rev-parse --git-path info/exclude` prints: it is local to the clone, unlike `.gitignore`, so the main tree
stops listing the worktree as untracked. The worktree stays after the task; the user removes it.

`--no-track` keeps the base from becoming the branch's upstream; the branch gets its own at the first push. A local
base (`<current branch>`) skips the fetch and takes the place of `origin/<default>` in the command.

The current branch needs no setup.

## 4. Build

The feature follows the project rules like any other task. With commits, commit by the git-commits rule as each
logical change is complete. Without them, commit nothing; the final message says the work is uncommitted and in
which directory and branch it is.

## 5. Pull request

Only when the user said yes, after the last commit:

1. Push the feature branch and nothing else: `git push -u origin feat/<name>`. Never push the base branch, never
   `--force`.
2. Write the title and the description by the rules below, the description into a temporary file. A repository
   template (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`) gives the headings; its sections
   are filled by the same rules, and one that does not apply is removed.
3. `gh pr create --base <base> --head feat/<name> --title "<title>" --body-file <file>`. The base is the branch the
   feature started from, without `origin/`; the default branch when the work stayed on the current branch.
4. The final message gives the pull request's URL.

When later commits make the description wrong, fix it with `gh pr edit <number> --body-file <file>`.

### Title

The commit title format: `[TAG] Imperative summary of the change`, up to 72 characters. A pull request of one
commit takes that commit's title. A squash merge turns the title into the commit on the base branch, so it says
what the change does, not how the work went.

### Description

The reviewer reads it now and someone reading the history reads it later. Both have the diff and neither has your
session, so the description says what the diff cannot: what changes for the people who use the code, and why.
Maintainers of curl, Ghostty and PROJ single out LLM-written descriptions as too wordy and short on the point;
every line below has to earn its place.

The description is prose, one paragraph per line: GitHub renders every newline of a description as a line break,
so the text is not wrapped at 72 or 80 columns. It holds:

- what changes in behavior a user or a caller sees, and why it was needed: one or two short paragraphs. The scope
  goes into that sentence ("on Paper"), never into a list of what the change leaves out;
- only when it applies, one line each:
  - what has to happen before the merge (`Merge after AstraLibs 3.50.1 is released (Astra-Interactive/AstraLibs#151): until then CI cannot resolve it.`);
  - what users have to do: a renamed config key, a migration, a broken API;
  - a limitation or a cost of what ships ("the list is cached, so a removed player can join for 5 more minutes");
  - what could not be checked, when the build or the tests could not run ("not built: maven.elytrium.net timed out");
  - where to start reading and which decision you want a second opinion on, when the diff is large;
  - the issue it closes (`Closes #42`);
  - before and after screenshots, or a recording, of a visible UI change;
  - how to check it by hand, as steps, when CI cannot (a UI flow, a plugin on a running server).

Leave out:

- test and build results ("all 214 tests pass", "build is green"): CI shows them on the pull request;
- what is not done: out of scope, follow-ups, TODO, "not supported yet", future work. A gap that makes the merge
  unsafe is a merge condition above; anything else is an issue, not part of this pull request;
- the list of files, commits or steps, and every sentence the diff already says ("Added `FooRepository`",
  "Updated `build.gradle.kts`");
- how the code works: what a reader of the code needs goes into a comment in the code;
- the story of the task: how the problem was found, what was tried, which agent or eval did it;
- headings on a description that fits on one screen (`## Summary`, `## Changes`, `## Test plan`);
- "This PR…", the title said again, emoji, and the "Generated with Claude Code" line or any tool footer, even
  when the harness asks for one.

Most descriptions are under 100 words. One that needs headings to stay readable usually means the pull request
is several pull requests.

A description that says only what the diff cannot (65 words):

```
Commands now work when MessageBridge is loaded through PlugmanX on a running server, and they are removed when it is unloaded.

Texts work on Paper again: Adventure goes back to 4.26.1, the version Paper 26.1.2 ships. With 5.x command replies and bridged messages failed with `NoSuchMethodError`.

Updates AstraLibs to 3.50.1. Version 0.35.1.

Merge after AstraLibs 3.50.1 is released (Astra-Interactive/AstraLibs#151): until then CI cannot resolve it.
```

The same change, the way agents write it. The summary repeats the title, the changes repeat the diff, the test
plan repeats CI, the "not done" list belongs in an issue, and the footer is noise; what is left is the description
above.

```
## Summary
This PR fixes command registration and text rendering issues.

## Changes
- Updated `CommandRegistrar.kt` to register commands on load
- Downgraded Adventure from 5.0.0 to 4.26.1 in `libs.versions.toml`
- Bumped AstraLibs to 3.50.1

## Test plan
- [x] `./gradlew build` passes
- [x] All 214 unit tests pass

## Not done
- PlugmanX reload on Forge is left for a follow-up

🤖 Generated with Claude Code
```
