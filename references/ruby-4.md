# Ruby 3.4 to 4.0: checks and regression specs

Use when crossing into Ruby 4, including dependencies and operational scripts.
These are conditional checks, not a mandate to change Rails or enable a JIT.
The [RubyInsights article](https://rubyinsights.blog/en/blog/ruby-3-4-4-to-ruby-4-0-3-upgrade-guide-rails)
prompted this review on 2026-10-16. Verify the chosen patch and resolved gem
versions; an article's example target is not a current release recommendation.

## Dependency and runtime checks

- Bundled gems are shipped with Ruby but must be in the resolved bundle to be
  available under Bundler. Inspect actual callers before adding direct dependencies.
  For CGI escaping alone use `require "cgi/escape"`; full CGI features need the gem.
  Test in a clean production-group bundle, including rake tasks and workers.
  See the [Ruby 4 release notes](https://www.ruby-lang.org/en/news/2025/12/25/ruby-4-0-0-released/).
- Run [check_ruby_requirements.rb](../scripts/check_ruby_requirements.rb) on the
  current working runtime before changing its Ruby declaration. It checks the
  installed bundle's requirements against the candidate with `satisfied_by?`.
  A regex for `< 4` misses pessimistic bounds, exclusions and higher minimums.
  Passing metadata does not prove native extension or application compatibility.
- Build dependencies for the target Ruby ABI, platform and libc in an isolated
  install/image; use cache keys that distinguish those inputs and the lockfile.
  Do not blindly delete shared bundles or run `bundle pristine`: it restores gem
  sources and can erase local gem edits. Test real native operations afterward.
  See [Bundler pristine](https://bundler.io/man/bundle-pristine.1.html).

From the app directory, with its baseline Ruby/Bundler and reviewed Gemfile:

```sh
skill_dir="/absolute/path/to/rails-update"
target_ruby="4.0.7" # Example only: substitute the requested, verified target.
ruby "$skill_dir/scripts/check_ruby_requirements.rb" --target "$target_ruby"

# Exercise the actual app paths; this enables warnings, not warnings-as-errors.
# Preserve any required existing RUBYOPT startup options.
RUBYOPT="${RUBYOPT:+$RUBYOPT }-W:deprecated" bundle exec rspec
```

Keep the test command's exit code and complete stderr; piping through `grep`
can conceal failures and cannot prove that unexecuted code is warning-free.
Use the project's test-only warning policy if warnings must fail CI. Ruby's
[`Warning`](https://docs.ruby-lang.org/en/4.0/Warning.html) and Rails deprecation
handling are separate mechanisms; do not install a global production warning patch.

## Search leads and the specs to add

Use only directories present in the app. These searches intentionally return
locations/tokens, not whole lines that could expose credentials. Exit 1 means no
matches, not proof of compatibility; inspect aliases, wrappers and dynamic inputs.

```sh
rg -n -o 'Ractor|SortedSet|Process::Status|Net::HTTP|OpenStruct|CGI::Cookie|CGI\.parse|implicit_parameters|local_variable_get' app lib config spec test
rg -n -o -- '--rjit|--yjit|--zjit|RUBY_YJIT_ENABLE|RUBY_BOX' .github Dockerfile* config bin
rg -n -o '(Kernel\.)?open|IO\.(read|binread|readlines|foreach)|IO\.popen|\$\?|Marshal\.(load|dump)' app lib config
```

Adapt these to the existing spec suite and real application entrypoints:

| Trigger | Repair and smallest useful regression |
| --- | --- |
| Leading-pipe `open`/IO calls | Use an explicit process API with argv, not interpolated shell text. Test output, nonzero exit and arguments containing spaces/metacharacters through the actual wrapper. Keep filename reads distinct. |
| Bitwise `Process::Status` handling | Use `success?`, `exitstatus`, `signaled?`/`termsig` as appropriate. Exercise success, failure and signal termination; a signaled process has no normal exit code. |
| Ractor messaging | Distinguish a final result (`value`) from a stream (`Ractor::Port`). Test multiple messages, termination/error propagation and closure with bounded waits; don't rewrite arbitrary `.take` calls. |
| Set/SortedSet consumers | Assert membership and required ordering, not incidental `inspect` text. Preserve sorting if it is a product contract. `SortedSet` needs its explicit library. |
| Error/backtrace or reflection consumers | Test error grouping with a real application exception and its source location. Exercise numbered-parameter/Proc metadata consumers only where used; avoid replacing every error snapshot blindly. |

These changes are documented in [Ruby 4 NEWS](https://docs.ruby-lang.org/en/4.0/NEWS_md.html).

**Outbound HTTP deserves a request contract spec.** Newer `net-http` no longer
adds a form content type to an arbitrary body. Inspect the resolved gem version,
including wrappers; don't infer behavior just from Ruby's version. In the app's
existing HTTP fake or a local server, call the real client and assert the received
method/path, Content-Type and decoded payload. For forms include spaces, `+`, `&`
and Unicode; for JSON assert JSON decoding. Set headers to match the actual body,
and check failure responses without contacting the real integration.
See the [upstream change](https://github.com/ruby/net-http/issues/205).

**Serialization and rollback need two runtimes.** Using synthetic trusted data,
write representative cache/session/job payloads on the old runtime, read on the
new one, then reverse the direction when rolling rollback requires it. Include
the actual serializer/gem versions and signing configuration. A same-process
round trip does not prove that the previous image can read new writes. Do not
assume all formats stay compatible just because no migration was added.

The [ERB advisory](https://www.ruby-lang.org/en/news/2026/04/21/erb-cve-2026-41316/)
depends on untrusted Marshal input and loaded ERB/ActiveSupport, not merely the
existence of a Rails cache. Verify the selected ERB gem against current advisories;
changing Ruby alone does not override an older locked gem. Patching a gadget
does not make `Marshal.load` safe for untrusted data.

## JIT and production comparison

Record actual YJIT/ZJIT state in each tested process; the snapshot/report helpers
record only their own process. Preserve the existing JIT policy during the
compatibility change. If changing it, compare warmed latency, throughput, error
rate and per-worker RSS under equivalent traffic, worker/thread count and limits.
Never promise a memory or speed gain from release notes alone. Check launch flags
for removed RJIT options; enabling experimental ZJIT or Ruby::Box is separate work.
