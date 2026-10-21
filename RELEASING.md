# Releasing rails-update

This repository is one portable Agent Skill. Keep `SKILL.md` at the root with
relative links to `references/` and `scripts/`. Tests, CI and release documents
support maintenance; applications need no gem, npm package or required plugin.

## Version policy

Use stable `MAJOR.MINOR.PATCH` versions: patch for compatible corrections, minor for added
capabilities, and major for incompatible helper CLI/evidence-format changes or
removal of supported behavior. The first versioned release is `1.0.0`; earlier
unversioned commits are not retroactively tagged.

The immutable Git tag `vMAJOR.MINOR.PATCH` identifies the released source.
`metadata.version` in `SKILL.md` carries that identity into installations without
Git metadata. Update it, the README's release/install links, and the dated
changelog entry together. The package check requires a matching changelog entry.
Keep later notes under Unreleased until the next version is selected. Do not
change a published tag; correct a release with a new version.

## Validate the candidate

1. Review the staged changes and `CHANGELOG.md`. Keep application names, private
   evidence, credentials and machine-specific paths out of the published package.
2. Run all three checks below. Require the CI matrix on the exact release commit;
   a local macOS pass does not establish Linux portability. Treat legacy Ruby as
   a supported baseline-collection tool, not an application deployment target.
3. Preview discovery and install the local candidate into a disposable project
   for the supported clients. Inspect the installed `SKILL.md`, references and
   scripts; run helper `--help` from that installed path. Discovery alone is not
   an installation test or a live agent invocation test.
4. Confirm the chosen LICENSE is present before advertising an open-source
   release. Review any third-party material and retain required attribution.
5. After publication is authorized, set the version fields and dated changelog,
   commit the reviewed candidate, and require the exact commit's CI matrix to
   pass. Create the matching immutable version tag, push it, and create the
   GitHub release from those notes. No helper
   performs these publication actions. Do not move a published tag.
6. Recheck remote discovery and a disposable remote installation at the released
   ref. Record the exact commit, client/CLI versions and results. The README's
   unpinned install command follows the repository's default branch.

```sh
ruby test/scripts_test.rb
ruby test/ruby_requirements_test.rb
ruby test/package_test.rb
npx skills@1.7.4 add . --list

# Run from an empty temporary project; substitute the candidate checkout path.
npx skills@1.7.4 add /absolute/path/to/rails-update --skill rails-update \
  -a cursor -a claude-code -a codex --copy --yes
```

For the remote check, install from the release's GitHub tree URL, for example
`https://github.com/mpakus/rails-update/tree/v1.0.0`, into another disposable
project. Compare the installed entrypoint, license, references and scripts with
the tagged tree. Attach a versioned source archive and its SHA-256 checksum to
the release if distributing a downloadable package.

The CI workflow tests helper behavior without a Rails application, database,
external services or production secrets. It cannot establish Rails compatibility.
Configure required checks in repository settings separately; a workflow file
does not establish branch protection.
