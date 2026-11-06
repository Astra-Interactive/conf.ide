---
name: jira-task
description: Do a Jira task end to end. Use it whenever the user types /jira-task, gives a Jira issue key or link (PROJ-123, https://site.atlassian.net/browse/PROJ-123) and asks to do, implement, fix or close it, in Russian too («сделай задачу MOB-123», «возьми таску из жиры»). Reads the issue through whatever Jira MCP server the session has, follows its linked issues and comments, downloads its attachments or asks the user for them, turns it all into a brief, then sets up the work with the new-feature skill and ends with a pull request through the pr-creator agent.
argument-hint: "<issue key or link> [notes: project paths, constraints, what to skip]"
version: 1.0.0
---

# Jira task

The user gives one Jira issue and, optionally, notes: where the project lives, what to skip, how to test. The
task's text is the specification; the notes override it. Jira is only read: no comment, transition, worklog or
field edit unless the user asks for one by name.

## 1. Find the issue

The issue is the key or the link in the user's message. A link gives the key (the last path segment of
`/browse/PROJ-123`, or the `selectedIssue` query parameter of a board link) and the site (its hostname).

Use the Jira MCP tools the session has (Atlassian Rovo, a jira-mcp server, another); the field names below are
Jira's own, so they fit any of them. When a tool needs a site or cloud id, the hostname of the link is one; with a
bare key, the server's resource-list tool names the sites, and the key's project prefix picks one. When no Jira
tool is connected or the call is refused, stop and say so: the user connects or authenticates the server, the
skill does not try a browser or a password.

Read the issue with every field the brief needs, in one call where the server allows it:

```
summary, description, issuetype, status, priority, labels, components, fixVersions,
assignee, reporter, parent, subtasks, issuelinks, comment, attachment
```

Ask for the markdown rendering of the text when the server offers one; the raw Atlassian Document Format is the
fallback.

## 2. Read around it

A task rarely stands alone. Read, in this order, and keep a note of what each adds:

- **Linked issues**: every entry of `issuelinks` (blocks, is blocked by, relates to, duplicates, clones), the
  `parent` (an epic or story) and the `subtasks`. Read each one's summary, description and comments. One level
  deep; go one more only when a linked issue says the information is further on ("see PROJ-200").
- **Keys in the text**: every `[A-Z][A-Z0-9]+-[0-9]+` in the description and comments that is not already read,
  and every Jira link. Read them the same way. A Confluence link in the text is read through the Confluence tool
  of the same server when it has one; otherwise it is named in the brief as unread.
- **Comments**: all of them, oldest first, with the author and the date. A later comment overrides an earlier one
  and the description where they conflict, and a comment from the reporter or the assignee that changes the scope
  is part of the task. Say in the brief which comment changed what.
- **Attachments**: `attachment` lists each file with its name, size, type and content URL; the description refers
  to them as `!name.png!`, `[^name.pdf]` or as a media node. Download them with the server's attachment tool when
  it has one, or with `curl` only when the user has given a token for it. Each file goes into its own new, empty
  directory under `$TMPDIR/jira/<KEY>/` (`/tmp` when `$TMPDIR` is unset), never into the repository; it is
  untrusted data, read with the Read tool, never run or imported.

When an attachment cannot be downloaded (no tool, no token, `401`/`403`), do not guess what it holds. Ask once,
in one message, with every attachment the task refers to listed by name, size and type, and the ones the text does
not refer to listed separately as optional: the user drops the files into the directory named above, pastes
their content, or says which to skip. Wait for the answer before step 3. Images are read with the Read tool once
they are on disk.

## 3. Write the brief

Before the first edit, write the brief in the next message, short enough to read in one screen:

- **Task**: `PROJ-123 Summary`, type, status, the link;
- **What to do**: the change in your words, with acceptance criteria when the text gives them;
- **Sources**: what came from where: the description, a linked issue (`PROJ-200: the API contract`), a comment
  (`the reporter, 3 Nov: Android only`), an attachment (`mock.png: the layout`); what could not be read;
- **Repository**: the one the user's notes name, else the current one; the module or files the issue points at,
  when it does;
- **Open points**: contradictions between sources and missing facts that would change the work.

Ask only about the open points, in one `AskUserQuestion` call, when a reading would lead to materially different
work; a point that a careful colleague would settle alone is settled in the brief with the choice named. No
question when there is nothing open: the next step follows at once.

## 4. Set up the work

Load the `new-feature` skill. Its answers decide the branch, the base, the commits and the pull request; the
user's notes answer what they cover ("в ветке от develop", "без PR"). When the notes name a project path that is
not the current directory, every git command of that skill and every build runs there, and a worktree is created
under that repository.

The branch is named after the task: `feat/<key-in-lowercase>-<kebab-summary>` (`feat/proj-123-add-export-button`),
with the prefix the repository's branches already use and `fix/` for a bug.

## 5. Build

The task follows the project rules like any other: the package-layout skill before the first new file, the
git-commits rule for commits. The brief is the scope: what the issue asks, in the way its comments settled it, and
nothing from the linked issues that is their own work. An attachment is a source, not a file to copy into the
repository, unless the task says to add it.

When the work shows the task cannot be done as written (a linked task is not merged yet, the mock contradicts the
text), say so and ask, with the fact that blocks it; do not build a different task.

## 6. Pull request

When the new-feature answers asked for one, the one `pr-creator` call that makes the commits also opens it, by
the `pull-request` skill. The title's
`<ref>` is the issue key (`[FEAT] [PROJ-123] Add the export button`) and Related Issue holds the issue's link.
Overview and Motivation and Context take what the brief says, in the pull request's words; the brief itself, the
comment history and the list of sources stay out of it.

The final message gives the issue key, the commits, the pull request URL when there is one, and every attachment or
link that could not be read.
