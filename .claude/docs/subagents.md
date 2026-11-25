## Subagents

The main thread is the orchestrator. It defines the outcome, assigns owners, reconciles evidence and
communicates with the user. Delegate investigation, implementation, command execution, runtime checks
and Git operations to the appropriate agent below. The user's current division of work takes precedence.

### Assignment and context

Give an agent the goal, acceptance criteria, relevant paths, base revision, owned files and current
constraints. Include one falsifiable example before an expensive design decision. Link applicable rules
and existing evidence instead of copying the session history or complete logs. On a follow-up, send the
changed requirements or evidence and reuse the agent's existing context.

Assign one owner per operation and one writer per path. Integrate prerequisites before dependent edits.
A reviewer or runner works on a stable state of its assigned paths. Independent work may proceed in
parallel within the harness capacity. Before dispatch, check the agent's actual tools, write scope and
ability to produce the requested result.

Read the harness capacity once before parallel work. Claude Code exposes
`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` and `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`; Codex uses
`max_concurrent_threads_per_session` in `~/.codex/config.toml`. With no reported capacity, start with two.
Reserve capacity for required helpers and queue excess work. Agent capacity and local CPU/RAM capacity
are separate limits. Reuse an active runner and serialize checks sharing a working tree or conflicting
build resources. Before changing a tree with a pending build, establish that the build has ended.

Helpers remain limited to `implementer`, `debugger`, `detekt-rule-author` and `linter-rollout`. Each may
start a runner (`gradle-check` or `cargo-check`) and one of `lookup`, `test-triage`, `test-writer`, within
the harness limits. Helpers start none. Give a test writer exclusive ownership and wait for its return
before building that state. The allowed lists also live in `worker-guard.sh` and the four roles' tools.

The operation owner reports a result, material blocker or requested milestone. Wait for its message
when dependent work is next. Only that owner polls its running command. After a lost message or process,
reconcile its state once before retrying. Use wait durations supported by the current harness. Repeated
unchanged polling adds no progress report.

### Which agent

| Need | Agent | Model | Writes files |
|---|---|---|---|
| Explain code or investigate a cause | `research-only` | opus | no |
| Locate a symbol or configuration | `lookup` | sonnet | no |
| Gradle build, test or lint | `gradle-check` | haiku | no |
| Cargo build, test or lint | `cargo-check` | haiku | no |
| Specified tests and fixtures | `test-writer` | haiku | yes |
| Unexplained or repeated check failure | `test-triage` | sonnet | no |
| Defined implementation | `implementer` | inherit | yes |
| Find and fix a bug | `debugger` | inherit | yes |
| Independent review of an ordinary change | `code-reviewer` | opus | no |
| Additional task coverage review | `task-vs-diff-verifier` | sonnet | no |
| Additional standards review | `agents-md-reviewer` | sonnet | no |
| Review a consequential design decision | `design-critic` | opus | no |
| Independent review of agent instructions | `docs-consistency-reviewer` | opus | no |
| Commit and authorized PR publication | `pr-creator` | sonnet | no |
| Web facts with sources | `search-specialist` | sonnet | no |
| Past sessions | `session-auditor` | sonnet | report only |
| Mechanical claim extraction | `claim-extractor` | sonnet | report only |
| Detekt or Konsist rule | `detekt-rule-author` | opus | yes |
| Consumer linter rollout | `linter-rollout` | sonnet | yes |
| Ansible provisioning | `ansible-ops` | sonnet | yes |
| Docker network exposure audit | `docker-infra-reviewer` | sonnet | no |
| Paper plugin configuration | `paper-plugin-config` | sonnet | yes |
| Build or port a Paper plugin | `paper-plugin-porter` | sonnet | yes |
| Minecraft crash analysis | `minecraft-crash-analyst` | sonnet | no |
| Perpetual futures position risk | `perps-risk-reviewer` | sonnet | no |
| Trading backtest | `trading-backtester` | opus | yes |

Use the specialist for its domain. Research ends when the requested question has a supported answer.
Implementation, builds and PR review enter the route when the task requests a changed artifact.
An independent design check is useful before implementation when a disputed contract or expensive
decision could invalidate the work. It is required when the user explicitly requests it.

### Tests and validation

`definition-of-done` owns selection of evidence, local check scope and the need for runtime validation.
The orchestrator accepts current evidence from the assigned runner, including an implementer's helper.
A second runner pass is required only when the state, environment or coverage makes that evidence stale.

Every Gradle/Cargo check goes through its runner. Give it the working directory, toolchain, commands and
covered state. For other executable checks, assign an execution agent with the needed tools. Operational
checks on a device, server or browser stay with their specialist. Request tests from `test-writer` with
concrete expected behaviour, exclusive file ownership and an existing example when tests are warranted.

The runner returns command, exit code, covered paths/revision including working changes, environment,
relevant diagnostics and a log/report pointer. Cached or up-to-date results are identified as reused.
The orchestrator reconciles this evidence with the final diff. Evidence for unchanged covered content
and the same relevant environment remains usable across agents and commits. A relevant edit invalidates
the affected evidence. Repeat those checks and affected consumer checks.

On a failure, send evidence to the current author first. The author fixes a clear cause in their change.
Use `test-triage` for an unknown cause, a repeated failure, flaky behaviour or a shared environment issue.
Preserve failing outcomes and analysis limitations. Unavailable required validation remains pending.

### Independent review

Assign one independent reviewer for an ordinary change. `code-reviewer` covers task requirements,
correctness and applicable repository rules. For instruction changes, `docs-consistency-reviewer`
covers those criteria and dependent instruction consistency. Add a specialist for an identified risk
or the user's explicit request. A review already covering the same final state and criteria counts
for publication.

Start review and validation together once the relevant diff is stable. The reviewer receives current
check outcomes before its final verdict. Resolve findings and required validation before publication.
After a fix, the reviewer checks the affected finding and integration. Unchanged review evidence stands.
Report CI still running or unavailable accurately. Required PR CI must pass before merge, which remains
the user's operation.

### Git ownership

Committing agents are `pr-creator`, `debugger`, `detekt-rule-author`, `linter-rollout`, `ansible-ops` and
`paper-plugin-config`. Pushing agents are `pr-creator` and `linter-rollout`. They publish authorized
feature branches under `git-commits.md` and `pull-request`. These lists also live in `git-guard.sh` and
the SubagentStart/SubagentStop matchers in `.codex/hooks.json`; change them together when changing roles.

Exactly one authorized agent owns Git mutations at a time. Before a handoff or interrupted-operation
retry, establish actual HEAD/index and whether its command ended. Reconcile completed operations before
starting another commit or push. Commit only the reviewed state with accepted validation evidence.
Finish product changes, including an authorized version bump, before that validation.

### Context and reporting

Read the current repository entry point and applicable rules as `AGENTS.md` directs. Reuse them in the
same agent while unchanged. Keep reports proportional to the assignment. A handoff identifies changed
paths and covered state, behaviour delivered, evidence and remaining blockers. Use a requirement table
for several independent requirements. Keep full command logs at their report paths.

`.codex/agents/*.toml` is generated from `.claude/agents/*.md` by `.codex/generate-agents.py` and is
ignored by Git. The `generate.sh` session hook refreshes it. Codex guards are instructions in generated
`developer_instructions`, and bind agents even where hooks are unavailable. New or changed hooks need
the harness's normal trust activation. Editing an instruction source alone does not establish activation.
