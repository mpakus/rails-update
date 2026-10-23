# Changelog

## Unreleased

## 1.1.0 — 2026-10-23

Local release candidate; not yet tagged or published.

### Added

- Old-runtime queued-job fixtures, legacy mail readers, keyword/positional-hash
  compatibility, retry checks and explicit drain/rollback criteria.
- Bundler settings across deployment processes and checks for every deployed
  environment, database mode, pool, migration path and ledger.
- Deferred attribute-type preservation, raw-value checks on unrelated writes,
  missing-column diagnosis and historical encryption fixtures.
- Active Storage controller, callback, transformation, schema and old-writer
  compatibility checks; template-buffer and complete-mail rendering checks.
- DatabaseCleaner worker-visibility diagnosis and failing-shard reproduction,
  including verification that earlier fixes survive later branch integration.
- Narrow dependency-bound patches with provenance and asset parity, Ruby 4
  duplicate-key guards, Bundler version output and warning attribution.

### Clarified

- Error insertion, association requiredness and uniqueness behavior must be
  verified against effective configuration and the actual adapter.
- Local repairs, integrated code, historical CI and release acceptance remain
  separate evidence. Helper CLIs and evidence formats are unchanged.

## 1.0.0 — 2026-10-21

First versioned release of the existing skill; earlier publications followed
`main` without version tags.

### Added

- Multi-major Rails upgrade guidance covering Rails 5.2 through 8.1, including
  direct-target audits and the difference between Git, test and deployment history.
- An upgrade record template for checkpoint evidence, dependency decisions,
  follow-up fixes and rollout/rollback gates.
- Worker/scheduler launcher checks and explicit coverage of all Ruby boundaries
  when an older runtime jumps to Ruby 4.
- Devise major-upgrade checks for signing-key lookup and cold first requests.
- Package version metadata and a documented installation pinned to the release.
- Chat invocation and practical planning, implementation, audit and report examples.

### Included from earlier unversioned updates

- Add Ruby 4 compatibility guidance, regression recipes and a frozen-bundle
  checker using semantic Ruby version requirements.
- Record helper-process YJIT/ZJIT state; keep report generation independent of
  the full CGI library removed from Ruby 4's default distribution.
- Add form persistence checks for rendered input names, checkbox clearing,
  nested deletion, callbacks, dates, uploads and tenant boundaries.
- Check coupled Ruby/JavaScript dependency upgrades and individual CI job
  results, including skipped tests on deployment branches.
- Add package-path checks, a Ruby/Linux/macOS CI matrix and release instructions.
- License the skill and helpers under MIT.

The helpers collect selected evidence; they do not certify application upgrades
or run application commands without explicit selection.
