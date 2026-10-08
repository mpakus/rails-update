# Compatibility catalog

Use the sections matching the inspected application. These are investigation
patterns, not automatic substitutions. Check the selected gem/Ruby/Rails version
before applying an example. For transitions beyond this catalog, inspect upstream
release notes and local dependency source; extend the finding ledger with the
new mechanism and a behavioral check.

## Section index

| Area | Search for / symptom |
| --- | --- |
| Runtime and dependencies | Runtime disagreement, missing standard libraries, implicit APIs lost with removed gems, native builds |
| Removed APIs and loading | Keyword arguments, enums, autoloading, route fragments, framework monkey patches |
| Persistence and search | YAML/JSON, association requiredness, Ransack, joined bulk writes, tenancy |
| Forms and rendering | Error objects, silent validation, strong parameters, format negotiation, mixed asset pipelines |
| Jobs, reports and files | Renderer state, worker context, binary dependencies, imports, cron |
| Authentication and I18n | First-request authentication, SAML, stored sessions, reloadable translation models |
| Tests and delivery | Coverage boot, shared state, seeds, missing test gates, changed behavior hidden by green tests |

## Runtime and dependencies

**Runtime disagreement.** Compare `.ruby-version`, `.tool-versions`/other runtime
configuration, Gemfile/gemspec, lockfile `RUBY VERSION`/`BUNDLED WITH`/`PLATFORMS`,
all Docker stages, CI, deployment scripts and worker images. Confirm `ruby -v`
and `bundle -v` in the process actually used for checks. A Ruby base image may be
the second `FROM`; a development image may pin a different Bundler. Use a matching
runtime before diagnosing `Bundler::RubyVersionMismatch`. Verify a frozen install
and boot in the production dependency groups, not only a developer bundle.

**Removed default/bundled libraries.** Search `require` and production dependency
paths for libraries such as `csv`, `benchmark`, `logger`, `base64`, `bigdecimal`,
`mutex_m`, `ostruct` and `drb`. Their packaging differs by Ruby version. Add an
explicit gem/require only when the target runtime and a real caller need it.
A required runtime library in the development group still breaks a production
image installed without that group. Prove a clean install and production boot.

**Native and transitive dependencies.** Review `pg`, Nokogiri, FFI, Psych,
ImageMagick, TLS libraries and architecture/platform lock entries. Resolve for
the actual Linux libc/architecture as well as the developer platform. Do not
universally enable `force_ruby_platform`, system libraries, insecure TLS, or an
old gem pin: each changes compatibility or security and needs its own evidence.
ZIP/spreadsheet consumers can constrain Rubyzip; change them together when needed
and test real archives/imports. Refresh advisories; old scan counts are not current.

**APIs supplied indirectly by gems.** Before removing an integration gem, inspect
the lockfile dependencies that disappear with it and search their callers too.
Replacing a template integration with its core library can also remove a
pagination gem used by an unrelated index action. Prefer the app's existing
pagination API where equivalent; verify page boundaries, totals, ordering and
unpaginated exports. Check removed Railties/engines for helpers and vendor asset
paths. Absence of that integration's templates does not prove removal is safe.

**Developer tools also cross the boundary.** Inspect RuboCop's supported Ruby
parser/`TargetRubyVersion`, plugin configuration, RSpec/RSwag, Brakeman,
Bundler Audit and database task hooks. An obsolete `annotate` dependency may call
removed `File.exists?` during a migration even when the app boots. Replace/remove
the hook only after finding its callers; verify the replacement task and review
generated annotations separately. Never suppress a tool failure and label it clean.

## Removed APIs and loading

Start with a targeted source search, using only directories present in the app:

```sh
rg -n -o 'update_attributes!?|File\.exists\?|Dir\.exists\?|URI\.(encode|escape)|\.to_s\(:|\.parent\b|Preloader\.new|Zip::Zip' app config lib
rg -n -o 'enum[[:space:]]+[A-Za-z_]+:|serialize[[:space:]]|meta_params|ruby2_keywords' app lib
```

Exit 1 from `rg` means no matches; exit 2 is a search error. These examples neither
parse Ruby nor cover dynamic calls. Read callers, alternate syntax and wrappers.
The `-o` output avoids dumping whole source lines that might contain credentials.

| Candidate | Conditional repair | Proof |
| --- | --- | --- |
| Positional options hash reaches a keyword-only initializer/serializer | Forward `**options` only if the callee expects keywords; preserve positional hashes and normalize keys only when its API requires it | Real endpoint with pagination, metadata, empty results and nested serialization; examine all resource constructors |
| `update_attributes` / bang variant removed | Use `update` / `update!`, preserving callbacks, validations and return/exception behavior | Successful and invalid writes, including imports/tasks |
| `File.exists?` / `Dir.exists?` removed | Use `exist?` in owned source or update the offending dependency | Exercise the task that reaches it, not just Rails boot |
| `URI.encode` / `escape` removed | Encode a query value, path segment or complete URL with the appropriate API; they are different contracts | Spaces, Unicode, slashes, `+`, `&`, filename/header behavior |
| Formatted `to_s(:format)` removed | Use the applicable `to_fs(:format)` API without changing date/time-zone output | Existing report/audit text including nil and DST boundaries |
| Namespace `.parent` removed | Use supported `module_parent` where namespace lookup is intended | Nested controller/component behavior |
| Preloader constructor changed | On versions with this API, `ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call` | Same associations and query behavior in the report using them |
| Old enum keyword form | Convert to `enum :status, mapping, prefix: true` where required; preserve stored mapping, defaults, predicates and scopes | Reload old integer/string values; API/form output and named scopes |
| Enum used only as a lookup with no backing attribute | Inspect schema and all generated-method callers; use a frozen mapping only if there was no persisted enum contract | Existing select options and every caller; do not invent a column to silence boot |
| `Zip::ZipOutputStream`/obsolete adapter | Use the supported Rubyzip API and remove a shim only after checking all callers | Parse the produced archive, assert names/content/encoding and attachment type |

**Configuration APIs.** Check deprecations in every environment, not just test.
Version-dependent changes include mailer `preview_path` to `preview_paths`, RSpec
`fixture_path` to `fixture_paths`, and RSwag `swagger_*` to `openapi_*` settings and
metadata. Update related tasks and consumers together, preserving docs routes,
schemas and authentication. Verify mail previews, fixture discovery, generated
OpenAPI and its served UI/JSON. Check logger load order, structured logging and
request logging: a booting process must still emit usable, redacted diagnostics.

**Zeitwerk and early loading.** Search acronyms, mismatched file constants,
`autoload_paths`, manual `require`, `class_eval`, initializers and empty files
under autoload roots. Check helper/config classes loaded before initializers.
Register needed inflections before the first consumer; give reloadable classes
their expected file and namespace. Use `to_prepare` for reloadable setup where
appropriate; require only truly early/non-reloadable code. Do not eagerly require
the whole application to mask a naming error. Test cold boot, eager load, reload,
and the first HTTP request in a fresh process.

**Routes and framework patches.** Inspect custom `Routing::Mapper#draw`, singular
resources declaring unsupported REST actions, malformed `only:` lists, and
duplicate paths. Prefer the supported native mechanism; compare route names,
verbs, paths and authorization before/after. Remove a patch only when the target
framework handles its actual use case. Apply the same review to database-drop,
Database Cleaner, logger, MIME registry and other internal patches. Never expose
a previously protected engine/docs/queue console to make routing pass.
For mounted Rack/Sinatra tools, check the engine's own host authorization too.
Request specs must use an intended allowed host; verify rejection separately
instead of disabling the host allowlist to fix a test-only default-host failure.

## Persistence and search

**Serialization.** Search `serialize`, `YAML.load`, `YAML.parse(...).to_ruby`,
`unsafe_load`, Psych aliases, `Marshal`, serialized job handlers and audit values.
For APIs requiring keyword options, use an explicit `coder:` without silently
changing the storage format. Preserve existing JSON/YAML null, empty, date/time,
symbol and nested collection behavior. Round-trip existing serialized fixtures
and new writes; a schema load cannot detect this regression.

Remove global `YAML.load = unsafe_load` behavior. Prefer a narrowly scoped safe
loader with only the classes/aliases the stored format requires. A legacy job
backend may require its own trusted object deserializer: document the storage
trust boundary and use its maintained implementation. Never apply unsafe loading
to a request, upload or other untrusted input; do not copy an isolated historical
`unsafe_load` fix to every YAML reader. Do not use `eval` to read Ruby-looking
history strings. A narrow parser must preserve unknown text, handle malformed
input and escape user content when displaying it.

**Associations.** Inspect actual foreign keys, `class_name`, `inverse_of`, touch,
nested attributes, validation conditions and `belongs_to_required_by_default`.
Preserve the application's requiredness, including draft and conditional states.
Uniqueness, formatting, a database FK and nullability do not establish a model
presence validation. Do not add `optional: true` or presence validation globally.
A namespaced association may need an explicit class instead of a data repair.
Prove both valid/invalid transitions, parent touching and tenant ownership.

**Ransack and SQL sorting.** Inspect all searchable/sortable models, associations,
custom ransackers and `auth_object` usage. Derive explicit allowlists from real
forms/API filters and existing role rules. A base-class return of
`authorizable_ransackable_attributes`, all columns or all associations bypasses
the intended review; it is not a universal fix. Test allowed and disallowed fields,
sensitive attributes, association traversal and cross-tenant queries.

`Arel.sql` marks SQL trusted; it does not sanitize it. Wrap only reviewed static
expressions, or construct from an explicit column/direction allowlist with correct
quoting/binds. Verify joined-table ambiguity, null/blank placement, numeric versus
lexical order, `DISTINCT`/pagination and stable tie ordering. Do not delete a sorting
test or merely fall back to ID order if sorting is a supported user feature.

**Joined bulk writes.** Search `update_all`, `delete_all` and the scopes feeding
them, especially scheduled status/retention tasks. A successful SELECT does not
prove the generated mutation SQL works. Rails changed joined UPDATE generation
for PostgreSQL/SQLite ([upstream change](https://github.com/rails/rails/commit/a6bc4b2c138d2ff44f3a56492453af2dee78a954));
reproduce with the target adapter and actual relation shape, including limits or
outer joins when used. Qualify ambiguous predicates with their intended table
using nested hashes or reviewed SQL. On disposable data, execute the real write
and assert exact affected IDs and unchanged excluded/other-tenant rows. Do not
drop a join, tenant filter or condition just to make the statement execute.

**Tenant boundaries.** Follow every record selector through requests, exports,
jobs, nested attributes and autocomplete. Resolve submitted IDs through the active
tenant/authorized parent. Permission checks alone do not scope a global `find`.
Include inactive, soft-deleted and indirect ownership cases; assert both denial
and absence of side effects for a second tenant. Do not automatically retrofit a
different tenancy architecture during a runtime upgrade.

## Forms and rendering

**Error objects.** Modern `ActiveModel::Errors#each` yields error objects rather
than field-name/message pairs. Inspect every consumer, including JS ERB, helpers
and components. Use `error.attribute` and `error.message`, or
`errors.attribute_names` when only fields are needed. Never use `error.to_s` as a
DOM selector or pass the error object into `errors[error]`.

Preserve the actual nested-field selector convention (`.` to `_`, suffix, etc.);
there is no universal selector transformation. Cover invalid create **and** update,
base/nested errors, visible messages and focus/field highlighting. Enable
`render_views` in controller specs that assert response bodies. In a browser,
prove the rendered JavaScript executes: a 200 response can still show no feedback.

**Strong parameters and form state.** Submit the complete real form, including
checkbox fallbacks, multiparameter times, arrays, conditional fields and nested
attributes. Separate UI-only navigation fields from model attributes; account for
multiple parameter readers rather than blanket-permitting everything. Use exact
allowlists and server-derived user/tenant/facility scope. Inspect generated names
and IDs before removing a field: JavaScript may depend on its ID. Verify the saved
record and invalid response with unpermitted parameters raised in focused tests.

**Template and format resolution.** Replace inappropriate handler-suffixed logical
names (`partial.html.slim`, `layout.html.erb`) with logical names and explicit
`formats:` where necessary. Distinguish logical templates from real filesystem
files. A PDF request using an HTML partial needs explicit HTML lookup; a shared
layout must be available in the requested format. Check HTML/JS/JSON/PDF/XLSX and
notification branches that otherwise implicitly render a missing template.

Compile ERB/Slim using the installed engine, then render representative paths.
Check ternaries, parentheses, whitespace-sensitive helper calls, invalid table
markup, escaping and nested controls. Compilation alone misses missing helpers,
template lookup, wrong instance variables and broken JavaScript.

**Asset compilation.** Check explicit Sprockets manifests, gem vendor asset paths,
and extensions needed for preprocessing, such as `.js.erb`. A newer dependency's
JavaScript may exceed the old minifier's syntax support; verify supported options
(for example Uglifier's harmony mode where applicable) before changing pipelines.
Test production compilation and the actual served asset, including error states
and PDF consumers. Do not treat a source-map warning as a failed build or suppress
a real compiler error because the development page loads.

When Sprockets and a bundler both publish `application.js`, inspect which source
the logical name resolves to. Give colliding entrypoints distinct names and update
manifests, normal/PDF layouts, standalone reports and engine consumers together.
Assert that the compiled asset contains the expected library and that a real
widget works with the dev proxy disabled; precompile success alone misses this.

**UJS/Turbo and rejected JavaScript responses.** For mixed legacy frontends, test
remote forms, method/confirm links, redirects, navigation/back and reconnecting
widgets; assert one intended write per action. Inspect duplicate event handlers
before changing frameworks. Exercise CSRF/cross-origin rejection as well as valid
XHR. If rejection happens after rendering, a rescue must discard the rendered
body and preserve the intended error status without triggering a second render.
Do not disable forgery protection to make the response test pass.

**Helpers and legacy widgets.** If a helper patches removed Action View internals
(for example country selection), first try a native form control with the existing
data/options helper. Preserve selected stored value, blank/default rules, name,
ID, classes and accessibility. Check both admin and ordinary forms. ViewComponent
may require `helpers.some_helper` instead of implicit helper inclusion; verify the
rendered markup and behavior rather than asserting an exact formatting string.

## Jobs, reports and files

**Standalone rendering.** Trace request → parameter builder → dispatcher → job →
query → renderer → native tool → storage → authorized download. Background work
does not inherit `current_user`, request params or controller instance variables.
Pass authorized filters and stable identifiers, and re-establish the required
context inside the job without trusting client-supplied scope.

Prefer the supported application controller renderer over manual construction of
Action View internals. `locals: { :@results => data }` does not assign `@results`;
use `assigns: { results: data }` when the template reads that instance variable.
Retain actual locals, helper access, locale, host/protocol, layout and format;
spreadsheet templates generally must not receive an HTML layout. Fix every branch
of the job. A renderer-only test misses dispatcher/constant-lookup and queue bugs.

**PDF and external tools.** A successful binary `--version` is insufficient. In the
final image and actual architecture, render a representative PDF with fonts,
local assets, page headers/footers and the options the app uses. Parse its bytes,
check pages/text, and visually inspect layout. Check patched-Qt requirements,
OpenSSL ABI, glibc/musl, permissions and ARM/x86 mismatches. Do not add obsolete
crypto libraries or change rendering engines merely to make the command start.

**Uploads, archives and spreadsheets.** Preserve attachment API, metadata, storage
keys, styles, content type and existing URLs across a compatible gem replacement.
Exercise old-file download and new upload/processing in isolated storage. Image
codecs may be separately packaged (JPEG/WebP/HEIC); test real decoding, not just
ImageMagick presence. Flush/rewind temporary files before another reader uses
them, supply a required suffix, close/unlink them safely, and validate remote
responses before treating bytes as an archive. Parse XLS/XLSX/ZIP output and check
representative totals, dates and empty datasets; an HTTP 200 is insufficient.

**Workers and schedulers.** Test actual deserialization and execution through the
retained backend, old queued mail/job formats, queue names, retry behavior and
tenant/locale context. Separate build-time initialization from runtime recurring
registration: a build guard must not disable the real scheduler. Verify generated
cron, time zone/DST behavior, runtime user, environment, writable log directories
and a harmless scheduler check-in. A missing redirection directory can prevent
the job command from starting at all.

For retention/batch jobs, use synthetic data with multiple tenant policies,
direct/indirect parents, orphaned or removed types, soft-deleted rows and exact
cutoff boundaries. Prove intended preservation, repeatability and counts. Do not
execute cleanup to validate an upgrade, invent a default retention period, or
change deletion policy to make a compatibility test pass.

## Authentication and I18n

**Authentication starts before the first request.** Test a fresh process with real
middleware and route loading, not only warmed controller tests. Inspect Devise /
Warden strategy registration and any initializer that references application
mailers or mutates gem controllers. Prefer supported hooks or a routed subclass
over loading a controller just to monkey-patch it. Verify failed/successful login,
disabled/unconfirmed accounts, recovery, sign-out and persisted sessions/tokens.
When Rack changes a status symbol, assert the intended numeric response and browser
behavior before updating expectations; don't change behavior to match an alias.

For SAML, verify actual signature trust configuration and rollover certificates,
issuer, audience, recipient/ACS, time validity, replay handling and provisioning.
Test signed success and wrong-signature/issuer/audience/recipient failures through
the routed endpoint. Preserve company/role assignment and password-versus-SSO
policy. A fixture assertion proves local validation only; real IdP smoke remains
separate. Never disable verification or log assertions/credentials as a workaround.

**Database-backed translations.** Inspect backend precedence, explicit coders,
reload hooks, cache invalidation, fallback locales, soft deletion and the configured
translation model. Moving an aliased model into a subclass can change `model_name`,
form parameter roots, table assumptions and CRUD behavior. Verify those contracts,
search and imports. Distinguish single-row `upsert` from batch `upsert_all` and
review conflict targets, validations bypassed and duplicate-data requirements.

**Build without live services.** Asset compilation/schema preparation may run
before translation tables exist. Use the application's deliberate build-only
path when needed; prove a normal runtime still uses database translations and
registers its jobs. Do not broadly rescue every DB error or leave a skip flag in
the deployed environment. Do not replace translation or any external integration
with a silent pass-through value just to make boot/tests pass.

## Tests and delivery

**Coverage-specific boot crashes.** Read `config/boot.rb` and the real CI harness,
including when coverage starts and when Knapsack or equivalent binds. Reproduce
under those exact options. A Bootsnap/Ruby compilation conflict may need a
compatible Bootsnap release; a documented, narrowly scoped
`BOOTSNAP_COMPILE_CACHE=false` can isolate it where supported. Preserve coverage
and add a removal condition for a temporary workaround. Do not assume every
Bootsnap failure has this cause or apply an old version threshold blindly. After
updating the dependency, rerun the original failing harness without the workaround
in isolation before deciding whether it still belongs in CI.

**Order-dependent failures.** Inspect examples mutating global config, `ENV`,
`Current`, I18n backends, time, caches and job adapters. Restore values in the
existing test lifecycle. Reproduce the failing seed, bisect when useful, then
rerun another seed. Avoid retries, disabling random order, mass fixture changes or
weaker assertions as substitutes for isolation. Keep native-tool stubs distinct
from checks that execute the native tool.

**Fresh install and CI gaps.** Review seeds before executing them: old seeds can
query translated fields on the wrong table or delete populated data. Test a fresh
disposable schema and safe bootstrap separately from migration of a restored
database. Check database configuration inheritance; a `host: null` override may
discard CI's intended host. Verify actual effective configuration with secrets
redacted. Follow the workflow from deployment through build to required tests on
the actual release branch, including triggers, `if`, `needs` and tolerated errors.
A test job may run on feature branches yet be skipped on main/develop while the
build/deploy chain runs independently. A stale cached artifact is no test gate.

Check image builds for migrations, remote DB access, credential keys copied into
layers, startup side effects and removed features hidden behind mocks. Migrations
belong in an observable, once-per-release operation, not image construction.
Report tracked secret paths without printing values; removal, rotation and
history remediation require a concrete plan within the user's authorization.
