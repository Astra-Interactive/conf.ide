---
name: new-feature
description: Set up a new feature in a git repository. Use it before the first edit whenever the user asks to add, build or implement a feature, or types /new-feature. Asks where to work (current branch, new branch or worktree), which branch to start from, whether to commit and whether to open a pull request; sets up the branch or worktree and hands the pull request to the pull-request skill.
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

When the user said yes, load the `pull-request` skill after the last commit. Its base is the branch the feature
started from; the default branch when the work stayed on the current branch.
