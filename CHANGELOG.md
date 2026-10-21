# Changelog

## Unreleased

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
