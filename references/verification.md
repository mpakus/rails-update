# Verification and release gates

Select checks from the actual stack; do not require a browser for a Ruby-only
library or an unavailable external service to validate a documentation edit.
For an application upgrade, account for every applicable row with fresh evidence,
an explicit blocker, or a source-backed reason it is inapplicable.

## Evidence format

Record `revision + dirty-diff identity | date | runtime/platform | environment |
command/flow | result | limitation`. Preserve exit codes. Label results **passed**,
**failed**, **blocked**, **not run**, or **not applicable**. Record test counts,
pending examples and random seed. Keep credentials, customer records, environment
dumps and signed URLs out of logs and committed evidence.

Compare against the baseline to separate new regressions from existing debt.
Baseline debt may still block release; it does not become safe because it predates
the upgrade. A historical full-suite pass, mock, syntax check, route table and
native execution are different kinds of evidence.

For a repeated audit, record the original upgrade revision and the current
release/integration revision separately. Link late fixes to the checks they
invalidate; do not copy a full-suite result forward after a runtime, dependency
or rendering change. Keep generated annotation/schema reordering separate from
semantic changes when reviewing the diff.

Before fixing a shared mechanism, add a compact caller inventory to the existing
finding ledger: `entrypoint | format/variant | role/tenant | focused check`.
For a report this can include an interactive download, a scheduled export, each
job dispatch branch and a shared PDF layout. Reuse representative records with
assertable labels/totals and empty-data cases. Assert rendered content before
stubbing the binary boundary, then verify the real binary separately. This makes
uncovered callers visible without introducing another test framework.

## Ruby helpers

The optional scripts in `scripts/` collect JSON evidence and generate Markdown.
Use plain Ruby from the application's selected runtime, with standard libraries
and Git available, on macOS/Linux. Ruby 2.7 or newer is required. Regression checks
have been exercised on macOS with Ruby 2.7.8, 3.4.2 and 4.0.6; Linux and other Ruby
implementations have not been exercised.
Do not launch them through `bundle exec` or Rails runner: those can evaluate
application code before the snapshot begins. Existing `RUBYOPT` startup hooks
also run before a Ruby script and must be reviewed separately.

Replace these paths. Keep evidence outside the application checkout so writing
the evidence does not change the source identity being measured:

```sh
skill_dir="/absolute/path/to/rails-update"
app_dir="/absolute/path/to/application"
evidence_dir=$(mktemp -d)

# Before changing Ruby, Rails or dependencies:
ruby "$skill_dir/scripts/runtime_snapshot.rb" "$app_dir" > "$evidence_dir/before.json"

# After the upgrade, review these commands and configure an isolated test database.
# Substitute the application's real test commands and required local wrappers.
ruby "$skill_dir/scripts/verify_upgrade.rb" \
  --check 'tests=env RAILS_ENV=test bundle exec rspec' \
  --check 'autoload=env RAILS_ENV=test bundle exec rails zeitwerk:check' \
  "$app_dir" > "$evidence_dir/verification.json"

# Generate a report even when verification returned a nonzero status.
ruby "$skill_dir/scripts/upgrade_report.rb" \
  "$evidence_dir/before.json" "$evidence_dir/verification.json" \
  > "$evidence_dir/report.md"
```

Review the JSON and command logs as well as the report. Add the app's required
checks, such as focused tests, assets or native tools, only after inspecting their
side effects. The helper never chooses a database, runs migrations or seeds,
installs gems, or starts application commands automatically.

- **Snapshot:** records the Ruby process running the helper, `.ruby-version`,
  selected file hashes, and metadata from `Gemfile.lock`. Use `--lockfile PATH`
  on both snapshot and verifier for `gems.locked` or another lockfile. Missing
  metadata stays unknown; this is not a lockfile validator or a Gemfile interpreter.
  Locked Rails/Bundler versions are not evidence of running Rails/Bundler.
  It reads the working checkout, not a supplied Git ref. For another revision,
  inspect it with `git show` or use a disposable checkout before collecting evidence.
- **Verifier:** optionally accepts `--ruby VERSION` for the running Ruby and
  `--rails VERSION` for locked Rails. It compares exact numeric `.ruby-version`
  declarations; aliases or engine-specific declarations require manual review.
  Repeat `--check 'NAME=COMMAND'` for reviewed commands. Commands run sequentially
  in the application directory, inherit the environment, receive no stdin and
  use argv parsing without shell expansion. Use `env NAME=value ...` for explicit
  environment settings; pipes, redirects and shell substitutions are not interpreted.
  Commands and exit codes are recorded; output goes to stderr, outside the JSON.
  Keep secrets out of command arguments and review logs before sharing them.
- **Timeouts and exit codes:** `--timeout SECONDS` defaults to 600 per command;
  a timeout kills that command's process group and records failure. Independent
  checks continue after failures. Verifier exit `0` means the selected checks
  passed; `1` means a check failed; `2` means incomplete evidence or an input/tool
  error. No selected commands means incomplete. Snapshot/report exit `0` means
  evidence/report generation succeeded, not that the upgrade passed.
- **Source identity:** records Git HEAD, branch, staged/unstaged diffs and
  nonignored untracked file contents. A change during checks invalidates the run.
  Ignored files, dependency installations, submodule working contents and external
  services are outside this identity. Without Git, verification stays incomplete.
- **Report:** accepts a baseline snapshot and verification JSON for the same
  application path. It preserves failed, blocked and unrun checks, distinguishes
  locked from running versions and lists remaining verification areas. It does not
  parse test counts, inspect current source, establish database fidelity, or claim
  CI/container/deployment acceptance. Add those results from their actual evidence,
  along with `config.load_defaults` and relevant environment/initializer overrides;
  the scripts hash configuration but do not evaluate its effective values.

## Check matrix

| Gate | Minimum useful evidence | Easily missed failure |
| --- | --- | --- |
| Runtime/dependencies | Actual runtime matches declarations; frozen install for production groups and platforms; workers agree | Developer gems conceal missing runtime dependencies; old Bundler in a later image stage |
| Cold boot/loading | Fresh process in every supported environment; eager load and first request; reload if supported | Initializer order, config acronyms, lazy Warden strategies, boot-time DB writes |
| Routes/API | Compare names/verbs/paths and request behavior; auth, errors, JSON structure, metadata, pagination and content types | Removed custom actions, changed route helpers, keyword-only serializer, accidentally public docs |
| Models/data | Stored-value round trips, callbacks, enums, validation conditions, soft-delete/restore and association resolution | Blank/draft states become invalid; old serialized rows stop loading |
| Bulk writes | Execute joined updates/deletes on disposable data with the target adapter; compare exact affected and preserved IDs | A SELECT passes while mutation SQL is ambiguous or changes the wrong rows |
| Tenancy/auth | Two tenants and roles; forged IDs/filters; session/token lifecycle; full SSO checks if present | Broad search allowlists, global lookups, reports escaping request scope |
| Forms/browser | Invalid create/update, successful persistence and rejected requests; real JS, modal errors, nested selectors, navigation | Blank alert, discarded field, duplicate UJS/Turbo writes, double render in a rejection handler |
| Assets | Production compilation without live services where designed; fetch actual JS/CSS/font/image assets and verify expected code/widget | Colliding logical entrypoints, missing engine/vendor paths, unprocessed ERB, dev-server-only success |
| Queues/schedules | Execute real adapter with synthetic old/new payloads, mail delivery, retry/idempotency; harmless cron check | Inline tests miss serialization; scheduler disabled by build flag; cron log path missing |
| Reports/files | Request/job-to-download path; parse generated PDF/XLS/XLSX/ZIP; representative and empty totals; visual PDF check | Instance variables absent, wrong layout/format, parser accepts an empty artifact |
| Native runtime | Execute PDF and image transformations inside final production architecture/image | Working macOS binary, missing image codec or incompatible OpenSSL in Linux |
| Database | Isolated fresh schema/bootstrap and restored-copy migration; structural and per-tenant fidelity | Seeds query obsolete schema or delete rows; migrations work only on a developer DB |
| Tests | Focused regression checks and full suite under CI-equivalent harness; changed JS checks where applicable | Coverage-only boot crash, global-state leak, excluded slow specs, weakened assertions |
| Lint/security | Target-runtime-compatible tools; changed-code lint and refreshed dependency/static scans with triage | Scanner cannot parse new Ruby; nonzero scan represented as clean |
| Delivery/rollback | Required tests feed build/deploy on the release branch; immutable artifact/revision, web-worker parity and rollback rehearsal | Feature-only tests bypassed by deploy, DB mutation in Docker build, incompatible mixed workers |

## Commands are templates, not a script to run blindly

Inspect project commands and task prerequisites first. Use the repository's
runtime manager and command wrapper. In an isolated, verified test environment:

```sh
git status --short --branch
ruby -v
bundle -v
bundle check
bundle exec rails zeitwerk:check
bundle exec rails routes
RAILS_ENV=test bundle exec rails db:abort_if_pending_migrations
```

Rails tasks can boot code with side effects; configure the isolated database and
sandbox services before running them. Older Rails or non-Rails apps may not have
these tasks. Use the project's equivalent instead of adding one for this skill.
`bundle check` alone does not prove clean/frozen installation on another platform.

Use the existing framework and retain the real CI environment:

```sh
bundle exec rspec path/to/affected_spec.rb
bundle exec rspec
# For a Minitest app, use its existing test and system-test tasks instead.
bundle exec rubocop path/to/changed_file.rb
bundle exec brakeman --no-pager
bundle exec bundler-audit check --update
git diff --check
```

Run only tools the project uses and whose installed versions support the options.
Do not install scanners or a second test framework just because they appear here.
For Ruby libraries use the existing `rake test`, RSpec or other declared task and
check the public API on the supported Ruby range. Test changed dependency groups
and packaging from a clean installation.

Read compiler/build hooks before running asset precompile or image builds. Use
test-only credentials and isolated outputs, avoid production databases, and
preserve existing generated assets. Verify actual served assets with the dev
server/proxy disabled. Do not run asset clobber against a shared checkout merely
to clean a diagnostic build. Scan manifests, HTML layouts, PDF layouts and worker
templates together when an entrypoint changes; retaining Sprockets/Vite/etc. is
usually smaller than replacing them.

## Database and persisted-data rehearsal

1. Read schema format, migration versions, task hooks, seeds and callbacks. Confirm
   the resolved database is disposable before any create/load/prepare task.
   A database environment label alone does not prove isolation.
2. Test the project's fresh-install path in an empty disposable database. If seeds
   are destructive or unsuitable, document the exact safe bootstrap path; do not
   change the main database to make setup succeed.
3. For an existing application, rehearse against an authorized restored copy.
   Compare normalized table/column/type/default/nullability/index/constraint/
   extension inventories, schema version and migration status. Include views,
   triggers, functions, sequences and other structures the application uses.
4. Check row counts by tenant, soft-deleted rows, ownership/FK consistency, enum
   mappings, serialized values and attachment references before and after. A
   textual schema diff, matching table count or model annotation is insufficient.
5. Read old job/session/cache payloads and simulate a safe new write. For rolling
   deploys, test old readers against new writes where that is required. If formats
   are incompatible, define a reviewed drain/rotation strategy and user impact.
6. Use additive migrations and separate restartable/batched backfills only when
   needed. Check existing violations before constraints. Preserve ambiguous data
   and report it; do not infer tenant ownership. A representation-only schema
   change does not justify a migration or row repair.

## Release and rollback

Keep release actions within the user's authorization. Implementation can finish
locally while promotion remains blocked by external acceptance checks.

- Require the intended full tests/security gates on the exact deployable revision.
  Recheck after merges, runtime patches and lockfile/base-image changes. Explain
  any baseline findings explicitly accepted by the responsible owner.
- Build an immutable application image without live DB migration. Run the reviewed
  migration once in an observable release step before processes needing it.
  Confirm web, worker and scheduler artifacts and configuration are compatible.
- Exercise staging/canary flows: login, invalid form, tenant denial, queued work,
  upload, export/download, static assets and each supported deployment variant.
  Monitor boot errors, failed/oldest jobs, latency and scheduler heartbeat.
- Retain the previous image, lockfile, runtime configuration and asset manifest;
  rehearse restoration and data fidelity for high-risk changes. Backups must be
  restorable, not merely present.
- Define stop/rollback triggers and whether old code can read the current schema
  and payloads. Rolling back an image does not undo destructive migrations or
  recover deleted history. Prefer compatible additive changes and a reviewed
  forward fix; never auto-run irreversible database rollback.

The final report should make the distinction clear: source implementation,
local verification, CI evidence, production-image verification and deployment
acceptance are separate outcomes.
