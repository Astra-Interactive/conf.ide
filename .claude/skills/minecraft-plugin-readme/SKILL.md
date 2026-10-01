---
name: minecraft-plugin-readme
description: Generate a README.md for a Minecraft plugin (Bukkit/Spigot/Paper/Fabric/Forge). Use when asked to write, refresh, or regenerate the README for a Minecraft plugin project.
version: 1.1.0
---

# Minecraft Plugin README Generator

Generate a clear, user-facing `README.md` for a Minecraft plugin. The README describes the **plugin** — what it does, how to use it, how to configure it — not its build system or internal
architecture. The reader is a server owner deciding whether and how to use the plugin.

## Principles

- The README is about the plugin's behavior and usage, not the platform. Keep the prose
  platform-agnostic, but always state the supported loader and Minecraft version (for example,
  "Bukkit, Minecraft 1.18+").
- Output is **flexible**: include a section only when the project actually has something to put in
  it. A plugin may have no database, no permissions, or no GUI — omit those sections entirely.
  Never emit an empty or "N/A" section.
- Always **regenerate** the README from scratch from the current code. The code is the source of
  truth; do not trust an existing README.
- Write in **English**.
- Never leak build placeholders. `plugin.yml` often uses Gradle templating like `${name}`,
  `${version}`, `${description}`. Resolve these from `gradle.properties` / the build config and use
  the real values.

## Step 0 — Understand the project

Read the project structure to learn the module layout, build files, and target platform
(Bukkit/Spigot/Paper/Fabric/Forge/NeoForge). Identify the supported Minecraft version — for example
`api-version` in `plugin.yml`, or the loader/MC version in the build config.

## Step 1 — Gather facts

Collect the raw material. Prefer **code** over manifests — manifests are usually incomplete. Only
what exists matters; a missing item simply means its section is skipped in Step 2.

- **Identity**: plugin name, description, authors, website/repo, supported MC + loader version.
  Resolve any `${...}` placeholders from the build config.
- **Features**: what the plugin does for players and admins — GUIs, services, the net effect of its
  commands. Look at internal services, GUI/menu classes, listeners, and the domain logic.
- **Commands**: every command and subcommand a player or console can run, with arguments. Manifests
  (`plugin.yml`) usually list bare command names only; the real arguments and behavior live in the
  command classes (for example, Brigadier command trees or command executors).
- **Permissions**: permission nodes that gate commands or features. These often live in code (for
  example, a sealed `PluginPermission` class) rather than the manifest.
- **Configuration**: config files and the data classes that back them. Capture the real default
  config — keys, defaults, and meaning. Look for `@Serializable` config models and bundled default
  resources (for example, `config.yml`). Note any separate database/storage config.
- **External plugin dependencies**: other Minecraft plugins this one needs or can use. Found as
  `compileOnly` in Gradle and as `depend`/`softdepend` in `plugin.yml` (Bukkit). For Paper/Fabric/
  Forge the manifest differs (`paper-plugin.yml`, `fabric.mod.json`, `mods.toml`). Note whether each
  is required (hard) or optional (soft).
- **Integrations**: what those dependencies are actually used for — for example, PlaceholderAPI
  placeholders exposed, or a Vault economy used. Describe the user-visible behavior, not the API call.

## Step 2 — Compose the README

Assemble from the sections below. Include a section only when Step 1 produced content for it;
otherwise omit it. Order them roughly as listed.

- **Title & summary**: plugin name and a one-line value proposition. Add a banner or screenshot if
  one exists (look in `media/`, `assets/`, `docs/`, or `images/`).
- **Supported version**: loader + Minecraft version.
- **Features**: a checklist (`- [x] ...`) or short bullets describing what the plugin offers.
- **Commands & permissions**: a single table with `Command | Description | Permission`. Merge the
  command data with the permission nodes that gate each command.
- **Configuration**: the config explained, with a real YAML/JSON example showing keys and defaults.
  If there is a separate database/storage config, show it too.
- **Integrations**: what each external plugin integration adds (for example, the available
  placeholders).
- **Footer**: links to the author/org, related plugins, and a bStats badge if present.

## Step 3 — Verify

Before finishing, check that:

- No unresolved `${...}` placeholders remain.
- Every command in the table has its correct permission (or "—" when it has none).
- Every documented config key exists in the real config; no invented keys.
- Sections with no real content were omitted, not left empty.
- Links and image paths are valid relative to the repo.

Write the result to `README.md` at the project root.
