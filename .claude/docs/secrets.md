## Secrets

A password, token, API key, SSH login, RCON password, database URL with credentials, or a private
hostname is a secret. Secrets reach a tool through the environment or a secret store; they do not
travel through prompts, files, commits or reports.

### When a secret is needed

* Read it from an environment variable, a `.env` file that git ignores, `ansible-vault`, or the
  tool's own keychain (`gh auth`, `sentry-cli`, `claude mcp`). The prompt names the variable, not the
  value.
* A command that needs the value reads the variable: `-p "$RCON_PASSWORD"`, never the literal.

### When a secret appears anyway

* In a prompt: say in one line that it is a credential and that it will not be stored, then use it
  only through the environment for this task. Do not repeat it in the reply.
* In a file you read (a log, a config, a crash report): it is not copied into the report; write
  `<redacted>`.
* In a diff you are about to commit: stop, report the path and the key name, commit nothing.

### Never

* a secret in a commit, a pull request description, a handoff or retro file, a `.claude/docs` example,
  a test fixture, or a Mermaid diagram;
* a secret echoed back to the user "for confirmation";
* a credentials file created to make a tool work, outside the location the tool documents and git
  ignores.
