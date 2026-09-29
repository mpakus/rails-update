# Rails update

[rails-update](SKILL.md) is a reusable Ruby/Rails upgrade skill for
Cursor, Claude Code and Codex. It includes conditional compatibility repairs,
source-search recipes, behavioral verification and data/release safeguards.

Source: [mpakus/rails-update](https://github.com/mpakus/rails-update).
`SKILL.md` and `references/` live at the repository root and form a self-contained
skill, independent of any particular application.

## Install with the Skills CLI

Preview the skills available in the GitHub repository without installing:

```sh
npx skills@latest add mpakus/rails-update --list
```

From your application's directory, install for Cursor, Claude Code and Codex:

```sh
npx skills@latest add mpakus/rails-update --skill rails-update \
  -a cursor -a claude-code -a codex
```

Add `-g` for a user-wide installation. The CLI manages the destination directories.
The full source URL, `https://github.com/mpakus/rails-update`, also works in place
of `mpakus/rails-update`. No npm package is required. See the official
[Skills CLI documentation](https://github.com/vercel-labs/skills#readme).

### Install from a local checkout

From this repository's root, preview local discovery:

```sh
npx skills@latest add . --list
```

From your application's directory, install using the absolute path to this
checkout. Replace `/absolute/path/to/rails-update` with its actual location:

```sh
npx skills@latest add /absolute/path/to/rails-update --skill rails-update \
  -a cursor -a claude-code -a codex
```

Local discovery was verified with Skills CLI 1.7.0 and Node 24.13.0. That CLI version
requires Node 22.20.0 or newer. These checks used `--list`; no client installation
or live invocation was tested. GitHub discovery must be rechecked after publishing
`SKILL.md` and `references/` at the repository root.

## Manual installation

Copy `SKILL.md` and the **whole `references/` directory** from the repository root
into one supported location:

| Client | Project location | Invoke |
| --- | --- | --- |
| Cursor | `.cursor/skills/rails-update/` | `/rails-update` or ask to use the skill |
| Claude Code | `.claude/skills/rails-update/` | `/rails-update` |
| Codex | `.agents/skills/rails-update/` | `$rails-update` or select it from skills |

Each destination must contain `SKILL.md` and `references/` directly; do not add
another nested `rails-update/` folder.

For an installation shared by local projects, use `~/.cursor/skills/`,
`~/.claude/skills/`, or `~/.agents/skills/`, respectively, with the same folder
structure. Cursor also supports `.agents/skills/`; avoid duplicate installations
of the same skill in locations a client scans. Remote sessions need the skill in
their own workspace or supported synchronized location.

These locations follow the official [Cursor](https://cursor.com/docs/skills),
[Claude Code](https://code.claude.com/docs/en/skills), and
[Codex](https://developers.openai.com/codex/skills) documentation checked on
2026-09-28. This package uses common `name`/`description` frontmatter and relative
references, without client-specific hooks, tools or required plugins.

Cloning this repository outside a supported skills directory does not install it.
Without installing, explicitly ask the agent to read `SKILL.md` in this checkout
and follow its linked references. From another directory, provide the absolute
path to this checkout's `SKILL.md`.

## Example requests

```text
Use rails-update to analyze this app for the Ruby and Rails versions I specify.
Inspect the current stack and produce a staged plan without changing code.

Use rails-update to upgrade this application to Ruby <target> and Rails <target>.
Preserve existing framework defaults and behavior; implement compatibility fixes
and verify the real browser, API, job, report and production-image paths.

Use rails-update to audit the upgrade between <base-sha> and <target-sha>.
Find regressions and missing evidence, and fix the confirmed compatibility issues.
Keep historical results separate from checks performed on the final revision.
```

The skill works across runtime versions and application domains. It guides
investigation and repair; it cannot guarantee that all
possible defects have been discovered. Structural validation of the package does
not certify an application's upgrade or each client's live skill discovery.
