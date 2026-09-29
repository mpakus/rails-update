# Rails update

[rails-update](SKILL.md) is a reusable Ruby/Rails upgrade skill for
Cursor, Claude Code and Codex. It includes conditional compatibility repairs,
source-search recipes, behavioral verification and data/release safeguards.

Source: [mpakus/rails-update](https://github.com/mpakus/rails-update).
`SKILL.md`, `references/` and `scripts/` live at the repository root and form a
self-contained skill, independent of any particular application.

## Layout

```text
rails-update/
├── README.md                    # Installation and usage
├── SKILL.md                     # Agent instructions and reference links
├── references/
│   ├── compatibility.md         # Conditional compatibility patterns
│   └── verification.md          # Test, data preservation and release gates
├── scripts/
│   ├── runtime_snapshot.rb      # Read-only runtime/source evidence
│   ├── verify_upgrade.rb        # Explicitly selected post-update checks
│   └── upgrade_report.rb        # Markdown report from saved evidence
└── test/
    └── scripts_test.rb          # Helper regression checks
```

This repository contains one skill. Keep its entrypoint at the root and detailed
guidance in `references/`, where agents can read it as needed.

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

Skills CLI 1.7.0 requires Node 22.20.0 or newer. Installation/discovery checks
verify packaging; they do not establish live invocation or application correctness.

## Manual installation

Copy `SKILL.md` and the **whole `references/` and `scripts/` directories** from the
repository root into one supported location:

| Client | Project location | Invoke |
| --- | --- | --- |
| Cursor | `.cursor/skills/rails-update/` | `/rails-update` or ask to use the skill |
| Claude Code | `.claude/skills/rails-update/` | `/rails-update` |
| Codex | `.agents/skills/rails-update/` | `$rails-update` or select it from skills |

Each destination must contain `SKILL.md`, `references/` and `scripts/` directly;
do not add another nested `rails-update/` folder. `test/` is only needed to run the
helper regression checks.

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

## Ruby helpers

The optional helpers use Ruby's standard libraries and Git; no Rails gems are
needed to collect a snapshot or generate a report. Run them with plain `ruby`,
using the application's selected runtime, on macOS or Linux.

| Script | Purpose |
| --- | --- |
| [runtime_snapshot.rb](scripts/runtime_snapshot.rb) | Record active Ruby, locked Rails/Bundler/platforms, file hashes and Git state without evaluating the Gemfile or booting Rails |
| [verify_upgrade.rb](scripts/verify_upgrade.rb) | Check optional version targets and run only named `--check` commands, preserving failures, timeouts and source changes |
| [upgrade_report.rb](scripts/upgrade_report.rb) | Compare the baseline with verification evidence and generate a Markdown report with unverified gates |

See [helper usage and limitations](references/verification.md#ruby-helpers) for
the before/update/verify/report workflow, command selection and exit codes.
Every script also supports `--help`.

Run the helper regression checks from this repository's root:

```sh
ruby test/scripts_test.rb
```

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
