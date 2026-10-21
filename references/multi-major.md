# Multi-major Rails upgrades: Rails 5 to Rails 8

Read this when planning a multi-major upgrade, continuing a direct-to-target
implementation, or auditing a commit that appears to skip Rails 6 and 7. The
versions below describe compatibility boundaries, not recommended patch targets.
Choose patches and Ruby bridges from current upstream support and the actual
dependency graph.

## Establish what was skipped

A change from a Rails 5 lockfile to a Rails 8 lockfile establishes the committed
endpoints. It does not establish the implementation or deployment sequence.
Record these three histories separately:

| History | Evidence to inspect | What it establishes |
| --- | --- | --- |
| Committed | Parent/target lockfiles, runtime files, defaults, branch ancestry and file comparisons | Source changes retained in Git |
| Locally exercised | Checkpoint records, exact lockfile/source identities, commands, logs, runtime and test results | Versions actually tested; a plan is not a result |
| Deployed | Image digests, deployment records, running web/worker versions and smoke results | Versions actually promoted and observed |

A single combined or squashed commit can contain a locally staged upgrade. A
later integration commit can also contain additional fixes or unrelated features.
When ancestry differs, compare relevant file contents before calling fixes absent.
Do not describe all three histories as a direct jump based on the commit count.
Keep undocumented intermediate execution **unknown**, not assumed passed or failed.

## Choose the path without changing the goal

For a new upgrade, prefer local checkpoints through every minor series, using
deprecation warnings to find changes before their APIs disappear. Separate Ruby
changes where the dependency intersection allows it. This follows the
[Rails upgrade process](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#the-upgrade-process).

For a Rails 5.2 → 8.1 target, the transition inventory is:

```text
5.2 → 6.0 → 6.1 → 7.0 → 7.1 → 7.2 → 8.0 → 8.1
```

This is a review and validation sequence, not a requirement to run every version
in production. A deployment may move from the old application directly to the
verified final image after local checkpoints and a production-like rehearsal.

If the user requests a direct implementation, or it already exists, keep that
target. Inventory all crossed changes, then fix and test the target application.
Record the missing intermediate warning/test evidence and the checks that address
each applicable boundary. Use an isolated intermediate runtime only when it helps
diagnose a failure or establish a comparison; do not downgrade the active checkout
just to manufacture a checkpoint history. Report a direct attempt as incomplete
when applicable target or rollout checks remain unverified.

## Separate runtime compatibility from framework defaults

Keep the original `config.load_defaults` and deliberate overrides during the
runtime change. Record association requiredness, session storage, job adapter,
serialization and asset choices explicitly. Later defaults activation is a
separate behavior change, as described in the
[Rails defaults guidance](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#configure-framework-defaults).

`config.load_defaults 5.2` does **not** make Rails 8 behave like Rails 5 in every
respect. Removed methods, changed dependency APIs and loader requirements still
apply. New applications' queue, storage or asset choices are not a migration plan
for an existing application. Retain compatible subsystems unless the requested
scope or a demonstrated incompatibility requires a replacement.

## Review the crossed boundaries

Use these rows to route investigation; they are not an exhaustive release-note
checklist. Record applicability, the actual affected caller, and an executable
check or blocker. Some mechanisms change across several releases or dependencies;
verify the selected version's API before editing. Detailed repair recipes stay in
the linked references.

| Boundary | Inspect | Useful regression evidence |
| --- | --- | --- |
| Ruby 2.7 → 3.x, when crossed | Positional hashes versus keyword arguments in serializers, wrappers, jobs and framework extensions; [Ruby's keyword migration](https://www.ruby-lang.org/en/news/2019/12/12/separation-of-positional-and-keyword-arguments-in-ruby-3-0/) | Real paginated API metadata and delegated calls; preserve positional-hash APIs rather than adding `**` everywhere |
| Rails 5.2 → 6.x | Loader naming, early configuration consumers, inflections, route-drawing shims, custom framework patches | Eager loading, reload, all route fragments and cold first requests; follow the [Zeitwerk migration guide](https://guides.rubyonrails.org/classic_to_zeitwerk_howto.html) |
| Rails 6.1 | `ActiveModel::Errors` object iteration and removed namespace APIs; [6.1 release notes](https://guides.rubyonrails.org/6_1_release_notes.html) | Invalid HTML/JS/JSON submissions display the correct field errors and retain input; happy-path saves cannot cover this |
| Rails 7.0 | Classic loader removal, explicit Sprockets dependencies, old view/preloader/formatting calls; [7.0 upgrade notes](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-6-1-to-rails-7-0) | Compile the retained assets, exercise remote forms and standalone reports; confirm the actual autoloader instead of adding obsolete configuration switches |
| Rails 7.1 | Serialization coder contracts, load paths, logging, cache and signed-data settings; [7.1 release notes](https://guides.rubyonrails.org/7_1_release_notes.html) | Old stored values and new writes, operational logs, and old/new reader compatibility for formats actually changing |
| Rails 7.2 | Test behavior with the configured queue adapter and custom attribute aliases; [7.2 upgrade notes](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-7-1-to-rails-7-2) | Enqueue and execute retained mail/job paths; a test adapter stub does not prove worker execution |
| Rails 8.0 | Removed keyword enum syntax and fresh-database task behavior; [8.0 release notes](https://guides.rubyonrails.org/8_0_release_notes.html) | Reload historical enum values, predicates and scopes; distinguish fresh schema bootstrap from migrating an existing database |
| Rails 8.1 | Schema dump ordering; [8.1 upgrade notes](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html#upgrading-from-rails-8-0-to-rails-8-1) | Compare structural schema inventories rather than line counts; retest the final runtime after regeneration |
| Ruby 4, when crossed | Standard-library packaging, native gems and serialization boundaries | Apply [Ruby 4 checks](ruby-4.md) in addition to the earlier Ruby boundaries |

For each Rails hop, also review the **selected dependency versions**. Ransack
allowlists, Devise/SAML integration, Paperclip-compatible storage, database I18n,
Audited/Paranoia, Rack/Puma, PDF binaries and development tasks can change across
several gem majors independently of Rails. Record `old → selected | constraint |
reason | stored contract | check` rather than copying another project's bundle.
Keep annotation-only model changes separate from executable model changes.

For example, [Devise 5](https://github.com/heartcombo/devise/blob/main/CHANGELOG.md)
changes secret-key lookup and accommodates Rails 8 lazy routes. Test the effective
signing-key contract without exposing keys, and password/remember-me/SAML on the
first request in a fresh process. Keeping Rails 5.2 defaults does not opt out of
these gem-level changes.

Use the [compatibility catalog](compatibility.md) for conditional fixes and
[form persistence checks](forms.md) for rendered names, clearing, nested deletion,
callbacks and reload assertions. A passing response or a newly valid record does
not prove that the user's submitted fields reached storage.

## Validate the deployment jump as its own transition

Local intermediate tests do not establish compatibility between the oldest
deployed process and the final target. Use the [release gates](verification.md#release-and-rollback)
for the exact pair that will overlap or be used for rollback:

- Read sanitized existing serialized rows, audit values, sessions, queued jobs
  and attachment metadata under the target. Where old/new processes overlap,
  test both write/read directions; pause only the affected producers/consumers
  when a proven incompatibility requires it.
- Test web, worker, scheduler and asset-build entrypoints separately. Use each
  launcher's real Bundler/environment context; a scheduler invoked outside
  `bundle exec` can fail even when request specs pass. Generate schedules without
  installing crontabs or sending jobs to a live queue.
- Verify production assets with build-time side effects excluded deliberately,
  then verify normal runtime initialization still registers required work.
- Rehearse both a clean bootstrap and an upgrade of restored data. Compare schema
  structure, stored values and tenant ownership; no migration file does not mean
  no compatibility risk. Separate business migrations bundled into a release.
- Recheck the final integration revision and deployment branch's actual CI jobs.
  Follow-up form, PDF, authentication or runtime fixes invalidate the affected
  earlier evidence. Classify old defects separately instead of declaring every
  later fix to be caused by the framework jump.

Keep the [upgrade record](upgrade-record.md) alongside the application's existing
upgrade plan. Save helper evidence per actual checkpoint, outside the checkout;
never regenerate a supposed historical baseline from the already upgraded tree.
