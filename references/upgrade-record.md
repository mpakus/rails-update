# Upgrade record template

Adapt this into the application's existing upgrade document when crossing
multiple major versions. Keep one maintained record; do not copy this template
into the public skill with private project evidence filled in. Add links to
sanitized logs and helper JSON rather than copying raw customer or secret data.
Adjust reference links for the destination document when copying this template.

## Scope and identities

| Field | Value to record |
| --- | --- |
| Request | Analyze, implement, or audit; exact requested Ruby/Rails targets |
| Baseline | Commit, lockfile identity, Ruby/Rails/Bundler, defaults and explicit overrides |
| Original upgrade | Commit and comparison base; ancestry or content-comparison result |
| Current integration | Exact commit plus dirty-diff identity, runtime and lockfile |
| Deployed baseline/target | Image digests and observed web/worker runtime, or unknown |
| Strategy | Local staged checkpoints or direct target; separate deployment sequence |
| Retained contracts | Defaults, tenancy, queue, sessions, attachments, assets and persisted formats |
| Excluded work | Unrelated modernization/features and separately tracked defects |

## Transition evidence

Create a row for every crossed Rails minor series and Ruby compatibility boundary.
Keep **planned**, **documented historical**, and **executed in this review** distinct.
For each check use passed, failed, blocked, not run, or not applicable with a reason.

| Transition | Source/lock identity and runtime | Evidence provenance/date | Applicable changes and checks | Result and remaining gap | Deployed? / image |
| --- | --- | --- | --- | --- | --- |
| Starting baseline | Fill from the old revision | Link actual evidence | Tests and known failures | Do not infer a pass | Record observed state |
| Each crossed boundary | Exact identity or unavailable | Plan, historical record, or fresh execution | Affected mechanism and check | Explicit result | Unknown unless verified |
| Final integration | Include late fixes and final runtime | Current command/flow evidence | Full applicable verification matrix | Separate local and release gates | Exact image or not deployed |

## Dependency decisions and findings

| Dependency | Old → selected | Compatibility constraint / reason | Contract to preserve | Check |
| --- | --- | --- | --- | --- |
| Relevant dependency | Exact versions | Source-backed reason | Stored format or public behavior | Command/flow and evidence link |

| Location / entrypoint | Trigger | Classification | Cause and fix | Verification | Remaining gate |
| --- | --- | --- | --- | --- | --- |
| Actual caller | Reproduction | Regression, pre-existing, risk, or unknown | Smallest confirmed change | Revision, command and result | Owner / next action |

## Final verification and rollout

Use the [verification matrix](verification.md#check-matrix) as the starting point.
List focused/full tests, pending examples, warnings, boot/routes, assets, browser/API,
jobs/scheduler, native image, data restore/fidelity and external integrations
separately. Include the CI run URL and each required job's result on the exact SHA.

Record the old and new readers/writers for sessions, caches, jobs and serialized
data, any required overlap restriction, the rollback image, and restore-rehearsal
results. State unresolved release gates and separate the later framework-defaults
rollout from the runtime upgrade. A generated helper report is supporting evidence,
not a substitute for this applicability and rollout assessment.
