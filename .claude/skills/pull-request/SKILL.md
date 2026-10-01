---
name: pull-request
description: Open a pull request and write its title and description. Use it whenever a pull request is to be opened, updated or described — the user asks for a PR, the new-feature skill's answers ask for one, or a PR description needs rewriting. Checks the branch, bumps the project version, pushes only the feature branch, writes a short title and a description that says only what the diff cannot, and creates or edits the PR with gh.
version: 1.1.0
---

# Pull request

A pull request is opened only when the user asked for one, here or through the new-feature skill. It is the one
case where pushing is allowed: the git-commits rule forbids pushing otherwise.

## 1. Check the branch

```bash
git status --short --branch
git symbolic-ref --short refs/remotes/origin/HEAD   # the default branch, e.g. origin/main
gh pr view --json number,url,baseRefName 2>/dev/null
```

- The base is the branch the work started from, when it is known (the new-feature skill's answer); otherwise the
  default branch.
- A pull request needs its own branch. When the work is on the base branch, stop and ask the user where to move it;
  never move commits off a branch yourself.
- The task's uncommitted changes are committed first, by the git-commits rule; files that carried the user's work
  before the task stay out.
- When the branch already has a pull request, update that one (step 5) instead of opening a second.

Read the whole change before writing, not only the last commit: `git log --oneline <base>..HEAD` and
`git diff <base>...HEAD`.

## 2. Bump the version

A pull request that changes what the project's users get (a fix, a feature, a dependency they receive) raises the
project version, unless the branch already raises it over the base (`git diff <base>...HEAD -- <version file>`).

- The version is where the build reads it: the version key of `gradle.properties`, `[package] version` of
  `Cargo.toml` (`[workspace.package]` in a workspace), `version` of `package.json`.
- A fix raises the patch number (1.38.1 → 1.38.2), a feature the minor (1.38.2 → 1.39.0), a change users have to
  act on (a renamed config key, a broken API) the major.
- The bump is its own commit, the last one on the branch: `[CHORE] Bump version to 1.38.2`. The description says
  the new version in one line (`Version 1.38.2.`).
- A pull request that changes nothing users get (docs, CI, tests, agent rules) keeps the version, and so does a
  project that keeps no version in its files.

## 3. Push

Push the feature branch and nothing else: `git push -u origin <branch>`. Never push the base branch, never
`--force`.

## 4. Open

Write the title and the description by the rules below, the description into a temporary file. A repository
template (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`) gives the headings; its sections
are filled by the same rules, and one that does not apply is removed.

```bash
gh pr create --base <base> --head <branch> --title "<title>" --body-file <file>
```

The base is written without `origin/`. The final message gives the pull request's URL.

## 5. Update

When later commits make the title or the description wrong, rewrite them for the whole change as it is now, by the
same rules: `gh pr edit <number> --title "<title>" --body-file <file>`. The description says what the pull request
does, never what changed since the last version of it.

## Title

The commit title format: `[TAG] Imperative summary of the change`, up to 72 characters. A pull request of one
commit takes that commit's title. A squash merge turns the title into the commit on the base branch, so it says
what the change does, not how the work went.

## Description

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
