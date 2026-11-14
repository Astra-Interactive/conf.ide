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
* While checks are pending, reserve one child slot for a runner; otherwise all slots may do useful work.
  Queue check requests and reuse the same runner across iterations. Serialize runs that share a working
  directory, Gradle daemon/cache or Cargo target directory.
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
| Run Gradle build, tests, detekt, lint, assemble | `gradle-check` | haiku |
| Run Cargo build, test, fmt check or clippy | `cargo-check` | haiku |
| Implement specified test cases and fixtures | `test-writer` | haiku |
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

An agent's `color` names its role, and a new agent takes its role's color: `cyan` research and answers,
`yellow` review of a change, plan or position, `blue` builds, tests and diagnosis without a fix, `green`
writes code, `purple` git and pull requests, `red` changes live servers and hosts.

Coding work that no agent above specialises in (a bug's root cause goes to `debugger`, a rollout to
`linter-rollout`) goes to `implementer`, not to a general-purpose agent. Before a pull request,
`task-vs-diff-verifier`, `agents-md-reviewer` and `code-reviewer` review the change, and their findings
are fixed before the pull request is opened.

### Tests and validation

The main thread owns test cases, expected behaviour and final judgment. Delegate requested test
implementation to `test-writer` and every build, test and check invocation to `gradle-check` or
`cargo-check`, even when the work is sequential or the output is short. Give the runner the exact working
directory, toolchain and commands. For checks outside Gradle/Cargo, give the exact command to a
parent-dispatched cheap execution agent with the required tool scope; no additional role is needed.
If none is available, report blocked validation. Operational actions
such as deploying to a named test server and exercising an app's entry point stay with their specialist.
This includes `figma-pixel-verify`'s UI rendering and measurement harness for entry-point verification;
regression test implementation, regression runs and build matrices still follow the routes above.

Assign each test/fixture file to one writer, including a Rust source file with colocated tests. The
implementer must finish and hand off that file before the test writer edits it; never edit it concurrently.
The writer receives concrete cases, expected results, owned paths and an existing example. Ambiguous
semantics or difficult APIs return to the main thread, which may assign the resolved work to sonnet
(Codex Sol). This route does not authorize unrequested tests.

Workers return **ready for validation** with requested commands, not a done/green claim without runner
evidence after the last edit. The main thread sends failures to `test-triage`, assigns the fix to the
appropriate writer, and sends the rerun to the runner. It owns final validation and passes fresh evidence
to committing agents. A worker that needs another agent returns the request to its parent: no nesting.
If a runner is unavailable, queue or reuse one, then report blocked validation; neither the main thread
nor a coding worker substitutes its own check run.

Committing agents: `pr-creator`, `debugger`, `detekt-rule-author`, `linter-rollout`, `ansible-ops`,
`paper-plugin-config`. Pushing agents: `pr-creator`, `linter-rollout`; they push a feature branch only, never
with force and never to `main`, `master` or the default branch (`git-commits.md`). These lists are what the
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
