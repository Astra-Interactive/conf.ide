# Cheaper Claude Code sessions on macOS

Source: Ahmad Ghoniem, "Stretching the $20 sub by 30%: Claude Code's harness tax"
(https://x.com/aghoniem_/status/2107236820929094094). Applied on 2026-10-30 to
`~/.claude/settings.json` on Claude Code 2.1.312.

The harness is everything Claude Code sends around the model on every request: the
system prompt, the tool definitions, the skill list, the connector instructions and the
side requests it runs between turns. A stock install sends about 30k tokens per request.
Each item below removes a part of it.

## Not applicable on macOS

- The PowerShell tool deny: there is no PowerShell tool here.
- The Git Bash notes and the `--path-separator=/` ripgrep flag: Windows only.

## Applied

### Tools denied (`permissions.deny`)

| Tool | Cost per request | What is lost |
|---|---|---|
| `Artifact` | 11,325 tokens, plus two deferred helpers | Shareable claude.ai pages from the terminal. A local HTML file replaces them. |
| `Grep`, `Glob` | 1,553 tokens | Nothing: code search goes through codebase-memory-mcp and the LSP, and `rg` through Bash does the rest. |
| `ScheduleWakeup` | 1,695 tokens | `/loop` without an interval. `/loop 5m …` still works. |
| `ReportFindings` | 821 tokens | Typed `/code-review` output. Findings print as text. |
| `ListAgents` | 405 tokens | Messaging other sessions. Subagents still work. |

`enableArtifact: false` also removes the three artifact skills from the skill list.

### Connector dropped (`deniedMcpServers`)

`claude.ai Claude Docs`: 873 tokens of tools and instructions on every request.
`permissions.deny` would remove only the tools, `deniedMcpServers` removes both.

### Bundled skills made user-invoked (`skillOverrides`)

`claude-api`, `code-review`, `dataviz`, `schedule`, `loop`, `run`, `keybindings-help`,
`fewer-permission-prompts`, `simplify`, `security-review`, `init` are set to
`user-invocable-only`: `/name` still works, the description is no longer sent
(1,869 tokens). `syncClaudeAiSkills: false` stops syncing the claude.ai skills
(docs, docx, pptx, xlsx, pdf, google-workspace, skill-creator, morning, import-memory).

### System prompt and side requests

- `includeGitInstructions: false`: drops the commit and PR steps from the Bash
  description, the attribution reminder and the git status snapshot taken at session
  start and after each compaction (355 tokens, more inside a repository). The project's
  git-commits rule runs `git status` itself, so the snapshot was redundant.
- `promptSuggestionEnabled: false`: the greyed-out next prompt is a side request that
  re-reads the whole conversation (up to 4.6% of usage).
- `awaySummaryEnabled: false` was already set: the session recap written when the
  terminal loses focus (1.2% of usage).
- `CLAUDE_CODE_DISABLE_EXPLORE_PLAN_AGENTS=1` in `env`: removes the Explore and Plan
  subagents (333 tokens); the general-purpose subagent stays.

### ripgrep instead of the Grep tool

`~/.ripgreprc` gives `rg` the same flags the Grep tool used:

```ini
--hidden
--glob=!.git
--max-columns=500
--max-columns-preview
```

On macOS `rg` does not read this file by itself. `~/.zshrc` needs:

```sh
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"
```

Without `--hidden`, searches inside `.claude/` find nothing and cost extra turns.

## Subagent status summaries (unofficial preload)

Source: Flamerix AI, `no-agent-summary.js`
(https://gist.github.com/flamerix-ai/c3905705cc4205e5de3011fa2e74efce). Applied on 2026-10-30.

Claude Code runs a side request for every running subagent to produce the short status
label in the agents panel. Checked in the 2.1.312 binary: the default is one summary per
agent every 30 seconds in "full" mode; a server flag can stretch the interval to 240
seconds or switch to "short" mode, and the config schema has no "off" value. No setting
disables it (`CLAUDE_CODE_AGENT_PROGRESS_SUMMARIES` is the SDK's progress feature, not
this). It skips an agent whose transcript has not changed or has fewer than three
messages. The gist's author measured it at 16% of their spend. Here, over the 30 days
before 2026-10-30: 921 Agent launches, 523 Workflow launches, 237 sessions with a
subagent.

The script is a Bun `--preload` that wraps the global `setTimeout` and returns an inert
timer when the callback's source contains the summary anchors. The binary is untouched.

Installed:

- `~/.claude/no-agent-summary/no-agent-summary.js`, sha256
  `f95df896a998653ee86e7320ae9a29a547add4addd50cf631491dffaa6040b40`, 102 lines, reviewed:
  it only inspects timer callbacks by source text and writes files only when its env vars
  name them.
- `~/.zshrc`: `export BUN_OPTIONS="--preload=$HOME/.claude/no-agent-summary/no-agent-summary.js"`.

Verified with `claude --version` and `CC_AGENT_SUMMARY_MARKER=<file>`: the marker reads
`preload active mode=off bun=1.4.4 hooked=global.setTimeout`.

What it costs:

- The agents panel no longer updates per-agent status labels.
- It fails open. An update that renames the anchors silently brings the summaries back.
  After every Claude Code update, run:

  ```sh
  grep -a -c -F '[AgentSummary] Timer fired' "$(readlink -f "$(which claude)")"
  ```

  A zero means the hook is dead.
- It patches the client at runtime, which the author notes may conflict with the
  service's terms.

To measure instead of suppress, start a session with `CC_AGENT_SUMMARY_MODE=pass` and
`CC_AGENT_SUMMARY_LOG=/tmp/nas.log`: the log counts the timers without stopping them.
To remove it, delete the `BUN_OPTIONS` line from `~/.zshrc` and the folder.

## Habits, not settings

- Run `/compact` before stepping away for an hour. The first message after the cache
  expires rewrites the whole conversation at 40 times the price of reading it.
- Compact earlier in long sessions: every call re-reads the whole conversation.
  `autoCompactWindow` in settings sets the threshold.
- Run `/context` to see the current split. The Atlassian, Figma, Chrome and walletbot
  MCP servers are likely the largest remaining share.

## Rollback

The previous settings are in `~/.claude/settings.json.bak-2026-10-30`.
