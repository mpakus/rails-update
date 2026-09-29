#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "verify_upgrade"
require "cgi"

def cell(value)
  text = value.nil? ? "unknown" : (value.is_a?(Array) ? value.join(", ") : value.to_s)
  CGI.escapeHTML(text).gsub(/[`*_\\\[\]]/) { |char| "&##{char.ord};" }.gsub("|", "&#124;").gsub(/\r?\n/, "<br>")
end

begin
  if ARGV == ["--help"] || ARGV == ["-h"]
    puts "Usage: ruby upgrade_report.rb BEFORE.json VERIFICATION.json > report.md"
    exit
  end
  raise ArgumentError, "Expected BEFORE.json and VERIFICATION.json" unless ARGV.size == 2
  before = RuntimeSnapshot.read(ARGV[0])
  verification = RuntimeSnapshot.read(ARGV[1])
  after = verification.fetch("snapshot")
  unless before["kind"] == "rails-update-snapshot" && verification["kind"] == "rails-update-verification" && after["kind"] == "rails-update-snapshot"
    raise ArgumentError, "Expected snapshot and verification evidence"
  end
  raise ArgumentError, "Snapshots describe different application paths" unless before.fetch("application") == after.fetch("application")
  checks = verification.fetch("checks")
  unless checks.is_a?(Array) && checks.all? { |check| check.is_a?(Hash) && %w[passed failed blocked not_run].include?(check["status"]) && %w[static command].include?(check["kind"]) }
    raise ArgumentError, "Invalid check results"
  end
  status = UpgradeVerification.outcome(checks)
  lines = ["# Ruby/Rails upgrade report", "", "Selected checks: **#{status}**. This is not deployment approval.", "",
           "Application: #{cell(after.fetch('application'))}", "",
           "Evidence: #{cell(before.fetch('captured_at'))} → #{cell(verification.fetch('finished_at'))}", "",
           "## Runtime and source", "", "| Item | Before | After |", "| --- | --- | --- |"]
  {
    "Git revision" => [before.dig("git", "head"), after.dig("git", "head")],
    "Working changes fingerprint" => [before.dig("git", "changes_sha256"), after.dig("git", "changes_sha256")],
    "Running Ruby" => [before.dig("running", "ruby"), after.dig("running", "ruby")],
    "Ruby engine" => [before.dig("running", "engine"), after.dig("running", "engine")],
    "Platform" => [before.dig("running", "platform"), after.dig("running", "platform")],
    "Declared Ruby (.ruby-version)" => [before.dig("declared", "ruby_version_file"), after.dig("declared", "ruby_version_file")],
    "Locked Ruby" => [before.dig("declared", "ruby_locked"), after.dig("declared", "ruby_locked")],
    "Locked Rails" => [before.dig("declared", "rails_locked"), after.dig("declared", "rails_locked")],
    "Locked Bundler" => [before.dig("declared", "bundler_locked"), after.dig("declared", "bundler_locked")],
    "Locked platforms" => [before.dig("declared", "platforms_locked"), after.dig("declared", "platforms_locked")]
  }.each { |name, values| lines << "| #{name} | #{cell(values[0])} | #{cell(values[1])} |" }
  lines.concat(["", "## Checks", "", "| Check | Status | Exit | Seconds | Command / detail |", "| --- | --- | --- | --- | --- |"])
  checks.each do |check|
    detail = [check["command"] && Shellwords.join(check["command"]), check["detail"]].compact.join(" — ")
    lines << "| #{cell(check.fetch('name'))} | #{cell(check['status'])} | #{cell(check['exit_code'])} | #{cell(check['seconds'])} | #{cell(detail)} |"
  end
  lines.concat(["", "## Remaining evidence", "",
                "Only the selected commands were executed; exit codes do not establish test counts or coverage.",
                "Review logs and separately record full-suite/CI results, browser/API behavior, authentication/tenancy,",
                "jobs, reports/native tools, database fidelity, production images, and release/rollback acceptance.",
                "Unlisted gates are unverified. This report describes saved evidence; later changes invalidate affected results."])
  puts lines.join("\n")
rescue StandardError => error
  warn "Report failed: #{error.message}"
  exit 2
end
