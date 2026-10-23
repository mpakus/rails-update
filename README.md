# Rails update

[rails-update](SKILL.md) is a reusable Ruby/Rails upgrade skill for
Cursor, Claude Code and Codex. It includes conditional compatibility repairs,
source-search recipes, behavioral verification and data/release safeguards.

Source: [mpakus/rails-update](https://github.com/mpakus/rails-update).
Working version: **1.1.0** (not yet published) — see the [changelog](CHANGELOG.md).
The latest published [versioned release is 1.0.0](https://github.com/mpakus/rails-update/releases/tag/v1.0.0).
`SKILL.md`, `references/` and `scripts/` live at the repository root and form a
self-contained skill, independent of any particular application.

After installing, see [How to use](#how-to-use) for chat commands and copyable
upgrade, audit and verification prompts.

## Layout

```text
rails-update/
├── .github/workflows/ci.yml     # Linux/macOS helper and package checks
├── README.md                    # Installation and usage
├── CHANGELOG.md                  # Release changes
├── RELEASING.md                  # Maintainer release steps
├── LICENSE                       # MIT license
├── SKILL.md                     # Agent instructions and reference links
├── references/
│   ├── compatibility.md         # Conditional compatibility patterns
│   ├── multi-major.md           # Rails 5 to 8 transition and deployment checks
│   ├── upgrade-record.md        # Checkpoint, dependency and evidence template
│   ├── verification.md          # Test, data preservation and release gates
│   ├── queued-jobs.md           # Old payloads, mail readers and queue cutover
│   ├── ruby-4.md                # Ruby 4 checks and regression spec recipes
│   └── forms.md                 # Form payload and persistence regression matrix
├── scripts/
│   ├── runtime_snapshot.rb      # Read-only runtime/source evidence
│   ├── verify_upgrade.rb        # Explicitly selected post-update checks
│   ├── upgrade_report.rb        # Markdown report from saved evidence
│   └── check_ruby_requirements.rb # Candidate Ruby vs installed gem requirements
└── test/
    ├── scripts_test.rb          # Evidence helper regression checks
    ├── ruby_requirements_test.rb # Requirement checker and frozen bundle checks
    └── package_test.rb          # Entrypoint, local links and script CLI checks
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

The command above follows published `main`, not uncommitted local changes.
To install the immutable 1.0.0 release instead (1.1.0 is not published yet):

```sh
npx skills@latest add https://github.com/mpakus/rails-update/tree/v1.0.0 \
  --skill rails-update -a cursor -a claude-code -a codex
```

The installed `SKILL.md` records the package version in `metadata.version`.

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

Skills CLI 1.7.4 requires Node 22.20.0 or newer (checked 2026-10-21).
Installation/discovery checks
verify packaging; they do not establish live invocation or application correctness.

## Manual installation

Copy `SKILL.md`, `LICENSE` and the **whole `references/` and `scripts/` directories** from the
repository root into one supported location:

| Client | Project location |
| --- | --- |
| Cursor | `.cursor/skills/rails-update/` |
| Claude Code | `.claude/skills/rails-update/` |
| Codex | `.agents/skills/rails-update/` |

Each destination must contain `SKILL.md`, `LICENSE`, `references/` and `scripts/` directly;
do not add another nested `rails-update/` folder. `test/` is only needed to run the
helper regression checks.

For an installation shared by local projects, use `~/.cursor/skills/`,
`~/.claude/skills/`, or `~/.agents/skills/`, respectively, with the same folder
structure. Cursor also supports `.agents/skills/`; avoid duplicate installations
of the same skill in locations a client scans. Remote sessions need the skill in
their own workspace or supported synchronized location.

These locations follow the official [Cursor](https://cursor.com/docs/skills),
[Claude Code](https://code.claude.com/docs/en/skills), and
[Codex](https://learn.chatgpt.com/docs/build-skills) documentation checked on
2026-10-21. This package uses common `name`/`description` frontmatter and relative
references, without client-specific hooks, tools or required plugins.

Cloning this repository outside a supported skills directory does not install it.
Without installing, explicitly ask the agent to read `SKILL.md` in this checkout
and follow its linked references. From another directory, provide the absolute
path to this checkout's `SKILL.md`.

## How to use

Open the **application you want to upgrade** in your agent, install the skill
there or globally, then send a request in the agent's chat:

| Client | Chat invocation |
| --- | --- |
| Codex | Type `$rails-update` and add your request. In the CLI or IDE extension, `/skills` also opens the skill selector. |
| Claude Code | Type `/rails-update` and add your request. |
| Cursor | Type `/` in Agent chat, select `rails-update`, then add your request. |

These are skill mentions in chat, not shell commands. The existing
`name: rails-update` in [SKILL.md](SKILL.md) supplies the name; no wrapper script
or separate command installation is needed. Invocation follows the official
[Codex](https://learn.chatgpt.com/docs/build-skills#how-chatgpt-and-codex-use-skills),
[Claude Code](https://code.claude.com/docs/en/skills) and
[Cursor](https://cursor.com/docs/skills) instructions.

The examples below use Codex syntax. For Claude Code or Cursor, use
`/rails-update` instead of `$rails-update`. Replace angle-bracket placeholders
with your target versions or Git revisions. The text after the skill name is
your request, not a fixed set of subcommands.

### Plan an upgrade

```text
$rails-update Analyze this application for an upgrade to Ruby <ruby-version>
and Rails <rails-version>. Inspect the current stack, dependency constraints,
tests and deployment setup. Produce a staged plan without changing code or
resolving a new lockfile.
```

### Implement an upgrade

```text
$rails-update Upgrade this application to Ruby <ruby-version> and Rails
<rails-version>. Capture a baseline, implement the required compatibility fixes,
preserve existing framework defaults and behavior, and run the relevant checks.
Summarize changes, test results and remaining release gates.
```

### Audit an existing upgrade

```text
$rails-update Audit the upgrade between <base-sha> and <target-sha> without
switching my working checkout. Include follow-up fixes, shared callers and CI
test gates. Report regressions and missing evidence without editing code.
```

To request repairs too, add: `Fix confirmed compatibility issues and verify
the changed behavior.` For a repeated audit, supply both the original upgrade
revision and the current release revision so the agent can check later fixes.

For Rails 5 → 8 or another multi-major jump, the skill uses the
[transition guide](references/multi-major.md) and
[upgrade record template](references/upgrade-record.md). For example:

```text
$rails-update Audit this Rails 5.2 to Rails 8 upgrade. Distinguish the committed
version jump from locally tested checkpoints and deployed versions. Review every
crossed Rails 6/7/8 boundary, preserve the existing framework defaults, and record
missing evidence without downgrading my working checkout.
```

### Verify the result and write a report

```text
$rails-update Verify the current upgrade and write a Markdown report. Use the
saved pre-upgrade snapshot at <baseline-json-path> if available. Select the
applicable checks from the repository, run them in an isolated test environment,
and use verify_upgrade.rb and upgrade_report.rb to save the evidence and report.
Separate passing, failing, skipped and unverified checks; include the exact Git
revision and remaining release gates. If no baseline exists, report that gap.
```

The helpers run selected checks; the agent still needs to inspect application
behavior and choose relevant tests. See [Ruby helpers](#ruby-helpers) below.

You can also ask in plain language: `Use rails-update to plan this app's upgrade.`
If the skill is missing from the selector, check the installation location above
and confirm that it contains `SKILL.md`. In Codex, restart the client if an
installed skill has not appeared. You can also explicitly provide the path to
`SKILL.md` as described under [Manual installation](#manual-installation).

## Ruby helpers

The evidence helpers use Ruby's standard libraries and Git; no Rails gems are
needed to collect a snapshot or generate a report. Run them with plain `ruby`,
using the application's selected runtime, on macOS or Linux. The requirements
checker additionally uses the app's installed Bundler and evaluates its reviewed
Gemfile/gemspecs; run it on the current Ruby before changing the declaration.

| Script | Purpose |
| --- | --- |
| [runtime_snapshot.rb](scripts/runtime_snapshot.rb) | Record active Ruby/JIT state, locked Rails/Bundler/platforms, file hashes and Git state without evaluating the Gemfile or booting Rails |
| [verify_upgrade.rb](scripts/verify_upgrade.rb) | Check optional version targets and run only named `--check` commands, preserving failures, timeouts and source changes |
| [upgrade_report.rb](scripts/upgrade_report.rb) | Compare the baseline with verification evidence and generate a Markdown report with unverified gates |
| [check_ruby_requirements.rb](scripts/check_ruby_requirements.rb) | Check a candidate Ruby against installed bundle requirements using RubyGems version semantics, with a frozen lockfile |

See [helper usage and limitations](references/verification.md#ruby-helpers) for
the before/update/verify/report workflow, command selection and exit codes.
Every script also supports `--help`.

Run the helper regression checks from this repository's root:

```sh
ruby test/scripts_test.rb
ruby test/ruby_requirements_test.rb
ruby test/package_test.rb
```

The [CI workflow](.github/workflows/ci.yml) runs the helper and package checks
on Linux and macOS, including a legacy Ruby baseline. Supporting old Ruby for
baseline evidence collection is not a recommendation to deploy an EOL runtime.
See [release preparation](RELEASING.md) and [changes](CHANGELOG.md).

The skill works across runtime versions and application domains. It guides
investigation and repair; it cannot guarantee that all
possible defects have been discovered. Structural validation of the package does
not certify an application's upgrade or each client's live skill discovery.

## Author

[Renat "MpaK" Ibragimov](https://aomega.co)

## License

[MIT](LICENSE).
