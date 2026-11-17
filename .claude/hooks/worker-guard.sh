#!/bin/bash
# PreToolUse on Bash and Agent (Claude Code only): keeps the agents that may start helpers to their helpers
# and their checks on their runner (subagents.md). It reads agent_type, tool_name, tool_input.subagent_type,
# tool_input.model and tool_input.command. Without agent_type the caller is the main thread and passes.
# Agent: a caller in STARTERS may start a type in HELPERS without tool_input.model; any other start blocks.
# Bash, caller in STARTERS: the command is split on ; & && || | ( ) and newlines outside quotes; comments,
# redirections and here-document bodies are skipped, except a body or here-string fed to a shell, and the text
# of each $(...) and backtick substitution is a command of its own. From each part the leading VAR=value words,
# the words ! { } if then else elif do while until, and the wrappers command, exec, nohup, time, sudo
# [options], env [options], timeout [options] <duration> and nice [options] are dropped; a bash, sh, zsh or
# dash -c string is checked the same way. A part whose first remaining word is gradle, gradlew or a path
# ending in /gradlew blocks unless every argument asks for the version or help, as does a shell given such a
# file, cargo [+toolchain] [global options] build|b|check|c|test|t|clippy|klibs-rules|run|r|bench|nextest, or
# cargo ... fmt with --check.
# Empty or unparseable input passes. Exit 2 blocks with the reason on stderr, and so does an exception in
# the Python check or a python3 that cannot run on a call that needs its verdict.
# Written for bash 3.2.

# Change together with the Helpers paragraph of subagents.md (Budget) and the tools: line (Agent, SendMessage) of each starter's agent file.
STARTERS="implementer debugger detekt-rule-author linter-rollout"
HELPERS="gradle-check cargo-check lookup test-triage test-writer"

INPUT=$(cat)
# Inside a JSON string every quote is escaped, so these patterns match top-level keys only; no jq needed.
EVENT_RE='"hook_event_name"[[:space:]]*:[[:space:]]*"([^"\\]*)"'
AGENT_RE='"agent_type"[[:space:]]*:[[:space:]]*"([^"\\]*)"'
TOOL_RE='"tool_name"[[:space:]]*:[[:space:]]*"([^"\\]*)"'
[[ $INPUT =~ $EVENT_RE ]] && [ "${BASH_REMATCH[1]}" != PreToolUse ] && exit 0
[[ $INPUT =~ $AGENT_RE ]] && [ -n "${BASH_REMATCH[1]}" ] || exit 0
AGENT=${BASH_REMATCH[1]}
TOOL=""
[[ $INPUT =~ $TOOL_RE ]] && TOOL=${BASH_REMATCH[1]}
case "$TOOL" in
    Agent) ;;
    Bash)
        case " $STARTERS " in
            *" $AGENT "*) ;;
            *) exit 0 ;;
        esac
        ;;
    *) exit 0 ;;
esac

fail() {
    echo "BLOCKED by worker-guard: the check could not run ($1); report it to your parent." >&2
    exit 2
}

IFS= read -r -d '' PROGRAM <<'PYTHON'
import json
import os
import re
import shlex
import sys

STARTERS = os.environ["STARTERS"].split()
HELPERS = os.environ["HELPERS"].split()
SHELLS = {"bash", "sh", "zsh", "dash"}
DROPPED = {"command", "exec", "nohup", "time", "!", "{", "}", "if", "then", "else", "elif", "do", "while", "until"}
REDIRECTION = re.compile(r"^\d*(>>?|<|&>>?|>&|<&|>\|)(.*)$")
OPTION_VALUES = {"env": {"-u", "--unset", "-C", "--chdir", "-P"}, "timeout": {"-s", "-k", "--signal", "--kill-after"},
                 "nice": {"-n", "--adjustment"},
                 "sudo": {"-u", "--user", "-g", "--group", "-C", "--close-from", "-D", "--chdir", "-p", "--prompt",
                          "-r", "--role", "-t", "--type", "-T", "--command-timeout", "-U", "--other-user"}}
SHELL_OPTION_VALUES = {"-o", "+o", "-O", "+O"}
GRADLE_INFO = {"--version", "-v", "--help", "-h", "-?"}
CARGO_OPTION_VALUES = {"--color", "--config", "-Z", "-C", "--explain"}
CARGO_BLOCKED = {"build", "b", "check", "c", "test", "t", "clippy", "klibs-rules", "run", "r", "bench", "nextest"}
HEREDOC = re.compile(r"<<(-?)[ \t]*(['\"]?)\\?([A-Za-z0-9_.-]+)\2")
RUNNER_MESSAGE = "BLOCKED by worker-guard: send this command to your gradle-check or cargo-check"


def block(message):
    print(message, file=sys.stderr)
    sys.exit(2)


def skip_bodies(text, i, heredocs):
    for word, strip_tabs, body in heredocs:
        lines = []
        while i < len(text):
            end = text.find("\n", i)
            line = text[i:] if end == -1 else text[i:end]
            i = len(text) if end == -1 else end + 1
            if (line.lstrip("\t") if strip_tabs else line) == word:
                break
            lines.append(line)
        body.append("\n".join(lines))
    return i


def scan(text, i, nested, pieces):
    current, bodies, heredocs, quote, depth = [], [], [], None, 0

    def flush():
        nonlocal bodies
        piece = "".join(current).strip()
        if piece:
            pieces.append((piece, bodies))
        current.clear()
        bodies = []

    while i < len(text):
        char = text[i]
        previous = text[i - 1] if i > 0 else ""
        if quote != "'" and text.startswith("$(", i) and not text.startswith("$((", i):
            i = scan(text, i + 2, True, pieces)
            current.append("$(...)")
            continue
        if quote != "'" and char == "`":
            end = text.find("`", i + 1)
            end = len(text) if end == -1 else end
            scan(text[i + 1:end], 0, False, pieces)
            current.append("`...`")
            i = end + 1
            continue
        if quote:
            if char == "\\" and quote == '"' and i + 1 < len(text):
                current.append(text[i:i + 2])
                i += 2
                continue
            quote = None if char == quote else quote
        elif char == "\\" and i + 1 < len(text):
            current.append(text[i:i + 2])
            i += 2
            continue
        elif char in "'\"":
            quote = char
        elif char == "#" and (i == 0 or previous in " \t\n;&|()"):
            end = text.find("\n", i)
            i = len(text) if end == -1 else end
            continue
        elif text.startswith("<<", i) and not text.startswith("<<<", i) and HEREDOC.match(text, i):
            match = HEREDOC.match(text, i)
            body = []
            heredocs.append((match.group(3), match.group(1) == "-", body))
            bodies.append(body)
            current.append(match.group(0))
            i = match.end()
            continue
        elif char == "\n":
            flush()
            i = skip_bodies(text, i + 1, heredocs)
            heredocs = []
            continue
        elif char == ")":
            flush()
            if depth == 0 and nested:
                return i + 1
            depth = max(depth - 1, 0)
            i += 1
            continue
        elif char == "(":
            flush()
            depth += 1
            i += 1
            continue
        elif char == ";" or (char == "|" and previous != ">") or \
                (char == "&" and (i == 0 or previous not in "<>") and not text.startswith("&>", i)):
            flush()
            i += 1
            continue
        current.append(char)
        i += 1
    flush()
    return len(text)


def words_of(piece):
    try:
        words = shlex.split(piece)
    except ValueError:
        words = piece.split()
    kept, herestrings, skip = [], [], False
    for index, word in enumerate(words):
        if skip:
            skip = False
            continue
        if word.startswith("<<<"):
            herestrings.append(word[3:] or (words[index + 1] if index + 1 < len(words) else ""))
            skip = not word[3:]
        elif word.startswith("<<"):
            skip = not word[2:].strip("-'\"\\")
        elif REDIRECTION.match(word):
            skip = not REDIRECTION.match(word).group(2)
        else:
            kept.append(word)
    return kept, herestrings


def drop_options(words, wrapper):
    values = OPTION_VALUES[wrapper]
    while words and words[0].startswith("-") and words[0] != "--":
        option = words.pop(0)
        if wrapper == "env" and option in ("-S", "--split-string") and words:
            script = words.pop(0)
            words = words_of(script)[0] + words
        elif option in values and words:
            words.pop(0)
    if words and words[0] == "--":
        words.pop(0)
    return words


def command_words(words):
    while words:
        first = words[0]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", first) or first in DROPPED:
            words = words[1:]
        elif first in OPTION_VALUES:
            words = drop_options(words[1:], first)
            if first == "timeout" and words:
                words = words[1:]
        else:
            break
    return words


def builds_gradle(words):
    if not (words[0] in ("gradle", "gradlew") or words[0].endswith("/gradlew")):
        return False
    return not words[1:] or not all(arg in GRADLE_INFO for arg in words[1:])


def shell_script(words):
    for index, word in enumerate(words[1:], start=1):
        if re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", word):
            return words[index + 1] if index + 1 < len(words) else None
    return None


def shell_operands(words):
    index = 1
    while index < len(words) and words[index][:1] in ("-", "+"):
        index += 2 if words[index] in SHELL_OPTION_VALUES else 1
    return words[index:]


def runs_cargo_check(args):
    if args and args[0].startswith("+"):
        args = args[1:]
    while args and args[0].startswith("-"):
        args = args[2:] if args[0] in CARGO_OPTION_VALUES else args[1:]
    if not args:
        return False
    return args[0] in CARGO_BLOCKED or (args[0] == "fmt" and "--check" in args[1:])


def check_command(text, level=0):
    pieces = []
    scan(text.replace("\\\n", ""), 0, False, pieces)
    for piece, bodies in pieces:
        words, herestrings = words_of(piece)
        words = command_words(words)
        if not words or words[0] == "cd":
            continue
        name = os.path.basename(words[0])
        if name in SHELLS:
            script = shell_script(words)
            operands = shell_operands(words)
            options = words[1:len(words) - len(operands)]
            reads_stdin = not operands or any(re.fullmatch(r"-[A-Za-z]*s[A-Za-z]*", word) for word in options)
            if script is not None and level < 5:
                check_command(script, level + 1)
            elif script is None and reads_stdin and level < 5:
                for body in ["".join(body) for body in bodies] + herestrings:
                    check_command(body, level + 1)
            elif script is None and operands and builds_gradle(operands):
                block(RUNNER_MESSAGE)
        elif builds_gradle(words):
            block(RUNNER_MESSAGE)
        elif name == "cargo" and runs_cargo_check(words[1:]):
            block(RUNNER_MESSAGE)


def check_agent(caller, tool_input):
    if caller not in STARTERS:
        block(f"BLOCKED by worker-guard: {caller} starts no agents; return the request to your parent (subagents.md)")
    if tool_input.get("subagent_type") in HELPERS and not tool_input.get("model"):
        return
    block(f"BLOCKED by worker-guard: {caller} starts only {', '.join(HELPERS)}, without a model override; "
          f"return the request to your parent (subagents.md)")


try:
    payload = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
if not isinstance(payload, dict) or payload.get("hook_event_name") not in (None, "", "PreToolUse"):
    sys.exit(0)
caller = payload.get("agent_type")
tool_input = payload.get("tool_input")
if not isinstance(caller, str) or not caller or not isinstance(tool_input, dict):
    sys.exit(0)
try:
    if payload.get("tool_name") == "Agent":
        check_agent(caller, tool_input)
    elif payload.get("tool_name") == "Bash" and caller in STARTERS and isinstance(tool_input.get("command"), str):
        check_command(tool_input["command"])
except Exception as error:
    block(f"BLOCKED by worker-guard: the check failed ({type(error).__name__}: {error}); report it to your parent.")
PYTHON

command -v python3 >/dev/null 2>&1 || fail "python3 not found"
printf '%s' "$INPUT" | STARTERS="$STARTERS" HELPERS="$HELPERS" python3 -I -c "$PROGRAM"
STATUS=$?
case "$STATUS" in
    0|2) exit "$STATUS" ;;
esac
fail "python3 exited with $STATUS"
