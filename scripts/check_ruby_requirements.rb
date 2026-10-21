#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "rubygems"

module RubyRequirements
  module_function

  def check(specs, target)
    version = Gem::Version.new(target)
    specs.sort_by(&:name).map do |spec|
      { "name" => spec.name, "version" => spec.version.to_s,
        "required_ruby_version" => spec.required_ruby_version.to_s,
        "status" => spec.required_ruby_version.satisfied_by?(version) ? "passed" : "failed" }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    target = nil
    options = OptionParser.new do |parser|
      parser.banner = "Usage: ruby check_ruby_requirements.rb --target VERSION\nRun from the app on its CURRENT Ruby. Evaluates its Gemfile/gemspecs, without requiring Rails."
      parser.on("--target VERSION", "Candidate Ruby, e.g. 4.0.7; metadata check only") { |value| target = value }
      parser.on("-h", "--help") { puts parser; exit }
    end
    options.parse!
    unless ARGV.empty? && target.to_s.match?(/\A\d+\.\d+\.\d+(?:[.-][a-zA-Z0-9]+)*\z/)
      raise ArgumentError, options.banner
    end

    # Bundler and application gemspecs can print; keep the result stream JSON-only.
    output = $stdout
    result = nil
    begin
      $stdout = $stderr
      require "bundler"
      Bundler.settings.temporary(frozen: true, disable_version_check: true) do
        raise ArgumentError, "An existing lockfile is required; install the baseline bundle first" unless Bundler.default_lockfile.file?

        Bundler.definition.validate_runtime!
        checks = RubyRequirements.check(Bundler.load.specs, target)
        result = { "kind" => "rails-update-ruby-requirements", "format_version" => 1,
                   "scope" => "Current bundle/platform gem requirements only; not target runtime compatibility",
                   "gemfile" => Bundler.default_gemfile.to_s,
                   "running_ruby" => RUBY_VERSION, "target_ruby" => target,
                   "status" => checks.any? { |check| check["status"] == "failed" } ? "failed" : "passed",
                   "checks" => checks }
      end
    ensure
      $stdout = output
    end
    puts JSON.pretty_generate(result)
    exit(result.fetch("status") == "passed" ? 0 : 1)
  rescue LoadError, StandardError => error
    # Bundler errors can quote Gemfile source containing credentials.
    warn "Requirements check blocked (#{error.class}). Use --help; check the current Ruby, Bundler and installed locked bundle. Review diagnostics locally."
    exit 2
  end
end
