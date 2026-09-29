#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "runtime_snapshot"
require "shellwords"
require "timeout"

module UpgradeVerification
  module_function

  def outcome(checks)
    return "failed" if checks.any? { |check| check["status"] == "failed" }
    return "incomplete" if checks.empty? || checks.any? { |check| %w[blocked not_run].include?(check["status"]) }
    return "incomplete" unless checks.any? { |check| check["kind"] == "command" }

    "passed"
  end

  def command(root, name, argv, timeout)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = { "name" => name, "kind" => "command", "command" => argv }
    pid = nil
    begin
      # An argv array avoids shell expansion, including when the executable is the only argument.
      pid = Process.spawn([argv.first, argv.first], *argv.drop(1), chdir: root,
                          in: File::NULL, out: $stderr, err: $stderr, pgroup: true)
      _, status = Timeout.timeout(timeout) { Process.wait2(pid) }
      pid = nil
      result.merge!("status" => status.success? ? "passed" : "failed",
                    "exit_code" => status.exitstatus, "signal" => status.termsig)
      result["detail"] = "Terminated by signal #{status.termsig}" if status.signaled?
    rescue Timeout::Error
      result.merge!("status" => "failed", "detail" => "Timed out after #{timeout} seconds")
    rescue SystemCallError => error
      result.merge!("status" => "blocked", "detail" => error.class.name)
    ensure
      if pid
        begin
          Process.kill("KILL", -pid)
        rescue Errno::ESRCH
          # The command may have exited between the timeout and cleanup.
        end
        begin
          Process.wait(pid)
        rescue Errno::ECHILD
          # wait2 already reaped the process.
        end
      end
      result["seconds"] = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).round(3)
    end
    result
  end

  def run(root, lockfile, targets, commands, timeout)
    before = RuntimeSnapshot.capture(root, lockfile)
    checks = []
    declaration = before.dig("declared", "ruby_version_file")
    if declaration
      version = declaration.sub(/\Aruby-/, "")
      status = version.match?(/\A\d+\.\d+\.\d+\z/) ? (version == RUBY_VERSION ? "passed" : "failed") : "not_run"
      checks << { "name" => "ruby_version_file", "kind" => "static", "status" => status,
                  "detail" => status == "not_run" ? "Non-exact Ruby declaration requires manual review" : "Declared #{version}; running #{RUBY_VERSION}" }
    end
    targets.each do |target, expected|
      actual = target == "ruby" ? [before.dig("running", "ruby")] : before.dig("declared", "rails_locked")
      checks << { "name" => "#{target}_target", "kind" => "static",
                  "status" => actual.empty? ? "blocked" : (actual == [expected] ? "passed" : "failed"),
                  "detail" => "Expected #{expected}; #{target == 'ruby' ? 'running' : 'locked'} #{actual.join(', ')}" }
    end
    commands.each { |name, argv| checks << command(before.fetch("application"), name, argv, timeout) }
    after = RuntimeSnapshot.capture(root, lockfile)
    unchanged = RuntimeSnapshot.identity(before) == RuntimeSnapshot.identity(after)
    checks << { "name" => "source_unchanged_during_checks", "kind" => "static",
                "status" => unchanged ? "passed" : "failed",
                "detail" => unchanged ? "Recorded source identity unchanged" : "Source changed; rerun checks on the final state" }
    checks << { "name" => "application_checks", "kind" => "command", "status" => "not_run",
                "detail" => "No --check commands were supplied" } if commands.empty?
    unless before["git"]
      checks << { "name" => "source_identity", "kind" => "static", "status" => "blocked",
                  "detail" => "Git unavailable; selected file hashes cannot identify the whole application" }
    end
    { "kind" => "rails-update-verification", "format_version" => 1,
      "scope" => "Selected checks only; not deployment approval", "status" => outcome(checks),
      "started_at" => before.fetch("captured_at"), "finished_at" => after.fetch("captured_at"),
      "snapshot" => after, "checks" => checks }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    lockfile = "Gemfile.lock"
    timeout = 600
    targets = {}
    commands = []
    options = OptionParser.new do |parser|
      parser.banner = "Usage: ruby verify_upgrade.rb [options] [APP_DIRECTORY]\nNo application commands run unless selected with --check."
      parser.on("--lockfile PATH") { |value| lockfile = value }
      parser.on("--ruby VERSION", "Expected running Ruby version") { |value| targets["ruby"] = value }
      parser.on("--rails VERSION", "Expected locked Rails version, not boot verification") { |value| targets["rails"] = value }
      parser.on("--timeout SECONDS", Integer, "Per-command timeout (default 600)") { |value| timeout = value }
      parser.on("--check NAME=COMMAND", "Repeat for each reviewed command; no shell expansion") do |value|
        name, command = value.split("=", 2)
        raise ArgumentError, "Use a unique check name and a nonempty command" if name.to_s.empty? || command.to_s.strip.empty? || commands.any? { |entry| entry.first == name }
        argv = Shellwords.split(command)
        raise ArgumentError, "Empty executable" if argv.first.to_s.empty?
        commands << [name, argv]
      end
      parser.on("-h", "--help") { puts parser; exit }
    end
    options.parse!
    raise ArgumentError, options.banner if ARGV.size > 1 || timeout <= 0
    result = UpgradeVerification.run(ARGV.fetch(0, Dir.pwd), lockfile, targets, commands, timeout)
    puts JSON.pretty_generate(result)
    exit({ "passed" => 0, "failed" => 1, "incomplete" => 2 }.fetch(result.fetch("status")))
  rescue StandardError => error
    warn "Verification failed: #{error.message}"
    exit 2
  end
end
