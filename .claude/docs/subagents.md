## Subagents

The harness caps how many subagents run at once and how deep they nest. This document says how to find
the cap, when to spawn a subagent, and which one.

Use the user's current division of work. A later instruction to implement personally or delegate a specific
part replaces the earlier assignment, without cancelling unrelated constraints. Give each worker the current
task-specific restrictions and approved exceptions; do not turn them into permanent rules for other tasks.

### Budget

* Read the cap before planning parallel work; do not assume it.
  - Claude Code: `printenv CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`.
    The first counts every running subagent of the session, helpers included. A spawn depth of 2 lets an
    agent the main thread started start helpers, which start none; 1 means a subagent starts none.
  - Codex: `max_concurrent_threads_per_session` under `[agents]` in `~/.codex/config.toml`.
  - Any other harness, or a value that is not set: ask the user once, and until then plan for two.
* The main thread runs at most two agents at a time. Plan the work in waves of two; the cap is the
  harness's limit for agents and their helpers together, not a target. A longer task list is queued by
  you, not by spawning everything and letting the harness refuse; a refused spawn is a planning error, not
  a retry.
* A writing agent edits files of a working tree ("Writes the tree" in Which agent). One works in a tree at
  a time, and the main thread counts as it while it edits that tree: a runner that builds while another
  writer is mid-edit reports failures that are not its writer's.
* Helpers. `implementer`, `debugger`, `detekt-rule-author` and `linter-rollout` start helpers of their
  own, at most two at a time: their runner (`gradle-check` or `cargo-check`; with both build tools, one
  after the other) and one of `lookup`, `test-triage`, `test-writer`, which may change between
  iterations. Helpers start none, and no other agent starts any. A helper is started without a model
  override and returns to the agent that started it. A `test-writer` helper runs in the foreground, and
  the runner is called after it returns. The `worker-guard.sh` hook holds the two lists and blocks every
  other start; change the hook, this paragraph and the `tools:` line (`Agent`, and `SendMessage` to
  reuse a helper) of the four agent files together. A session started with `--agent <name>` is that agent
  to the hook.
* The runner belongs to the agent that starts helpers. The main thread starts a runner for final
  validation and for the plain route (Tests and validation). Queue check requests and reuse the same
  runner across iterations. Serialize runs that share a working directory, Gradle daemon/cache or Cargo
  target directory. Before final validation and before a new writing agent starts,
  check that no build of the tree still runs: a Gradle wrapper client (`GradleWrapperMain`) or a `cargo`
  or `rustc` process whose working directory is inside the tree (`pgrep -fl`, then
  `lsof -a -d cwd -p <pid>`); an idle Gradle daemon does not count.
* A subagent is spawned when the work is independent of the main thread, or when its output is large
  and only a summary is needed (a Gradle run, a log, a web search). It is not spawned for a lookup
  that is three tool calls.
* Each subagent gets the task, the paths, and the base ref in the prompt. It does not get the story
  of the session. A brief to an implementer states the behaviour, the constraints and the design numbers
  (sizes, timings, limits) and names the skills that apply (`compose-hoisting`); the mechanism (where
  state lives, keys, hoisting) stays with those skills and the rule documents.
  A brief never moves a build, test or lint run from the runner to the worker; the operational actions
  of Tests and validation are the only builds a worker starts. It quotes an owner approval only in the
  owner's words.
  Before dispatch, check its working directory, actual tools, write scope, model/effort and ability to return the requested
  artifact. A role label is not proof of those capabilities; a read-only worker returns its report inline.
* Assign one writer to each shared path at a time. Workers return separate results; the main thread alone
  assembles the final report. Integrate shared prerequisites before dependent writers change the same files.
* Wait when the next step needs the result; otherwise continue independent work. Reuse a worker instead of
  repeated close/resume cycles without new input. Do not repeat a failed action without addressing its cause.
* Give the user concise updates on changed facts, remaining work and blockers, at the cadence required by
  the execution environment. Repeated polling is not progress to report.

### Which agent

| Need | Agent | Model | Writes the tree |
|---|---|---|---|
| A question about the code, no change wanted | `research-only` | opus | no |
| Where something is | `lookup` | sonnet | no |
| Run Gradle build, tests, detekt, lint, assemble | `gradle-check` | haiku | no |
| Run Cargo build, test, fmt check, clippy or klibs-rules | `cargo-check` | haiku | no |
| Implement specified test cases and fixtures | `test-writer` | haiku | yes |
| Explain red tests or red CI | `test-triage` | sonnet | no |
| A defined coding task | `implementer` | inherit | yes |
| Find and fix a bug | `debugger` | inherit | yes |
| Does the change match the task | `task-vs-diff-verifier` | sonnet | no |
| Does the change follow AGENTS.md | `agents-md-reviewer` | sonnet | no |
| Is the change correct: bugs, races, lifecycle, callers | `code-reviewer` | opus | no |
| Attack a design, plan or rule before it is built | `design-critic` | opus | no |
| Does a change to docs, skills, agents or AGENTS.md contradict the rest | `docs-consistency-reviewer` | opus | no |
| Commit and open the pull request | `pr-creator` | sonnet | for a version bump |
| Facts from the web, with sources | `search-specialist` | sonnet | no |
| Audit old Claude, Codex or Kimi sessions | `session-auditor` | sonnet | no |
| Record-by-record extraction from notes | `claim-extractor` | sonnet | no |
| A detekt or Konsist rule | `detekt-rule-author` | opus | yes |
| A linter version into one consumer repository | `linter-rollout` | sonnet | yes |
| Ansible playbooks and hosts | `ansible-ops` | sonnet | yes |
| Is the docker stack exposed | `docker-infra-reviewer` | sonnet | no |
| A Paper plugin config | `paper-plugin-config` | sonnet | yes |
| Build or port a third-party Paper plugin to a new server version | `paper-plugin-porter` | sonnet | yes |
| A Minecraft crash log | `minecraft-crash-analyst` | sonnet | no |
| A perps position against the playbook | `perps-risk-reviewer` | sonnet | no |
| A pre-registered strategy backtest | `trading-backtester` | opus | yes |

An agent that writes only its report into a folder the prompt names does not write the tree.

An agent's `color` names its role, and a new agent takes its role's color: `cyan` research and answers,
`yellow` review of a change, plan or position, `blue` builds, tests and diagnosis without a fix, `green`
writes code, `purple` git and pull requests, `red` changes live servers and hosts.

Coding work that no agent above specialises in (a bug's root cause goes to `debugger`, a rollout to
`linter-rollout`) goes to `implementer`, not to a general-purpose agent. A UI or multi-module task with a
written spec sends the spec to `design-critic` before the first implementer starts, unless it already
passed one (`brainstorming`). Before a pull request, `task-vs-diff-verifier`, `agents-md-reviewer` and
`code-reviewer` review the change (when: Tests and validation), and their findings are fixed before the
pull request is opened.

### Tests and validation

The main thread owns final judgment; test cases and expected behaviour belong to the agent that starts
`test-writer`. Requested test implementation goes to `test-writer` and every build, test and check
invocation to `gradle-check` or `cargo-check`, even when the work is sequential or the output is short.
Give the runner the exact working directory, toolchain and commands. The runner builds in the session's
tree, in a worktree or in another repository: its guard lets it move to the git top level of any of them.
For checks outside Gradle/Cargo, the main thread gives the exact command to a cheap execution agent it
dispatches, with the required tool scope; no additional role is needed.
If none is available, report blocked validation. Operational actions
such as deploying to a named test server and exercising an app's entry point stay with their specialist.
This includes `figma-pixel-verify`'s UI rendering and measurement harness for entry-point verification;
regression test implementation, regression runs and build matrices still follow the routes above.

Assign each test/fixture file to one writer, including a Rust source file with colocated tests. The
implementer must finish and hand off that file before the test writer edits it; never edit it concurrently.
The writer receives concrete cases, expected results, owned paths and an existing example. Ambiguous
semantics or difficult APIs return to the agent that started the test writer; the main thread may assign
the resolved work to sonnet (Codex Sol). This route does not authorize unrequested tests.

The check loop of an agent that starts helpers (Budget):

1. It sends its checks, the project's lint tasks included (`architectureLint` and `detekt` in Gradle;
   `cargo clippy` and `cargo klibs-rules` in Cargo), to its own runner, scoped to the modules it touched,
   with `--continue` in a request that names more than one Gradle task.
2. On a failure it may ask its own `test-triage`, fixes, and reruns the failed tasks only.
3. Its last run before it returns is the whole scoped set, after its last edit. It returns **ready for
   validation** with that run's evidence and the full CI task set as requested checks, not a done/green
   claim.

The plain route is for a worker the main thread started that starts no helpers, for an agent whose harness
gave it no way to start one, and for the main thread's own edits: the worker returns **ready for
validation** with requested commands, and the main thread's runner runs them, scoped to that worker's
modules; the main thread sends failures to `test-triage`, assigns the fix to the writing agent, and sends
the rerun to the runner. A worker that
needs an agent it may not start returns the request to its parent. When no build applies, the worker says
so and returns. No build applies to a change of documents or agent instructions only, with nothing a build
reads; a version catalog or a version bump needs runner evidence.

The main thread owns final validation: its runner runs the full CI task set of `definition-of-done` after
the last edit, a version bump included. A red result goes back to the same writing agent, and the full set
runs again after its fix. If a runner is unavailable, queue or reuse one, then report blocked validation;
neither the main thread nor a coding worker substitutes its own check run. A brief to a committing agent
carries the evidence of a run the main thread's runner made for that commit, or states that no build
applies; a committing agent that waits for it stays its tree's writing agent.

The reviewers start on a change once that validation is green, or no build applies, and their brief
carries the runner's lint output: the linter is the authority on what it checks, and a review builds on
its verdict. Before a pull request `code-reviewer` starts together with `task-vs-diff-verifier`, and
`agents-md-reviewer` starts when the first of them returns; the `code-review` skill keeps its own pair. A
reviewer runs beside a writing agent only on files that agent does not edit: its brief names the paths
under review, and it reads the diff of those paths only. After a finding is fixed and validation is green
again, the reviewer that raised it reviews the fix, which its brief names by file and finding; the others
do not run again.

Committing agents: `pr-creator`, `debugger`, `detekt-rule-author`, `linter-rollout`, `ansible-ops`,
`paper-plugin-config`. Pushing agents: `pr-creator`, `linter-rollout`; they push a feature branch only, never
with force and never to `main`, `master` or the default branch (`git-commits.md`). These lists are what the
`git-guard.sh` hook allows and what the SubagentStart/SubagentStop matchers in `.codex/hooks.json` name;
change the three together.

Exactly one authorized agent owns Git mutations at a time; `pr-creator` is the default, and a listed
committing specialist may own them when explicitly assigned. Before transferring ownership, establish the
state of its running command and the repository's HEAD/index. Closing or interrupting an agent does not
prove that a process it launched stopped. Reconcile completed operations before retrying; never run a second
commit or push while the first one's outcome is unknown. This changes ownership, not the permission lists.

### Codex

* `.codex/agents/*.toml` is generated from `.claude/agents/*.md` by `.codex/generate-agents.py`
  and is not in git. The `generate.sh` hook runs it at session start; never edit a `.toml` by hand.
* Codex gives a subagent no tool list, no hooks and no sandbox of its own, so the read-only guards
  are text in `developer_instructions` there. The agent is bound by them exactly as by the hook.
* The hooks in `.codex/hooks.json` run the scripts in `.claude/hooks`. Codex skips a new or changed
  hook until it is trusted in `/hooks`.
* The helper rules of Budget are text in Codex: no hook input names the caller there. One writing agent
  with two helpers and one agent that does not write fill a cap of four.
* Call `wait_agent` with `timeout_ms` of at least 300000: a wait that expires costs a model call. A runner
  polls a running command with waits of up to 300000 ms each.

### What every subagent must hear

* Read `AGENTS.md` and its General and Agents documents before the first tool call; the code rules load
  with the first code file you read or edit, and `AGENTS.md` says when to read them yourself. The
  reviewers in this list check against them; an implementer that skipped them fails the review.
* Navigation goes through `codebase-memory-mcp`, the LSP and `ksrc`. `grep`, `cat` and `find` over
  code are not navigation.
* Return the result in the output format the agent defines. No preamble, no method, no next steps.
