#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "json"
require "open3"
require "optparse"
require "time"

module RuntimeSnapshot
  module_function

  def git(root, *args)
    out, _, status = Open3.capture3("git", "--no-optional-locks", "-c", "core.fsmonitor=false", "-C", root, *args)
    status.success? ? out : nil
  rescue Errno::ENOENT
    nil
  end

  def git_state(root)
    return nil unless git(root, "rev-parse", "--show-toplevel")

    status = git(root, "status", "--porcelain=v1", "--untracked-files=all", "--", ".")
    changes = [git(root, "diff", "--no-ext-diff", "--no-textconv", "--binary", "--", "."),
               git(root, "diff", "--cached", "--no-ext-diff", "--no-textconv", "--binary", "--", ".")]
    untracked = git(root, "ls-files", "--others", "--exclude-standard", "-z", "--", ".")
    raise "Could not read Git working state" unless status && changes.all? && untracked

    untracked.split("\0").sort.each do |name|
      path = File.join(root, name)
      changes << name << (File.symlink?(path) ? File.readlink(path) : Digest::SHA256.file(path).hexdigest)
    end
    {
      "head" => git(root, "rev-parse", "--verify", "HEAD")&.strip,
      "branch" => git(root, "symbolic-ref", "--quiet", "--short", "HEAD")&.strip,
      "status" => status.encode("UTF-8", invalid: :replace, undef: :replace),
      "changes_sha256" => Digest::SHA256.hexdigest(changes.join("\0"))
    }
  end

  def capture(directory, lockfile = "Gemfile.lock")
    root = File.realpath(directory)
    raise ArgumentError, "Application path must be a directory" unless File.directory?(root)
    lock_path = File.expand_path(lockfile, root)
    text = File.file?(lock_path) ? File.read(lock_path, encoding: "UTF-8") : nil
    raise ArgumentError, "Lockfile must be valid UTF-8" if text && !text.valid_encoding?
    raise ArgumentError, "Resolve lockfile merge conflicts first" if text&.match?(/^(<<<<<<<|=======|>>>>>>>)/)

    # ponytail: metadata extraction only; Bundler must validate and resolve the complete lockfile.
    sections = {}
    section = nil
    rails = []
    specs = false
    text.to_s.each_line do |line|
      if line.match?(/\A[A-Z][A-Z ]*\r?\n?\z/)
        section = line.strip
        specs = false
        sections[section] ||= []
      elsif section && !line.strip.empty?
        sections[section] << line.strip
        specs = true if %w[GEM GIT PATH].include?(section) && line.strip == "specs:"
        match = line.match(/\A    rails \(([^)]+)\)\r?\n?\z/)
        rails << match[1] if specs && match
      end
    end
    ruby_file = File.join(root, ".ruby-version")
    declaration = File.file?(ruby_file) ? File.read(ruby_file).strip : nil
    # Do not print arbitrary file contents, Gemfile code, source URLs or environment dumps.
    declaration = "unrecognized" if declaration && !declaration.match?(/\A[a-zA-Z0-9._+-]+\z/)
    fingerprints = ["Gemfile", "gems.rb", ".ruby-version", ".tool-versions", "config/application.rb", lock_path].each_with_object({}) do |name, result|
      path = File.expand_path(name, root)
      result[path.delete_prefix(root + File::SEPARATOR)] = Digest::SHA256.file(path).hexdigest if File.file?(path)
    end
    {
      "kind" => "rails-update-snapshot", "format_version" => 1,
      "captured_at" => Time.now.utc.iso8601, "application" => root,
      "running" => { "ruby" => RUBY_VERSION, "engine" => RUBY_ENGINE,
                     "engine_version" => RUBY_ENGINE_VERSION, "patchlevel" => RUBY_PATCHLEVEL,
                     "platform" => RUBY_PLATFORM },
      "declared" => { "ruby_version_file" => declaration,
                      "ruby_locked" => sections.fetch("RUBY VERSION", []).first,
                      "bundler_locked" => sections.fetch("BUNDLED WITH", []).first,
                      "rails_locked" => rails.uniq.sort,
                      "platforms_locked" => sections.fetch("PLATFORMS", []).sort },
      "lockfile" => { "path" => lock_path, "present" => !text.nil? },
      "files_sha256" => fingerprints, "git" => git_state(root)
    }
  end

  def identity(snapshot)
    [snapshot.fetch("application"), snapshot.fetch("running"), snapshot.fetch("files_sha256"), snapshot["git"]]
  end

  def read(path)
    data = JSON.parse(File.read(path))
    unless data.is_a?(Hash) && data["format_version"] == 1
      raise ArgumentError, "Unsupported evidence format: #{path}"
    end
    data
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    lockfile = "Gemfile.lock"
    options = OptionParser.new do |parser|
      parser.banner = "Usage: ruby runtime_snapshot.rb [--lockfile PATH] [APP_DIRECTORY]"
      parser.on("--lockfile PATH", "Default: Gemfile.lock; use gems.locked when applicable") { |value| lockfile = value }
      parser.on("-h", "--help") { puts parser; exit }
    end
    options.parse!
    raise ArgumentError, options.banner if ARGV.size > 1
    puts JSON.pretty_generate(RuntimeSnapshot.capture(ARGV.fetch(0, Dir.pwd), lockfile))
  rescue StandardError => error
    warn "Snapshot failed: #{error.message}"
    exit 2
  end
end
