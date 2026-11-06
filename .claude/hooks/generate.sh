#!/bin/bash
# Regenerates the files that are not in git: .claude/rules from .claude/docs and .codex/agents
# from .claude/agents. Runs at session start and from link-consumer.sh. Resolves its physical path,
# so a consumer repository whose .claude/hooks is a symlink regenerates the conf.ide checkout.

set -u

HOOKS=$(cd "$(dirname "$0")" && pwd -P)
CONF=$(cd "$HOOKS/../.." && pwd)

python3 "$CONF/.claude/hooks/generate-rules.py" || exit 1
python3 "$CONF/.codex/generate-agents.py" || exit 1
