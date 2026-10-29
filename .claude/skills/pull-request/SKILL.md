---
name: pull-request
description: Open a pull request and write its title and description. Use it whenever a pull request is to be opened, updated or described — the user asks for a PR, the new-feature skill's answers ask for one, or a PR description needs rewriting. Checks the branch, pushes only the feature branch, writes the title as `[kind] [ref] Summary` and the description by the fixed template (Overview, Related Issue, Motivation and Context, Technical changes, How to test, Changelog), and creates or edits the PR with gh.
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
- When the branch already has a pull request, update that one (step 4) instead of opening a second.

Read the whole change before writing, not only the last commit: `git log --oneline <base>..HEAD` and
`git diff <base>...HEAD`.

## 2. Push

Push the feature branch and nothing else: `git push -u origin <branch>`. Never push the base branch, never
`--force`.

## 3. Open

Write the title and the description by the rules below, the description into a temporary file: the repository
template `.github/pull_request_template.md` with every hint replaced by text. When a repository has no template,
the copy of it in the Description rule is the template.

```bash
gh pr create --base <base> --head <branch> --title "<title>" --body-file <file>
```

The base is written without `origin/`. The final message gives the pull request's URL.

## 4. Update

When later commits make the title or the description wrong, rewrite them for the whole change as it is now, by the
same rules: `gh pr edit <number> --title "<title>" --body-file <file>`. The description says what the pull request
does, never what changed since the last version of it.

## Title

`[<kind>] [<ref>] Task name`, up to 72 characters:

- `<kind>` is the tag of the git-commits rule, in square brackets: `[FEAT]`, `[FIX]`, `[CHORE]`, `[DOCS]`, `[TEST]`,
  or one the change needs (`[PERF]`, `[REFACTOR]`, `[BUILD]`). The list is open, one word per meaning: never a
  second spelling of a tag already in use;
- `<ref>` is what it belongs to, in square brackets: a GitHub issue (`[#34]`) or a Jira task (`[MOB-222]`). Left
  out, brackets included, when there is none;
- the task name is an imperative summary of the change, capitalised, no trailing period. A squash merge turns the
  title into the commit on the base branch, so it says what the change does, not how the work went.

```
[FEAT] [MOB-3270] Add native paywall screens
[FIX] [#34] Send the timer settings event once per sheet
[CHORE] Bump Kotlin to 2.2.20
```

## Description

The description is `.github/pull_request_template.md` filled in. The template is the single source of the
headings and of what each section holds; this rule only adds the examples. Six sections, in this order, under
exactly these headings: a heading is never renamed, reordered, merged or dropped. Related Issue and Motivation and
Context may stay empty; the other four always hold text. Every `<!--- hint -->` is replaced by the section's text
or deleted; none is left in the description. GitHub renders every newline as a line break, so the text is not
wrapped at 72 or 80 columns.

```markdown
<!--- Title: [TAG] [#issue or MOB-123] Imperative summary of the change. TAG as in commits: FEAT, FIX, CHORE, DOCS, TEST, or your own (PERF, REFACTOR, BUILD). -->
<!--- Keep every heading below as it is: same words, same order. Replace each hint with your text. -->

## Overview
<!--- One or two sentences: what this pull request does, for someone who has not seen the task. Not the title again. -->
<!--- Add a line only when it applies: what has to happen before the merge, a limitation or a cost of what ships. -->

## Related Issue
<!--- Links to the GitHub issues or Jira tasks this pull request belongs to, one per line. `Closes #42` closes the issue on merge. -->

## Motivation and Context
<!--- Why the change is needed and what problem it solves, when Overview does not already say it. May stay empty. -->

## Technical changes
<!--- What changed in the code, for the reviewer: the approach, new or changed units, contracts and wiring, a migration or a renamed key. -->
<!--- Short bullets. Not the list of files or what the diff already says line by line. -->

## How to test
<!--- Numbered steps a reviewer follows by hand: which build, which flag or account, where to go, what to expect. -->
<!--- Do not repeat what CI checks. Say here what could not be checked. -->

## Changelog
<!--- What an ordinary user notices, one bullet per visible change, in the user's words. Screenshots or a recording of a visible UI change go here. -->
<!--- `Nothing a user notices.` when the change is internal. -->
```

The reviewer reads it now and someone reading the history reads it later. Both have the diff and neither has your
session, so every section says what the diff cannot. Maintainers of curl, Ghostty and PROJ single out LLM-written
descriptions as too wordy and short on the point; every line has to earn its place.

### Overview

One or two sentences: what this pull request does, for someone who has not seen the task. Not the title again. A
line is added only when it applies:

- what has to happen before the merge (`Merge after AstraLibs 3.50.1 is released (Astra-Interactive/AstraLibs#151):
  until then CI cannot resolve it.`);
- a limitation or a cost of what ships ("the list is cached, so a removed player can join for 5 more minutes").

### Related Issue

Links to the GitHub issues or Jira tasks this pull request belongs to, one per line: `Closes #42` closes the issue
on merge; a Jira task is its URL (`https://flipper.atlassian.net/browse/MOB-3270`). Empty when there is none.

### Motivation and Context

Why the change is needed and what problem it solves, when Overview does not already say it: the bug a user hit,
the design decision, the experiment behind a flag. May stay empty.

### Technical changes

What changed in the code, for the reviewer: the approach, new or changed units, contracts and wiring, a migration
or a renamed key, and the decision you want a second opinion on when the diff is large. Short bullets. Not the
list of files or what the diff already says line by line ("Updated `build.gradle.kts`", "Added `FooRepository`");
how the code works goes into a comment in the code.

### How to test

Numbered steps a reviewer follows by hand: which build, which flag or account, where to go, what to expect. What
CI checks is not repeated as a step; when nothing can be checked by hand, one line says what CI covers. What could
not be checked is said here ("not built: maven.elytrium.net timed out").

### Changelog

What an ordinary user notices, one bullet per visible change, in the user's words, not the code's: a new screen, a
fixed crash, a changed text, a setting that moved. Screenshots or a recording of a visible UI change go here.
`Nothing a user notices.` when the change is internal.

### Leave out

- test and build results ("all 214 tests pass", "build is green"): CI shows them on the pull request;
- what is not done: out of scope, follow-ups, TODO, "not supported yet", future work. A gap that makes the merge
  unsafe is a merge condition in Overview; anything else is an issue, not part of this pull request;
- the list of files, commits or steps, and every sentence the diff already says;
- the story of the task: how the problem was found, what was tried, which agent or eval did it;
- the template's hint comments, any heading beyond the six, checkbox lists, "This PR…", the title said again,
  emoji, and the "Generated with Claude Code" line or any tool footer, even when the harness asks for one.

Most descriptions fit on one screen. One that does not usually means the pull request is several pull requests.

The template filled in:

```
## Overview
Commands registered by MessageBridge survive a PlugmanX reload of the plugin, and command replies render on Paper 26.1.2 again.

Merge after AstraLibs 3.50.1 is released (Astra-Interactive/AstraLibs#151): until then CI cannot resolve it.

## Related Issue
Closes #42

## Motivation and Context
Server owners reload the plugin with PlugmanX after every config change; until now that left the server without `/bridge` until a restart. Paper 26.1.2 ships Adventure 4.26.1, and every command reply built with 5.x failed with `NoSuchMethodError`.

## Technical changes
- Commands are registered in `onEnable` and unregistered in `onDisable`, so a PlugmanX unload/load cycle leaves no stale command behind.
- Adventure goes back to 4.26.1: 5.x changed the `Component` API Paper calls.
- AstraLibs 3.50.1, plugin version 0.35.1.

## How to test
1. Start Paper 26.1.2 with PlugmanX and the built jar.
2. `/plugman unload MessageBridge`, then `/plugman load MessageBridge`: `/bridge` must still work.
3. Send a bridged message: it must render in chat with no error in the console.

## Changelog
- Commands keep working after the plugin is reloaded with PlugmanX.
- Command replies and bridged messages render again on Paper 26.1.2.
```

The same change, the way agents write it: the summary repeats the title, the changes repeat the diff, the test
plan repeats CI, the "Not done" section belongs in an issue, and the footer is noise.

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
