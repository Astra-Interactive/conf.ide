# XML: read with `xmlstarlet`, edit with the edit tool

`xmlstarlet` reads, queries and validates XML, including configs and test reports, in place of a one-off
parser. Use `xmlstarlet --help` or subcommand help when unsure. Install on macOS with
`brew install xmlstarlet`.

A targeted change to an XML file goes through the harness edit tool (`apply-patch.md`), resource files of
Android, Compose and moko (`strings.xml`, `plurals.xml`) above all: `xmlstarlet ed`, `-P` included,
re-escapes `->` to `-&gt;`, leaves a blank line where it deleted a node and rewrites the final newline, so
the diff carries changes nobody asked for. Reformatting a whole XML file is a full rewrite (`Write`).
