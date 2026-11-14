#!/bin/bash
# PreToolUse on Bash (Claude Code and Codex): enforces git-commits.md on git and gh commands.
# Denied for everyone: git add -A, --all or .; git commit -a or --all; --author or a Co-authored-by
# trailer on a commit; commit --amend when HEAD is already on a remote branch; a git alias defined with
# -c or --config-env; git send-pack and git http-push; gh pr merge, gh repo sync, gh alias set or import,
# a gh api write to a ref, a merge or a file's contents, and a gh api graphql merge or ref mutation or a
# query it cannot read. A git push passes only as the whole Bash call, a plain git [-C <dir>] push with a
# literal remote and refspec: nothing before or after it, no wrapper, variable, substitution, brace or
# wildcard, no -c, --config-env, --git-dir, --work-tree, GIT_CONFIG_*, --receive-pack or --exec; a redirection
# such as 2>&1 is allowed. Then it is denied when it forces (--force, -f,
# --force-with-lease and their abbreviations, a +refspec, a + in remote.<name>.push, remote.<name>.mirror),
# touches every branch (--all, --branches, --mirror, --prune, a : refspec), or updates main, master or the
# remote's default branch (refs/remotes/<remote>/HEAD), with HEAD, remote.<name>.push and an upstream under
# push.default=upstream resolved the way git resolves them. Git and gh aliases are expanded and checked as
# the command they stand for. git commit runs only in a committing agent, git push only in a pushing agent.
# The agent is agent_type in Claude Code. Codex gives PreToolUse no agent field, so there a
# window-<agent>-<session_id> file younger than 2 hours, written by pr-creator-window.sh, stands for it.
# Without either the caller is the main thread, which neither commits nor pushes.
# The command is split on ; & | ( ) and newlines outside quotes; comments are skipped, and a $(...), a
# backtick substitution, a bash/sh -c string, an eval string and a heredoc fed to a shell are checked as
# commands of their own, as are the commands of git rebase -x, git submodule foreach and git bisect run and
# the substitutions in an unquoted heredoc; a git or gh behind another command (timeout, xargs) is checked
# too. A shell reading a pipe, and a command, git subcommand or gh command built at run time ($VAR, env -S),
# are denied when the command mentions push or merge. git -C <dir>
# and the other global options are stripped. Exit 2 blocks with the reason on stderr, and so does an
# exception in the Python check.
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
    *git*|*gh*) ;;
    *) exit 0 ;;
esac
CWD=$(field .cwd)
[ -d "$CWD" ] || CWD=.
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
PUSH_VALUE_OPTIONS = {"-o", "--push-option", "--repo", "--receive-pack", "--exec", "--recurse-submodules"}
PUSH_EVERY_BRANCH_OPTIONS = {"--all", "--branches", "--mirror", "--prune"}
PUSH_LONG_OPTIONS = {"--all", "--branches", "--mirror", "--prune", "--force", "--force-with-lease", "--force-if-includes",
                     "--delete", "--tags", "--follow-tags", "--dry-run", "--porcelain", "--set-upstream", "--thin",
                     "--progress", "--quiet", "--verbose", "--verify", "--atomic", "--signed", "--ipv4", "--ipv6",
                     "--push-option", "--repo", "--receive-pack", "--exec", "--recurse-submodules", "--no-verify",
                     "--no-thin", "--no-atomic", "--no-signed", "--no-force-with-lease", "--no-follow-tags",
                     "--no-recurse-submodules", "--no-force-if-includes"}
GH_COMMANDS = {"agent-task", "alias", "api", "attestation", "auth", "browse", "cache", "codespace", "completion",
               "config", "copilot", "extension", "gist", "gpg-key", "help", "issue", "label", "org", "pr", "preview",
               "project", "release", "repo", "ruleset", "run", "search", "secret", "ssh-key", "status", "variable",
               "workflow"}
PROTECTED_BRANCHES = {"main", "master"}
GH_API_VALUE_OPTIONS = {"-X", "--method", "-f", "--raw-field", "-F", "--field", "-H", "--header", "--input", "-q",
                        "--jq", "-t", "--template", "--hostname", "--cache", "-p", "--preview"}
GH_API_FIELD_OPTIONS = {"-f", "--raw-field", "-F", "--field", "--input"}
GH_API_WRITE_PATH = re.compile(r"(^|/)git/refs(/|$)|/merges/?$|/merge-upstream/?$|/contents(/|$)|/pulls/[^/]+/merge/?$",
                               re.IGNORECASE)
GH_GRAPHQL_WRITE = re.compile(r"mergePullRequest|mergeBranch|updateRefs?\b|createCommitOnBranch|createRef|deleteRef|"
                              r"enablePullRequestAutoMerge|enqueuePullRequest")
FORCED_PUSH = "no forced push; the user runs it (git-commits.md, pull-request skill)."
REDIRECTION = re.compile(r"^\d*(>>?|<|&>>?|>&|<&|>\|)(.*)$")
PUSH_OR_MERGE = re.compile(r"\b(push|merge|send-pack|http-push)\b")
DYNAMIC = re.compile(r"[$`{}*?\[\]~^]")
GH_API_SHORT_VALUES = "XHfFqtp"
GH_ALIASES = {}
HEREDOC = re.compile(r"<<(?P<dash>-?)[ \t]*(?P<quote>['\"]?)\\?(?P<word>[A-Za-z0-9_.-]+)(?P=quote)")


class Lexer:
    """Cuts a shell text into simple commands, the way the shell would run them."""

    def __init__(self, text):
        self.text = text
        self.pieces = []
        self.bodies = []

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
            if quote != "'" and char == "`":
                end = text.find("`", i + 1)
                end = n if end == -1 else end
                inner = Lexer(text[i + 1:end])
                inner.scan(0, False)
                self.pieces.extend(inner.pieces)
                self.bodies.extend(inner.bodies)
                current.append("`...`")
                i = end + 1
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
                    heredocs.append((match.group("word"), match.group("dash") == "-",
                                     bool(match.group("quote")) or "\\" in match.group(0)))
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
            if (char == "&" and ((i > 0 and text[i - 1] in "<>") or text.startswith("&>", i))) or \
                    (char == "|" and i > 0 and text[i - 1] == ">"):
                current.append(char)
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
        for word, strip_tabs, quoted in heredocs:
            body = []
            while i < len(text):
                end = text.find("\n", i)
                line = text[i:] if end == -1 else text[i:end]
                i = len(text) if end == -1 else end + 1
                if (line.lstrip("\t") if strip_tabs else line) == word:
                    break
                body.append(line)
            self.bodies.append(("\n".join(body), quoted))
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
    words = kept
    assigned, wrapped = [], False
    while words and (words[0] in WRAPPERS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0])):
        if "=" in words[0]:
            assigned.append(words[0].split("=", 1)[0])
        else:
            wrapped = True
        words.pop(0)
    return words, assigned, wrapped, herestrings


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


def git_output(repo, *args):
    result = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, errors="replace")
    return result.stdout.strip() if result.returncode == 0 else ""


def is_pushed(repo):
    result = subprocess.run(["git", "-C", repo, "branch", "-r", "--contains", "HEAD"],
                            capture_output=True, text=True, errors="replace")
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


def branch_of(ref):
    for prefix in ("refs/heads/", "heads/"):
        if ref.startswith(prefix):
            return ref[len(prefix):]
    return None if ref.startswith("refs/") else ref


def protected_branches(repo, remote):
    names = set(PROTECTED_BRANCHES)
    for name in dict.fromkeys((remote, "origin")):
        prefix = f"refs/remotes/{name}/"
        head = git_output(repo, "symbolic-ref", "--quiet", f"{prefix}HEAD")
        if head.startswith(prefix):
            names.add(head[len(prefix):])
    return names


def long_option(arg, options):
    """The long option git's parse-options reads arg as: the exact name, else the one option it abbreviates."""
    name = arg.partition("=")[0]
    if name in options:
        return name
    matches = [option for option in options if option.startswith(name)]
    return matches[0] if len(matches) == 1 else name


def mapped_destinations(source, source_ref, configured):
    """Every destination remote.<name>.push could map a local ref to; a superset of the one git picks."""
    found = []
    for spec in configured:
        pattern, _, target = spec.lstrip("+").partition(":")
        if not target:
            continue
        if "*" in pattern:
            head, _, tail = pattern.partition("*")
            if source_ref.startswith(head) and source_ref.endswith(tail) and len(source_ref) >= len(head) + len(tail):
                found.append(target.replace("*", source_ref[len(head):len(source_ref) - len(tail)], 1))
        elif pattern in (source, source_ref) or f"refs/heads/{pattern}" == source_ref:
            found.append(target)
    return found


def push_destinations(piece, repo, remote, refspecs):
    """The remote refs these refspecs update, resolved the way git resolves them from the current config."""
    configured = git_output(repo, "config", "--get-all", f"remote.{remote}.push").split()
    if any(spec.startswith("+") for spec in configured):
        deny(piece, f"remote.{remote}.push forces the push; " + FORCED_PUSH)
    if any(spec.lstrip("+").startswith(":") for spec in configured):
        deny(piece, f"remote.{remote}.push holds a matching refspec, which pushes every branch the remote has "
                    f"(git-commits.md).")
    if git_output(repo, "config", "--bool", "--get", f"remote.{remote}.mirror") == "true":
        deny(piece, f"remote.{remote}.mirror makes every push a forced mirror (git-commits.md).")
    upstream_mode = git_output(repo, "config", "--get", "push.default") in ("upstream", "tracking")
    destinations = []
    for spec in refspecs:
        source, colon, target = spec.partition(":")
        if colon:
            destinations.append(target)
            continue
        if source in ("HEAD", "@"):
            source = git_output(repo, "symbolic-ref", "--quiet", "HEAD") or source
        source_ref = git_output(repo, "rev-parse", "--symbolic-full-name", source) or source
        destinations += mapped_destinations(source, source_ref, configured)
        if upstream_mode and source_ref.startswith("refs/heads/"):
            destinations.append(git_output(repo, "for-each-ref", "--format=%(upstream:remoteref)", source_ref))
        destinations.append(source_ref)
    return [destination for destination in destinations if destination]


def check_push(piece, args, repo, role, alone):
    if not alone:
        deny(piece, "git push runs as a Bash call of its own, a plain git push with nothing before or after it "
                    "and no wrapper, alias script, variable or substitution: git push -u origin <branch> "
                    "(git-commits.md).")
    if not os.path.isdir(repo):
        deny(piece, "git push from a directory that does not exist when the command is checked; push from the "
                    "repository itself (git-commits.md).")
    for arg in args:
        if re.search(r"[$`{}]", arg):
            deny(piece, "the arguments of git push are written out literally: no variable, substitution or brace "
                        "(git-commits.md).")
    positional, pending, options_done = [], None, False
    for arg in args:
        if pending:
            pending = None
            continue
        if options_done or not arg.startswith("-") or arg == "-":
            positional.append(arg)
            continue
        if arg == "--":
            options_done = True
            continue
        if arg.startswith("--"):
            option = long_option(arg, PUSH_LONG_OPTIONS)
            if option in ("--force", "--force-with-lease"):
                deny(piece, FORCED_PUSH)
            if option in ("--receive-pack", "--exec"):
                deny(piece, f"no git push {option}: it runs a command of its own on the remote side (git-commits.md).")
            if option in PUSH_EVERY_BRANCH_OPTIONS:
                deny(piece, f"no git push {option}: it can update or delete main, master or the default branch; "
                            f"push one named feature branch (git-commits.md).")
            if option in PUSH_VALUE_OPTIONS and "=" not in arg:
                pending = option
            continue
        for position, letter in enumerate(arg[1:]):
            if letter == "f":
                deny(piece, FORCED_PUSH)
            if letter == "o":
                pending = "-o" if position == len(arg) - 2 else None
                break
    if len(positional) < 2:
        deny(piece, "name the remote and the branch: git push -u origin <branch> (git-commits.md).")
    remote, refspecs = positional[0], positional[1:]
    for spec in positional:
        if re.search(r"[$`{}*?\[\]~^]", spec):
            deny(piece, "the remote and the refspec of git push are written out literally: no variable, "
                        "substitution, brace, wildcard or revision expression (git-commits.md).")
    for spec in refspecs:
        if spec.startswith("+"):
            deny(piece, FORCED_PUSH)
        if spec == ":":
            deny(piece, "a : refspec pushes every matching branch; name the branch (git-commits.md).")
    protected = protected_branches(repo, remote)
    for destination in push_destinations(piece, repo, remote, refspecs):
        name = branch_of(destination)
        if name in protected:
            deny(piece, f"no push to {name}: main, master and the remote's default branch change only through a "
                        f"pull request the user merges; push a feature branch (git-commits.md).")
    _, pushes, who = role
    if not pushes:
        deny(piece, f"git push runs only in a pushing agent ({', '.join(PUSHING)}); otherwise the user pushes "
                    f"(git-commits.md). This call came from {who}.")


def check_gh_api(piece, args):
    method, path, fields, has_input, pending = None, None, [], False, None
    for arg in args:
        if pending:
            if pending in ("-X", "--method"):
                method = arg.upper()
            elif pending in ("-f", "-F"):
                fields.append(arg)
            elif pending == "--input":
                has_input = True
            elif pending in GH_API_FIELD_OPTIONS:
                fields.append(arg)
            pending = None
            continue
        option, equals, value = arg.partition("=")
        if arg.startswith("--"):
            if option == "--input":
                has_input = True
            if not equals:
                pending = arg if arg in GH_API_VALUE_OPTIONS else None
            elif option == "--method":
                method = value.upper()
            elif option in GH_API_FIELD_OPTIONS:
                fields.append(value)
        elif re.fullmatch(r"-[A-Za-z].*", arg):
            for position, letter in enumerate(arg[1:], start=1):
                if letter not in GH_API_SHORT_VALUES:
                    continue
                value = arg[position + 1:].lstrip("=")
                if not value:
                    pending = "-" + letter
                elif letter == "X":
                    method = value.upper()
                elif letter in "fF":
                    fields.append(value)
                break
        elif not arg.startswith("-") and path is None:
            path = arg
    if path is None:
        return
    route = path.split("?")[0]
    if re.search(r"(^|/)graphql/?$", route, re.IGNORECASE):
        queries = [field.partition("=")[2] for field in fields if field.partition("=")[0] == "query"]
        hidden = has_input or any(query.startswith("@") or "{" not in query for query in queries)
        if hidden or GH_GRAPHQL_WRITE.search(" ".join(fields)):
            deny(piece, "no gh api graphql call that merges or moves a ref, or whose query comes from a file or "
                        "a variable (git-commits.md).")
        return
    writes = (method or ("POST" if fields or has_input else "GET")) != "GET"
    if writes and GH_API_WRITE_PATH.search(route):
        deny(piece, "no gh api call that moves a branch, merges or commits a file: a branch changes only by a "
                    "push of a feature branch, and the user merges (git-commits.md).")


def gh_command(args):
    """The command path gh resolves: the first two words that are neither flags nor the value of -R/--repo."""
    path, skip = [], False
    for index, arg in enumerate(args):
        if skip:
            skip = False
            continue
        if arg in ("-R", "--repo"):
            skip = True
            continue
        if arg.startswith("-"):
            continue
        path.append((index, arg))
        if len(path) == 2:
            break
    return path


def gh_alias(name):
    if "list" not in GH_ALIASES:
        try:
            result = subprocess.run(["gh", "alias", "list"], capture_output=True, text=True, errors="replace",
                                    timeout=3)
            GH_ALIASES["list"] = result.stdout.splitlines()
        except (OSError, subprocess.SubprocessError):
            GH_ALIASES["list"] = []
    for line in GH_ALIASES["list"]:
        alias, _, expansion = line.partition("\t") if "\t" in line else line.partition(":")
        if alias.strip() == name:
            return expansion.strip().strip("'\"")
    return ""


def check_gh(piece, words, cwd, raw, role, level):
    args = words[1:]
    path = gh_command(args)
    names = [name for _, name in path]
    if any(name.startswith(("$", "`")) for name in names):
        deny(piece, "a gh command built at run time cannot be checked (git-commits.md).")
    if names == ["pr", "merge"]:
        deny(piece, "no gh pr merge: merging updates the base branch; the user merges (git-commits.md).")
    if names == ["repo", "sync"]:
        deny(piece, "no gh repo sync: it moves a branch, the default one unless --branch names another; the user "
                    "runs it (git-commits.md).")
    if names[:2] in (["alias", "set"], ["alias", "import"]):
        deny(piece, "no new gh alias: an alias can hide gh pr merge from this check; the user defines aliases "
                    "(git-commits.md).")
    if names[:1] == ["api"]:
        check_gh_api(piece, args[path[0][0] + 1:])
    elif names and names[0] not in GH_COMMANDS and level < 3:
        expansion = gh_alias(names[0])
        rest = args[path[0][0] + 1:]
        if expansion.startswith("!"):
            check(" ".join([expansion[1:], *(shlex.quote(arg) for arg in rest)]), cwd, raw, role, level + 1)
        elif expansion:
            check_gh(piece, ["gh", *shlex.split(expansion), *rest], cwd, raw, role, level + 1)


def check_git(piece, words, cwd, raw, role, alone, level=0, inherited=(), assigned=()):
    if any(name.startswith("GIT_CONFIG") for name in assigned):
        deny(piece, "no git config through the environment (GIT_CONFIG_*): it can define an alias or redirect a "
                    "push past this check (git-commits.md).")
    repo, k, overrides = cwd, 1, list(inherited)
    while k < len(words) and words[k].startswith("-"):
        option = words[k]
        if option == "-C" and k + 1 < len(words):
            if DYNAMIC.search(words[k + 1]):
                overrides.append(("-C", words[k + 1]))
            repo = os.path.join(repo, os.path.expanduser(words[k + 1]))
            k += 2
            continue
        if option in GIT_VALUE_OPTIONS or option.startswith(("--git-dir=", "--work-tree=", "--namespace=",
                                                             "--config-env=")):
            setting = option.partition("=")[2] if "=" in option else (words[k + 1] if k + 1 < len(words) else "")
            overrides.append((option.partition("=")[0], setting))
            k += 1 if "=" in option else 2
            continue
        k += 1
    if k >= len(words):
        if not alone and PUSH_OR_MERGE.search(raw):
            deny(piece, "git whose subcommand comes from its input (xargs) cannot be checked next to a push; run "
                        "git push as a plain command (git-commits.md).")
        return
    subcommand, args = words[k], words[k + 1:]
    if subcommand.startswith(("$", "`")):
        if PUSH_OR_MERGE.search(raw):
            deny(piece, "a git subcommand built at run time cannot be checked next to a push (git-commits.md).")
        return
    keys = [setting.partition("=")[0].lower() for name, setting in overrides if name in ("-c", "--config-env")]
    if any(key.startswith(("alias.", "include.", "includeif.")) for key in keys):
        deny(piece, "no git alias or include defined on the command line (-c, --config-env): it hides the command "
                    "from this check (git-commits.md).")
    if subcommand == "add":
        check_add(piece, args)
    elif subcommand == "commit":
        check_commit(piece, args, repo, raw, role)
    elif subcommand == "push":
        if overrides:
            deny(piece, "no global option on git push other than -C (-c, --config-env, --git-dir, --work-tree, "
                        "--namespace): it can force the push or change where it goes (git-commits.md).")
        check_push(piece, args, repo, role, alone)
    elif subcommand == "rebase" and level < 3:
        for index, arg in enumerate(args):
            if arg in ("-x", "--exec") and index + 1 < len(args):
                check(args[index + 1], repo, raw, role, level + 1)
            elif arg.startswith(("--exec=", "-x")) and len(arg) > 2:
                check(arg.partition("=")[2] if arg.startswith("--exec=") else arg[2:], repo, raw, role, level + 1)
    elif subcommand in ("submodule", "bisect") and level < 3:
        trigger = "foreach" if subcommand == "submodule" else "run"
        if trigger in args:
            rest = [arg for arg in args[args.index(trigger) + 1:] if not arg.startswith("-")]
            check(" ".join(rest) if subcommand == "submodule" else " ".join(shlex.quote(arg) for arg in rest),
                  repo, raw, role, level + 1)
    elif subcommand in ("send-pack", "http-push"):
        deny(piece, f"no git {subcommand}: it is push plumbing; a pushing agent pushes with git push (git-commits.md).")
    else:
        alias = git_output(repo, "config", "--get", f"alias.{subcommand}")
        if alias and level >= 3:
            deny(piece, "git alias chain too deep to check; run the git command it stands for (git-commits.md).")
        if alias.startswith("!"):
            check(" ".join([alias[1:], *(shlex.quote(arg) for arg in args)]), repo, raw, role, level + 1)
        elif alias:
            try:
                expanded = shlex.split(alias)
            except ValueError:
                expanded = alias.split()
            check_git(piece, ["git", *expanded, *args], repo, raw, role, alone, level + 1, overrides)


def substitutions(text):
    """The texts of the $(...) and backtick substitutions in text, which the shell runs while it expands it."""
    found, i = [], 0
    while i < len(text):
        if text.startswith("$(", i):
            depth, j = 1, i + 2
            while j < len(text) and depth:
                depth += {"(": 1, ")": -1}.get(text[j], 0)
                j += 1
            found.append(text[i + 2:j - 1])
            i = j
        elif text[i] == "`":
            end = text.find("`", i + 1)
            end = len(text) if end == -1 else end
            found.append(text[i + 1:end])
            i = end + 1
        else:
            i += 1
    return found


def check_command(piece, words, cwd, raw, role, level, alone, assigned, inputs, scan=True):
    name = os.path.basename(words[0])
    if words[0].startswith(("$", "`", "-")):
        if PUSH_OR_MERGE.search(raw):
            deny(piece, "a command whose name is built at run time, or that a wrapper option hides (env -S), cannot be "
                        "checked next to a push or a merge; run git push as a plain command (git-commits.md).")
        return
    if name in SHELLS or name in ("eval", "trap"):
        if level >= 3:
            if PUSH_OR_MERGE.search(raw):
                deny(piece, "shells nested too deep to check next to a push or a merge (git-commits.md).")
            return
        if name == "eval":
            scripts = [" ".join(words[1:])]
        elif name == "trap":
            scripts = words[1:2]
        else:
            script = shell_script(words)
            reads_stdin = script is None and all(word.startswith("-") for word in words[1:])
            scripts = [script] if script is not None else (inputs if reads_stdin else [])
            if reads_stdin and not inputs and PUSH_OR_MERGE.search(raw):
                deny(piece, "a shell that reads its script from a pipe cannot be checked next to a push or a merge; "
                            "run git push as a plain command (git-commits.md).")
        for script in scripts:
            check(script, cwd, raw, role, level + 1)
        return
    if name == "git":
        check_git(piece, words, cwd, raw, role, alone, level, assigned=assigned)
        return
    if name == "gh":
        check_gh(piece, words, cwd, raw, role, level)
        return
    if scan:
        for index, word in enumerate(words[1:], start=1):
            tool = os.path.basename(word)
            if tool in ("git", "gh", "eval") or tool in SHELLS:
                check_command(piece, words[index:], cwd, raw, role, level, False, assigned, inputs, scan=False)


def check(text, cwd, raw, role, level=0):
    lexer = Lexer(text)
    lexer.scan(0, False)
    single = level == 0 and len(lexer.pieces) == 1 and not lexer.bodies
    for body, quoted in lexer.bodies:
        for inner in [] if quoted else substitutions(body):
            check(inner, cwd, raw, role, level + 1)
    for piece in lexer.pieces:
        words, assigned, wrapped, herestrings = words_of(piece)
        if not words:
            continue
        if os.path.basename(words[0]) == "cd":
            cwd = os.path.join(cwd, os.path.expanduser(words[1] if len(words) > 1 else "~"))
            continue
        inputs = [body for body, _ in lexer.bodies] + herestrings
        check_command(piece, words, cwd, raw, role, level, single and not assigned and not wrapped, assigned, inputs)


try:
    payload = json.load(sys.stdin)
except ValueError:
    sys.exit(0)
if not isinstance(payload, dict):
    sys.exit(0)
tool_input = payload.get("tool_input")
command = tool_input.get("command") if isinstance(tool_input, dict) else None
if isinstance(command, list):
    parts = [str(part) for part in command]
    if len(parts) == 3 and os.path.basename(parts[0]) in SHELLS and re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", parts[1]):
        command = parts[2]
    else:
        command = " ".join(shlex.quote(part) for part in parts)
if not isinstance(command, str):
    sys.exit(0)
cwd = payload.get("cwd") if isinstance(payload.get("cwd"), str) else os.getcwd()
try:
    check(command, cwd, command, caller(payload))
except Exception as error:
    deny(command, f"git-guard failed on this command ({type(error).__name__}: {error}); split it into plain "
                  f"commands, or report the failure to the user.")
PYTHON

printf '%s' "$INPUT" | COMMITTING="$COMMITTING" PUSHING="$PUSHING" SCRATCH="$SCRATCH" SESSION="$SESSION" \
    python3 -I -c "$PROGRAM"
