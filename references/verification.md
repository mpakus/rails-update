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

## Check matrix

| Gate | Minimum useful evidence | Easily missed failure |
| --- | --- | --- |
| Runtime/dependencies | Actual runtime matches declarations; frozen install for production groups and platforms; workers agree | Developer gems conceal missing runtime dependencies; old Bundler in a later image stage |
| Cold boot/loading | Fresh process in every supported environment; eager load and first request; reload if supported | Initializer order, config acronyms, lazy Warden strategies, boot-time DB writes |
| Routes/API | Compare names/verbs/paths and request behavior; auth, errors, JSON structure, metadata, pagination and content types | Removed custom actions, changed route helpers, keyword-only serializer, accidentally public docs |
| Models/data | Stored-value round trips, callbacks, enums, validation conditions, soft-delete/restore and association resolution | Blank/draft states become invalid; old serialized rows stop loading |
| Tenancy/auth | Two tenants and roles; forged IDs/filters; session/token lifecycle; full SSO checks if present | Broad search allowlists, global lookups, reports escaping request scope |
| Forms/browser | Invalid create/update and successful persistence; real JS, modal errors, nested selectors, helper widgets | 200 response with blank alert, console error, field silently discarded |
| Assets | Production compilation without live services where designed; fetch actual JS/CSS/font/image assets | Missing vendor paths, wrong entrypoint, `.js` with unprocessed ERB, dev-server-only success |
| Queues/schedules | Execute real adapter with synthetic old/new payloads, mail delivery, retry/idempotency; harmless cron check | Inline tests miss serialization; scheduler disabled by build flag; cron log path missing |
| Reports/files | Request/job-to-download path; parse generated PDF/XLS/XLSX/ZIP; representative and empty totals; visual PDF check | Instance variables absent, wrong layout/format, parser accepts an empty artifact |
| Native runtime | Execute PDF and image transformations inside final production architecture/image | Working macOS binary, missing image codec or incompatible OpenSSL in Linux |
| Database | Isolated fresh schema/bootstrap and restored-copy migration; structural and per-tenant fidelity | Seeds query obsolete schema or delete rows; migrations work only on a developer DB |
| Tests | Focused regression checks and full suite under CI-equivalent harness; changed JS checks where applicable | Coverage-only boot crash, global-state leak, excluded slow specs, weakened assertions |
| Lint/security | Target-runtime-compatible tools; changed-code lint and refreshed dependency/static scans with triage | Scanner cannot parse new Ruby; nonzero scan represented as clean |
| Delivery/rollback | Active required CI, immutable artifact/revision, web-worker parity, release migration and rollback rehearsal | Image built without tests, DB mutation in Docker build, incompatible mixed workers |

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
