# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "shellwords"

SCRIPTS = File.expand_path("../scripts", __dir__)

def assert(condition, message)
  raise message unless condition
end

def run_script(name, *args)
  out, err, status = Open3.capture3(RbConfig.ruby, File.join(SCRIPTS, name), *args)
  [out, err, status.exitstatus]
end

def git(root, *args)
  out, err, status = Open3.capture3("git", "-C", root, *args)
  assert(status.success?, "git #{args.first}: #{out} #{err}")
end

def ruby_command(code, *args)
  Shellwords.join([RbConfig.ruby, "-e", code, *args])
end

Dir.mktmpdir("rails-update-tests-") do |tmp|
  app = File.join(tmp, "app with spaces")
  FileUtils.mkdir_p(File.join(app, "config"))
  File.write(File.join(app, "Gemfile"), 'raise "Gemfile must not be evaluated"')
  File.write(File.join(app, "config/application.rb"), 'raise "Rails must not boot"')
  File.write(File.join(app, ".ruby-version"), RUBY_VERSION)
  File.write(File.join(app, "Gemfile.lock"), <<~LOCK)
    GEM
      remote: https://user:DO_NOT_PRINT@example.invalid/
      specs:
        rails (8.1.3)

    PLATFORMS
      ruby
      arm64-darwin

    DEPENDENCIES
      rails

    RUBY VERSION
       ruby #{RUBY_VERSION}p0

    BUNDLED WITH
       4.0.15
  LOCK
  git(app, "init", "--quiet")
  git(app, "add", ".")
  git(app, "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--quiet", "-m", "baseline")

  out, err, code = run_script("runtime_snapshot.rb", app)
  assert(code == 0, "snapshot failed: #{err}")
  before = JSON.parse(out)
  assert(before.dig("declared", "rails_locked") == ["8.1.3"], "Rails metadata missing")
  assert(before.dig("declared", "platforms_locked") == %w[arm64-darwin ruby], "Platforms missing")
  assert(before.dig("declared", "bundler_locked") == "4.0.15", "Bundler metadata missing")
  assert(before.dig("git", "status") == "", "Expected clean Git state")
  assert(!out.include?("DO_NOT_PRINT"), "Source credentials leaked")
  baseline = File.join(tmp, "before.json")
  File.write(baseline, out)

  File.write(File.join(app, "untracked.rb"), "one")
  first = JSON.parse(run_script("runtime_snapshot.rb", app).first)
  File.write(File.join(app, "untracked.rb"), "two")
  second = JSON.parse(run_script("runtime_snapshot.rb", app).first)
  assert(first.dig("git", "changes_sha256") != second.dig("git", "changes_sha256"), "Untracked content changes were missed")
  File.unlink(File.join(app, "untracked.rb"))

  out, _, code = run_script("verify_upgrade.rb", app)
  assert(code == 2 && JSON.parse(out)["status"] == "incomplete", "No commands must not produce a pass")

  literal = "$(touch should-not-exist)"
  success = ruby_command('abort unless ARGV.first == "$(touch should-not-exist)"; puts "CHECK_LOG"', literal)
  out, err, code = run_script("verify_upgrade.rb", "--ruby", RUBY_VERSION, "--rails", "8.1.3", "--check", "test=#{success}", app)
  verified = JSON.parse(out)
  assert(code == 0 && verified["status"] == "passed", "Selected checks failed: #{err}")
  assert(err.include?("CHECK_LOG"), "Command output did not stay on stderr")
  assert(!File.exist?(File.join(app, "should-not-exist")), "Command was interpreted by a shell")
  evidence = File.join(tmp, "verification.json")
  File.write(evidence, out)
  report, err, code = run_script("upgrade_report.rb", baseline, evidence)
  assert(code == 0 && report.include?("**passed**") && report.include?("Unlisted gates are unverified"), "Report failed: #{err}")
  assert(!report.include?("DO_NOT_PRINT"), "Report leaked lockfile source credentials")

  fail_command = ruby_command("exit 7")
  out, _, code = run_script("verify_upgrade.rb", "--check", "failed=#{fail_command}", "--check", "later=#{ruby_command('exit 0')}", app)
  failed = JSON.parse(out)
  assert(code == 1 && failed["status"] == "failed", "Nonzero status was lost")
  assert(failed["checks"].any? { |c| c["name"] == "failed" && c["exit_code"] == 7 }, "Original exit code was lost")
  assert(failed["checks"].any? { |c| c["name"] == "later" && c["status"] == "passed" }, "Independent checks did not continue")
  failed["checks"].first["name"] = "<img src=x>|**unsafe**"
  failed["status"] = "passed"
  File.write(evidence, JSON.generate(failed))
  report, _, code = run_script("upgrade_report.rb", baseline, evidence)
  assert(code == 0 && report.include?("**failed**"), "Report trusted a stale summary instead of check results")
  assert(report.include?("&lt;img src=x&gt;&#124;&#42;&#42;unsafe&#42;&#42;"), "Report failed to escape Markdown/HTML")

  out, _, code = run_script("verify_upgrade.rb", "--rails", "99.0.0", "--check", "tests=#{ruby_command('exit 0')}", app)
  assert(code == 1 && JSON.parse(out)["status"] == "failed", "Wrong target version passed")
  out, _, code = run_script("verify_upgrade.rb", "--check", "missing=rails-update-nonexistent-command", app)
  assert(code == 2 && JSON.parse(out)["checks"].any? { |c| c["status"] == "blocked" }, "Missing tool was not blocked")
  child_marker = File.join(tmp, "child-survived")
  slow = ruby_command('require "rbconfig"; spawn(RbConfig.ruby, "-e", "sleep 2; File.write(ARGV[0], :alive)", ARGV[0]); sleep 10', child_marker)
  out, _, code = run_script("verify_upgrade.rb", "--timeout", "1", "--check", "slow=#{slow}", app)
  assert(code == 1 && JSON.parse(out)["checks"].any? { |c| c["detail"].to_s.include?("Timed out") }, "Timeout was not recorded")
  sleep 1.3
  assert(!File.exist?(child_marker), "Timeout left a child process running")

  mutation = ruby_command('File.write("changed.rb", "change")')
  out, _, code = run_script("verify_upgrade.rb", "--check", "mutation=#{mutation}", app)
  assert(code == 1 && JSON.parse(out)["checks"].any? { |c| c["name"] == "source_unchanged_during_checks" && c["status"] == "failed" }, "Changed source was reported as verified")
  File.unlink(File.join(app, "changed.rb"))

  File.rename(File.join(app, "Gemfile.lock"), File.join(app, "gems.locked"))
  out, _, code = run_script("runtime_snapshot.rb", "--lockfile", "gems.locked", app)
  assert(code == 0 && JSON.parse(out).dig("declared", "rails_locked") == ["8.1.3"], "Explicit lockfile failed")
  out, _, code = run_script("verify_upgrade.rb", "--rails", "8.1.3", app)
  assert(code == 2 && JSON.parse(out)["checks"].any? { |c| c["name"] == "rails_target" && c["status"] == "blocked" }, "Missing lockfile was treated as valid")
  File.write(File.join(app, "Gemfile.lock"), "DEPENDENCIES\n    rails (99.0.0)\n")
  out, _, code = run_script("runtime_snapshot.rb", app)
  assert(code == 0 && JSON.parse(out).dig("declared", "rails_locked").empty?, "Dependency constraint was mistaken for a locked Rails spec")
  File.write(File.join(app, "Gemfile.lock"), "<<<<<<< conflict\n")
  _, err, code = run_script("runtime_snapshot.rb", app)
  assert(code == 2 && err.include?("merge conflicts"), "Conflicted lockfile was accepted")

  File.write(evidence, "{}")
  _, _, code = run_script("upgrade_report.rb", baseline, evidence)
  assert(code == 2, "Malformed evidence was accepted")
  File.write(evidence, JSON.generate(verified.merge("snapshot" => verified["snapshot"].merge("application" => "/another/app"))))
  _, _, code = run_script("upgrade_report.rb", baseline, evidence)
  assert(code == 2, "Different application baselines were accepted")
  outside = File.join(tmp, "without-git")
  FileUtils.mkdir_p(outside)
  out, _, code = run_script("verify_upgrade.rb", "--check", "tests=#{ruby_command('exit 0')}", outside)
  assert(code == 2 && JSON.parse(out)["status"] == "incomplete", "Missing source identity was treated as verified")
  puts "PASS: snapshot, selected checks, failure/timeout handling, source identity, and Markdown reports"
end
