#!/bin/bash
# PreToolUse on Bash (Claude Code and Codex): enforces git-commits.md on git commands.
# Denied for everyone: git add -A, --all or .; git commit -a or --all; --author or a Co-authored-by
# trailer on a commit; a forced push (--force, -f, --force-with-lease, a +refspec); commit --amend when
# HEAD is already on a remote branch. git commit runs only in a committing agent, git push only in a
# pushing agent. The agent is agent_type in Claude Code. Codex gives PreToolUse no agent field, so there a
# window-<agent>-<session_id> file younger than 2 hours, written by pr-creator-window.sh, stands for it.
# Without either the caller is the main thread, which neither commits nor pushes.
# The command is split on ; & | ( ) and newlines outside quotes; heredoc bodies and comments are skipped,
# a $(...) and a bash/sh -c string are checked as commands of their own, and git -C <dir> and the other
# global options are stripped. Exit 2 blocks with the reason on stderr; exits 0 outside a git repository.
# Written for bash 3.2.

# The "Committing agents" and "Pushing agents" lists of .claude/docs/subagents.md; change them together.
COMMITTING="pr-creator debugger detekt-rule-author linter-rollout ansible-ops paper-plugin-config"
PUSHING="pr-creator linter-rollout"

INPUT=$(cat)
field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null; }

EVENT=$(field .hook_event_name)
[ -n "$EVENT" ] && [ "$EVENT" != PreToolUse ] && exit 0
TOOL=$(field .tool_name)
[ -n "$TOOL" ] && [ "$TOOL" != Bash ] && exit 0
case "$(field .tool_input.command)" in
    *git*) ;;
    *) exit 0 ;;
esac
CWD=$(field .cwd)
[ -d "$CWD" ] || CWD=.
git -C "$CWD" rev-parse --git-dir >/dev/null 2>&1 || exit 0
SESSION=$(field .session_id)
[ -n "$SESSION" ] && SESSION=$(printf '%s' "$SESSION" | tr -c 'A-Za-z0-9._-' '_')
SCRATCH=$(bash "$(dirname "$0")/scratch.sh" "$CWD") || SCRATCH=

IFS= read -r -d '' PROGRAM <<'PYTHON'
import json
import os
import re
import shlex
import subprocess
import sys
import time

COMMITTING = os.environ["COMMITTING"].split()
PUSHING = os.environ["PUSHING"].split()
WINDOW_SECONDS = 2 * 60 * 60
SHELLS = {"bash", "sh", "zsh", "dash"}
WRAPPERS = {"env", "command", "exec", "nohup", "time", "sudo", "!", "{", "}", "if", "then", "else", "elif",
            "do", "while", "until"}
GIT_VALUE_OPTIONS = {"-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix", "--config-env"}
COMMIT_VALUE_OPTIONS = {"-m", "-F", "-C", "-c", "-t", "--message", "--file", "--reuse-message",
                        "--reedit-message", "--template", "--date", "--cleanup", "--fixup", "--squash",
                        "--trailer", "--pathspec-from-file"}
PUSH_VALUE_OPTIONS = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
HEREDOC = re.compile(r"<<(?P<dash>-?)[ \t]*(?P<quote>['\"]?)\\?(?P<word>[A-Za-z0-9_.-]+)(?P=quote)")


class Lexer:
    """Cuts a shell text into simple commands, the way the shell would run them."""

    def __init__(self, text):
        self.text = text
        self.pieces = []

    def scan(self, i, nested):
        text, n = self.text, len(self.text)
        current, heredocs, quote, depth = [], [], None, 0

        def flush():
            piece = "".join(current).strip()
            if piece:
                self.pieces.append(piece)
            current.clear()

        while i < n:
            char = text[i]
            if quote != "'" and text.startswith("$(", i) and not text.startswith("$((", i):
                i = self.scan(i + 2, True)
                current.append("$(...)")
                continue
            if quote == "'":
                current.append(char)
                quote = None if char == "'" else quote
                i += 1
                continue
            if quote == '"':
                if char == "\\" and i + 1 < n:
                    current.append(text[i:i + 2])
                    i += 2
                    continue
                current.append(char)
                quote = None if char == '"' else quote
                i += 1
                continue
            if char == "\\" and i + 1 < n:
                if text[i + 1] != "\n":
                    current.append(text[i:i + 2])
                i += 2
                continue
            if char in "'\"":
                quote = char
                current.append(char)
                i += 1
                continue
            if char == "#" and (i == 0 or text[i - 1] in " \t\n;&|()"):
                end = text.find("\n", i)
                i = n if end == -1 else end
                continue
            if text.startswith("<<", i) and not text.startswith("<<<", i):
                match = HEREDOC.match(text, i)
                if match:
                    heredocs.append((match.group("word"), match.group("dash") == "-"))
                    current.append(match.group(0))
                    i = match.end()
                    continue
            if char == "\n":
                flush()
                i = self.skip_bodies(i + 1, heredocs)
                heredocs = []
                continue
            if char == ")":
                flush()
                if depth == 0 and nested:
                    return i + 1
                depth = max(depth - 1, 0)
                i += 1
                continue
            if char == "(":
                flush()
                depth += 1
                i += 1
                continue
            if char in ";&|":
                flush()
                i += 1
                continue
            current.append(char)
            i += 1
        flush()
        return n

    def skip_bodies(self, i, heredocs):
        text = self.text
        for word, strip_tabs in heredocs:
            while i < len(text):
                end = text.find("\n", i)
                line = text[i:] if end == -1 else text[i:end]
                i = len(text) if end == -1 else end + 1
                if (line.lstrip("\t") if strip_tabs else line) == word:
                    break
        return i


def deny(piece, reason):
    shown = " ".join(piece.split())
    if len(shown) > 200:
        shown = shown[:200] + "..."
    print(f"BLOCKED by git-guard: '{shown}': {reason}", file=sys.stderr)
    sys.exit(2)


def words_of(piece):
    try:
        words = shlex.split(piece)
    except ValueError:
        words = piece.split()
    while words and (words[0] in WRAPPERS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0])):
        words.pop(0)
    return words


def shell_script(words):
    for index, word in enumerate(words[1:], start=1):
        if re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", word):
            return words[index + 1] if index + 1 < len(words) else None
    return None


def open_windows():
    scratch, session = os.environ.get("SCRATCH"), os.environ.get("SESSION")
    if not scratch or not session:
        return []
    now, names = time.time(), []
    for name in dict.fromkeys(COMMITTING + PUSHING):
        try:
            if now - os.path.getmtime(os.path.join(scratch, f"window-{name}-{session}")) < WINDOW_SECONDS:
                names.append(name)
        except OSError:
            pass
    return names


def caller(payload):
    agent = payload.get("agent_type")
    if isinstance(agent, str) and agent:
        return agent in COMMITTING, agent in PUSHING, f"agent '{agent}'"
    windows = open_windows()
    if windows:
        return (any(name in COMMITTING for name in windows), any(name in PUSHING for name in windows),
                f"a session with an open {', '.join(windows)} window")
    return False, False, "the main thread (in Codex, or an agent while no committing agent runs)"


def is_pushed(repo):
    result = subprocess.run(["git", "-C", repo, "branch", "-r", "--contains", "HEAD"],
                            capture_output=True, text=True)
    return result.returncode == 0 and result.stdout.strip() != ""


def check_add(piece, args):
    for arg in args:
        if arg in ("-A", "--all", ".", "./") or re.fullmatch(r"-[A-Za-z]*A[A-Za-z]*", arg):
            deny(piece, "stage explicit paths with git add <paths>; never git add -A, --all or . (git-commits.md).")


def check_commit(piece, args, repo, raw, role):
    amend, skip = False, False
    for arg in args:
        if skip:
            skip = False
            continue
        if arg == "--":
            break
        if arg in ("-a", "--all"):
            deny(piece, "never git commit -a or --all; stage explicit paths first (git-commits.md).")
        if arg == "--author" or arg.startswith("--author="):
            deny(piece, "no --author: the author is whoever git config resolves to (git-commits.md).")
        if arg == "--amend":
            amend = True
        elif arg in COMMIT_VALUE_OPTIONS:
            skip = True
        elif re.fullmatch(r"-[A-Za-z]+", arg):
            for position, letter in enumerate(arg[1:]):
                if letter == "a":
                    deny(piece, "never git commit -a or --all; stage explicit paths first (git-commits.md).")
                if letter in "mFCct":
                    skip = position == len(arg) - 2
                    break
    if re.search(r"co-authored-by", raw, re.IGNORECASE):
        deny(piece, "no Co-authored-by trailer (git-commits.md).")
    if amend and is_pushed(repo):
        deny(piece, "HEAD is already on a remote branch; amending it rewrites pushed history (git-commits.md).")
    commits, _, who = role
    if not commits:
        deny(piece, f"git commit runs only in a committing agent ({', '.join(COMMITTING)}); everyone else "
                    f"leaves the commit to pr-creator (git-commits.md, subagents.md). This call came from {who}.")


def check_push(piece, args, role):
    skip = False
    for arg in args:
        if skip:
            skip = False
            continue
        if arg in ("--force", "-f") or arg.startswith("--force-with-lease") or arg.startswith("+"):
            deny(piece, "no forced push; the user runs it (git-commits.md, pull-request skill).")
        if arg in PUSH_VALUE_OPTIONS:
            skip = True
        elif re.fullmatch(r"-[A-Za-z]+", arg):
            for position, letter in enumerate(arg[1:]):
                if letter == "f":
                    deny(piece, "no forced push; the user runs it (git-commits.md, pull-request skill).")
                if letter == "o":
                    skip = position == len(arg) - 2
                    break
    _, pushes, who = role
    if not pushes:
        deny(piece, f"git push runs only in a pushing agent ({', '.join(PUSHING)}); otherwise the user pushes "
                    f"(git-commits.md). This call came from {who}.")


def check_git(piece, words, cwd, raw, role):
    repo, k = cwd, 1
    while k < len(words) and words[k].startswith("-"):
        if words[k] == "-C" and k + 1 < len(words):
            repo = os.path.join(repo, os.path.expanduser(words[k + 1]))
            k += 2
        elif words[k] in GIT_VALUE_OPTIONS:
            k += 2
        else:
            k += 1
    if k >= len(words):
        return
    subcommand, args = words[k], words[k + 1:]
    if subcommand == "add":
        check_add(piece, args)
    elif subcommand == "commit":
        check_commit(piece, args, repo, raw, role)
    elif subcommand == "push":
        check_push(piece, args, role)


def check(text, cwd, raw, role, level=0):
    lexer = Lexer(text)
    lexer.scan(0, False)
    for piece in lexer.pieces:
        words = words_of(piece)
        if not words:
            continue
        name = os.path.basename(words[0])
        if name == "cd":
            cwd = os.path.join(cwd, os.path.expanduser(words[1] if len(words) > 1 else "~"))
        elif name in SHELLS and level < 3:
            script = shell_script(words)
            if script is not None:
                check(script, cwd, raw, role, level + 1)
        elif name == "git":
            check_git(piece, words, cwd, raw, role)


try:
    payload = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
if not isinstance(payload, dict):
    sys.exit(0)
tool_input = payload.get("tool_input")
command = tool_input.get("command") if isinstance(tool_input, dict) else None
if isinstance(command, list):
    command = " ".join(shlex.quote(str(part)) for part in command)
if not isinstance(command, str):
    sys.exit(0)
cwd = payload.get("cwd") if isinstance(payload.get("cwd"), str) else os.getcwd()
check(command, cwd, command, caller(payload))
PYTHON

printf '%s' "$INPUT" | COMMITTING="$COMMITTING" PUSHING="$PUSHING" SCRATCH="$SCRATCH" SESSION="$SESSION" \
    python3 -I -c "$PROGRAM"
