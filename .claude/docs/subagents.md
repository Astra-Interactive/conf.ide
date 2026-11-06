## Subagents

The harness caps how many subagents run at once and how deep they nest. This document says how to find
the cap, when to spawn a subagent, and which one.

### Budget

* Read the cap before planning parallel work; do not assume it.
  - Claude Code: `printenv CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`
    (set in `~/.claude/settings.json` under `env`). A spawn depth of 1 means a subagent spawns none.
  - Codex: `max_concurrent_threads_per_session` under `[agents]` in `~/.codex/config.toml`.
  - Any other harness, or a value that is not set: ask the user once, and until then plan for two.
* Plan the work in waves of that size. A task list longer than the cap is queued by you, not by
  spawning everything and letting the harness refuse; a refused spawn is a planning error, not a retry.
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
| A defined coding task | `implementer` | inherit |
| Find and fix a bug | `debugger` | inherit |
| Does the change match the task | `task-vs-diff-verifier` | sonnet |
| Does the change follow AGENTS.md | `agents-md-reviewer` | sonnet |
| Is the change correct: bugs, races, lifecycle, callers | `code-reviewer` | opus |
| Attack a design, plan or rule before it is built | `design-critic` | opus |
| Does a change to docs, skills, agents or AGENTS.md contradict the rest | `docs-consistency-reviewer` | opus |
| Commit and open the pull request | `pr-creator` | sonnet |
| Facts from the web, with sources | `search-specialist` | sonnet |
| Audit old Claude, Codex or Kimi sessions | `session-auditor` | sonnet |
| Record-by-record extraction from notes | `claim-extractor` | sonnet |
| A detekt or Konsist rule | `detekt-rule-author` | opus |
| A linter version into one consumer repository | `linter-rollout` | sonnet |
| Ansible playbooks and hosts | `ansible-ops` | sonnet |
| Is the docker stack exposed | `docker-infra-reviewer` | sonnet |
| A Paper plugin config | `paper-plugin-config` | sonnet |
| Build or port a third-party Paper plugin to a new server version | `paper-plugin-porter` | sonnet |
| A Minecraft crash log | `minecraft-crash-analyst` | sonnet |
| A perps position against the playbook | `perps-risk-reviewer` | sonnet |
| A pre-registered strategy backtest | `trading-backtester` | opus |

Coding work that no agent above specialises in (a bug's root cause goes to `debugger`, a rollout to
`linter-rollout`) goes to `implementer`, not to a general-purpose agent. Before a pull request,
`task-vs-diff-verifier`, `agents-md-reviewer` and `code-reviewer` review the change, and their findings
are fixed before the pull request is opened.

Committing agents: `pr-creator`, `debugger`, `detekt-rule-author`, `linter-rollout`, `ansible-ops`,
`paper-plugin-config`. Pushing agents: `pr-creator`, `linter-rollout`. These lists are what the
`git-guard.sh` hook allows and what the SubagentStart/SubagentStop matchers in `.codex/hooks.json` name;
change the three together.

### Codex

* `.codex/agents/*.toml` is generated from `.claude/agents/*.md` by `.codex/generate-agents.py`
  and is not in git. The `generate.sh` hook runs it at session start; never edit a `.toml` by hand.
* Codex gives a subagent no tool list, no hooks and no sandbox of its own, so the read-only guards
  are text in `developer_instructions` there. The agent is bound by them exactly as by the hook.
* The hooks in `.codex/hooks.json` run the scripts in `.claude/hooks`. Codex skips a new or changed
  hook until it is trusted in `/hooks`.

### What every subagent must hear

* Read `AGENTS.md` and the documents it links before the first tool call; the code rules load with
  every code file you read or edit. The reviewers in this list check against them; an implementer
  that skipped them fails the review.
* Navigation goes through `codebase-memory-mcp`, the LSP and `ksrc`. `grep`, `cat` and `find` over
  code are not navigation.
* Return the result in the output format the agent defines. No preamble, no method, no next steps.
