---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Write a handoff document summarising the current conversation so a fresh agent can continue the work.

Before writing, ask the user where to save it, unless their message already says. Offer two places, each with its absolute path resolved, `<topic>` being the work in kebab-case:

- a local file in the repository: `<repository root>/.claude/handoff/<YYYY-MM-DD>-<topic>.md`. It stays out of git: when `git check-ignore -q <path>` fails, add `.claude/handoff/` to the file `git rev-parse --git-path info/exclude` prints;
- the temporary directory of the user's OS (`$TMPDIR`, else `/tmp`; `%TEMP%` on Windows): `handoff-<YYYY-MM-DD>-<topic>.md` there.

Write the document to the place the user picked, then print its absolute path.

Include a "suggested skills" section in the document, naming which skills the next agent should call the Skill tool for.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
