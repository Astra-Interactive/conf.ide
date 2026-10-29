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

## Habits, not settings

- Run `/compact` before stepping away for an hour. The first message after the cache
  expires rewrites the whole conversation at 40 times the price of reading it.
- Compact earlier in long sessions: every call re-reads the whole conversation.
  `autoCompactWindow` in settings sets the threshold.
- Run `/context` to see the current split. The Atlassian, Figma, Chrome and walletbot
  MCP servers are likely the largest remaining share.

## Rollback

The previous settings are in `~/.claude/settings.json.bak-2026-10-30`.
