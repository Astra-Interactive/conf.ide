# File edits

A targeted change to a file in a repository goes through the harness's own edit tool, so the change is
visible, reviewable and checked against the file's current text. Appending an entry to a log and writing a
marker file outside the repository are not edits.

- Claude Code and Kimi: `Edit` for a change inside a file, `Write` for a new file or a full rewrite. `Edit`
  needs the file read first in the same session.
- Codex: `apply_patch`.

A one-off Python or shell script that reads a file and replaces text in it (`read_text().replace(...)`,
`sed -i`, a heredoc that rewrites the file) is the pattern this replaces. XML is read and changed with
`xmlstarlet` (xmlstarlet.md).
