## Subagents

The user's budget allows two subagents at a time and no nesting. This document says when to spawn one
and which one.

### Budget

* At most two subagents run at once; a subagent spawns none. These are the harness limits
  (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=2`, spawn depth 1); an orchestrator plans for them instead of
  queueing ten.
* A subagent is spawned when the work is independent of the main thread, or when its output is large
  and only a summary is needed (a Gradle run, a log, a web search). It is not spawned for a lookup
  that is three tool calls.
* Each subagent gets the task, the paths, and the base ref in the prompt. It does not get the story
  of the session.
* No intermediate reports to the user while subagents run. The user reads the result.

### Which agent

| Need | Agent | Model |
|---|---|---|
| A question about the code, no change wanted | `research-only` | opus |
| Where something is | `lookup` | sonnet |
| Run tests, detekt, lint, assemble | `gradle-check` | haiku |
| Explain red tests or red CI | `test-triage` | sonnet |
| Find and fix a bug | `debugger` | inherit |
| Does the change match the task | `task-vs-diff-verifier` | sonnet |
| Does the change follow AGENTS.md | `agents-md-reviewer` | sonnet |
| Commit and open the pull request | `pr-creator` | sonnet |
| Facts from the web, with sources | `search-specialist` | sonnet |
| A detekt or Konsist rule | `detekt-rule-author` | opus |
| A linter version into one consumer repository | `linter-rollout` | sonnet |
| Ansible playbooks and hosts | `ansible-ops` | sonnet |
| Is the docker stack exposed | `docker-infra-reviewer` | sonnet |
| A Paper plugin config | `paper-plugin-config` | sonnet |
| A Minecraft crash log | `minecraft-crash-analyst` | sonnet |
| A perps position against the playbook | `perps-risk-reviewer` | sonnet |

### What every subagent must hear

* Read `AGENTS.md` and the documents it links before the first tool call. The reviewers in this list
  check against them; an implementer that skipped them fails the review.
* Navigation goes through `codebase-memory-mcp`, the LSP and `ksrc`. `grep`, `cat` and `find` over
  code are not navigation.
* Return the result in the output format the agent defines. No preamble, no method, no next steps.
