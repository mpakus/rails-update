---
name: rails-update
description: >-
  Plan, implement, or audit Ruby and Ruby on Rails upgrades, including dependency
  compatibility, removed APIs, hidden runtime regressions, data preservation,
  test and container parity, and release readiness. Use for a runtime/framework
  version change or failures caused by one. Supports Ruby-only applications and
  existing Rails stacks; does not prescribe a rewrite or unrelated modernization.
---

# Rails update

Upgrade the application's runtime while preserving its observable behavior and
stored data. Find gaps through source tracing, transition-specific upstream
changes, and executable checks. A clean boot or an empty search cannot establish
that every hidden issue has been found.

## Establish the requested outcome

- **Analyze/plan:** inspect and produce a prioritized upgrade plan; do not edit
  application code or resolve a new lockfile.
- **Implement/fix:** make the smallest necessary compatibility changes and run
  their checks. A request to perform the upgrade already authorizes this work.
- **Audit an existing upgrade:** compare the specified revisions and test the
  changed behavior; fix findings only when that is also requested.

Honor the requested Ruby/Rails targets. If the user asks for the latest supported
versions, verify current official releases, support policy, and gem requirements.
Do not use a version from this skill or a previous application as the target.
An upgrade request alone does not authorize production mutations, publication,
credential rotation, destructive maintenance, or an architectural replacement.

## 1. Establish the actual baseline

Read repository instructions and architecture, database, testing, and operations
documents relevant to the change. Preserve existing work. Record the checkout,
branch, HEAD, requested SHA, dirty files, and the comparison base. Inspect exact
commits with `git show`; do not switch another person's checkout just to read it.
Verify ancestry before attributing an earlier fix to a requested snapshot. A
commit subject, branch name, or old audit does not establish the runtime.

Use [scripts/runtime_snapshot.rb](scripts/runtime_snapshot.rb) when a reusable
JSON baseline would help. Run it with plain Ruby, not `bundle exec` or Rails
runner. It reads declared metadata without evaluating the Gemfile or booting Rails;
it does not prove the application, container or workers use that runtime.

Build a compact baseline with:

- Declared **and running** Ruby, Rails, Bundler, framework defaults and explicit
  overrides; gem lock platforms, Git dependency revisions and production groups.
- Runtime files, version-manager configuration, containers including every stage,
  CI jobs, workers, schedulers, Node/package locks, database adapter and server.
- Authentication, tenant boundaries, sessions, caches, stored serialization,
  attachments, jobs, report generators, assets, external binaries and integrations.
- Baseline focused/full tests, production-like boot, route/API behavior, schema
  structure and known warnings. Inspect test boot and seed scripts before running
  them; use an isolated test database and sandboxed external services.

For Ruby-only applications, substitute the gemspec, executable entrypoints, public
API, supported Ruby matrix, packaging and existing test task. Mark Rails-only
checks inapplicable with evidence; do not add Rails structure.

## 2. Choose testable checkpoints

Use the [Rails upgrade guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)
and release notes for **each crossed version**. Prefer one Rails minor series per
checkpoint, at a compatible patch release, with a separate Ruby checkpoint when
the support ranges permit. Choose a Ruby bridge from the actual intersection of
Rails, Bundler, native gems and deployment support; never hardcode a bridge.

Keep the existing `config.load_defaults` and deliberate overrides during the
version change. New defaults, cache/cookie formats, queue/storage replacements,
and business behavior need their own tested changes. Do not introduce a new
application stack merely because a generator recommends it.

Update only the named gems needed for the checkpoint. Review transitive changes,
licenses and native platform resolution. Prefer a compatible maintained release,
then an existing local pattern or native API, before a narrowly scoped patch.
Inspect `app:update` output in a disposable copy or supported preview mode;
merge individual required changes instead of overwriting configuration.

Do not downgrade an already upgraded application just to reconstruct historical
checkpoints. Audit its final state and use an isolated baseline when comparison
is needed. Old test results remain historical evidence.

## 3. Search for the gaps that boot misses

Use the [compatibility catalog](references/compatibility.md). Read its section
index first, then the sections matching the detected stack and version crossing.
For every applicable area, record a concrete check or why it cannot yet run.
Search the whole mechanism, including controllers, concerns, helpers, components,
templates, services, jobs, tasks, engines, initializers and tests. Use repository
search or `rg`; use a reference index only if it is available and relevant.

For each candidate:

1. Read the callee, every caller and the target-version implementation or official
   API. Search hits are leads, not confirmed defects.
2. Trace the actual user path through authorization, parameters, persistence,
   response rendering and any queued work or external tool.
3. Reproduce on synthetic or sanitized data. Add the smallest regression check
   that observes behavior, not just a mock of the replacement API.
4. Fix the shared cause, then check sibling paths: create/update, HTML/JS/JSON,
   synchronous/queued reports, admin/ordinary user, and every supported variant.
5. Search again and classify remaining matches. Do not hide the error by removing
   a validation, broadening permissions, disabling an integration, stubbing the
   failing path, or deleting its test.

Keep a small finding ledger in the existing upgrade document (or create one if
needed): `location | symptom/trigger | baseline or regression | cause | fix |
verification | remaining gate`. Distinguish confirmed failures, source-confirmed
risks, hypotheses, pre-existing debt, and unavailable evidence. Continue safe,
independent work when one external gate is blocked.

## 4. Preserve the persisted contracts

Read [verification and release gates](references/verification.md) before database,
job, authentication, or deployment checks. Never run destructive seeds, cleanup
jobs, schema loads or database resets against an existing working database as a
diagnostic. Inspect initializer side effects before even a Rails runner or route
command: boot may register jobs or contact external services.

Do not edit applied migrations or hand-edit generated schema dumps. Distinguish
schema/annotation representation changes from structural changes. If a data
change is necessary, use an additive, reversible, scoped migration with a separate
backfill and fidelity checks. Unknown ownership is not permission to reassign or
delete data. Existing retention rules are business contracts, not upgrade repairs.

Exercise old persisted enum values, YAML/JSON, audit history, job payloads, signed
data and attachment metadata under the new runtime. Test old/new process overlap
where deployment permits it. Keep sensitive fixtures, tokens, keys and dumps out
of source and evidence; report discovered secrets by path only.

## 5. Verify and report the actual result

Apply the relevant matrix in [verification.md](references/verification.md).
Run focused checks first, then the full suite for an upgrade. Use the same coverage,
test-distribution, dependency groups and compiled assets as CI. A Ruby patch,
lockfile, base-image or late source change invalidates affected earlier evidence.

For repeatable local evidence, use [scripts/verify_upgrade.rb](scripts/verify_upgrade.rb)
with explicitly selected, reviewed commands, then [scripts/upgrade_report.rb](scripts/upgrade_report.rb)
to summarize the baseline and results. Follow the [helper instructions](references/verification.md#ruby-helpers).
No command checks are selected automatically; a generated report is not release approval.

Deliver the requested changes and a concise report containing:

- Exact revision/runtime/defaults reached and compatibility fixes made.
- Focused tests, full suite, lint, security scans, boot/routes, assets, browser/API,
  jobs, native container and database fidelity results **separately**.
- Each remaining failure or unverified gate, its impact and the next concrete
  action. Report tool unavailability as blocked, not passed.
- Release/rollback readiness and documentation changes. Deployment readiness
  requires current evidence for every required gate; never claim zero hidden gaps.

Use the project's existing tools and test framework. Shell examples in the
references use ordinary commands; honor local wrappers such as RTK when required.
This skill requires no particular editor, connector, index server, or agent API.
