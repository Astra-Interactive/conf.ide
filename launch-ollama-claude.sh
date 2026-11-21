#!/bin/bash
# Launches Claude Code against the Ollama server at 127.0.0.1:11434 with a separate model for
# the session and for the opus/sonnet/haiku agent aliases:
#   launch-ollama-claude.sh [--model <tag>] [--opus <tag>] [--sonnet <tag>] [--haiku <tag>]
#                           [--dry-run] [-- <claude args> ...]
#
# `ollama launch claude` sets ANTHROPIC_DEFAULT_OPUS_MODEL, ANTHROPIC_DEFAULT_SONNET_MODEL,
# ANTHROPIC_DEFAULT_HAIKU_MODEL and CLAUDE_CODE_SUBAGENT_MODEL to its --model value, so every
# agent runs on the session model. This script skips that launcher and starts claude directly:
# the ollama server speaks the Anthropic API, and ANTHROPIC_DEFAULT_*_MODEL map the agent
# aliases from .claude/agents/*.md (`model: opus`, `model: sonnet`, `model: haiku`) to Ollama
# tags. CLAUDE_CODE_SUBAGENT_MODEL is removed: set, it would override every agent's model.
#
# Defaults are the chosen analogues of the Claude models: deepseek-v4.1-flash:cloud for the
# session, kimi-k3.1-pro:cloud for opus, glm-5.3-flash:cloud for sonnet and gemma4:31b-cloud for
# haiku. Environment variables from a parent session are ignored, so the defaults hold wherever the
# script starts; a flag is the way to change one. Written for bash 3.2.

set -u

BASE_URL="http://127.0.0.1:11434"
MODEL="deepseek-v4.1-flash:cloud"
OPUS_MODEL="kimi-k3.1-pro:cloud"
SONNET_MODEL="glm-5.3-flash:cloud"
HAIKU_MODEL="gemma4:31b-cloud"
DRY_RUN=0
CLAUDE_ARGS=()

usage() {
    echo "usage: $0 [--model <tag>] [--opus <tag>] [--sonnet <tag>] [--haiku <tag>] [--dry-run] [-- <claude args> ...]" >&2
}

need_value() {
    [ $# -ge 2 ] || { echo "$1 needs a model tag" >&2; usage; exit 2; }
}

while [ $# -gt 0 ]; do
    case "$1" in
        --model) need_value "$@"; MODEL="$2"; shift 2 ;;
        --opus) need_value "$@"; OPUS_MODEL="$2"; shift 2 ;;
        --sonnet) need_value "$@"; SONNET_MODEL="$2"; shift 2 ;;
        --haiku) need_value "$@"; HAIKU_MODEL="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --) shift; CLAUDE_ARGS=("$@"); break ;;
        -h | --help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

if ! curl -fsS --max-time 3 "$BASE_URL/api/version" > /dev/null 2>&1; then
    echo "ollama does not answer at $BASE_URL: open Ollama.app or run 'ollama serve'" >&2
    exit 1
fi

for tag in "$MODEL" "$OPUS_MODEL" "$SONNET_MODEL" "$HAIKU_MODEL"; do
    if ! ollama list 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -q -x -F "$tag"; then
        echo "warning: $tag is not in 'ollama list' (ollama pull $tag)" >&2
    fi
done

echo "session: $MODEL"
echo "opus:    $OPUS_MODEL"
echo "sonnet:  $SONNET_MODEL"
echo "haiku:   $HAIKU_MODEL"

ENV=(
    ANTHROPIC_BASE_URL="$BASE_URL"
    ANTHROPIC_AUTH_TOKEN=ollama
    ANTHROPIC_MODEL="$MODEL"
    ANTHROPIC_DEFAULT_OPUS_MODEL="$OPUS_MODEL"
    ANTHROPIC_DEFAULT_SONNET_MODEL="$SONNET_MODEL"
    ANTHROPIC_DEFAULT_HAIKU_MODEL="$HAIKU_MODEL"
    ANTHROPIC_SMALL_FAST_MODEL="$HAIKU_MODEL"
)

if [ $DRY_RUN -eq 1 ]; then
    printf 'env -u CLAUDE_CODE_SUBAGENT_MODEL'
    printf ' %q' "${ENV[@]}"
    printf ' claude --model %q' "$MODEL"
    [ ${#CLAUDE_ARGS[@]} -eq 0 ] || printf ' %q' "${CLAUDE_ARGS[@]}"
    printf '\n'
    exit 0
fi

exec env -u CLAUDE_CODE_SUBAGENT_MODEL "${ENV[@]}" claude --model "$MODEL" ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}
