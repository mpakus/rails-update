# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "open3"
require "rbconfig"
require "shellwords"
require "bundler"
require_relative "../scripts/check_ruby_requirements"

def assert(condition, message)
  raise message unless condition
end

def specification(name, *requirements)
  Gem::Specification.new do |spec|
    spec.name = name
    spec.version = "1.0.0"
    spec.required_ruby_version = Gem::Requirement.new(*requirements)
  end
end

specs = [specification("bounded", ">= 3.4", "< 4.1"),
         specification("pessimistic", "~> 3.4"),
         specification("excluded", ">= 2.7", "!= 4.0.3"),
         specification("future", ">= 4.1"),
         specification("exact", "= 4.0.3"),
         specification("patch", "~> 4.0.2")]
checks = RubyRequirements.check(specs, "4.0.3")
assert(checks.select { |check| check["status"] == "failed" }.map { |check| check["name"] } == %w[excluded future pessimistic],
       "Semantic version requirements were misclassified")
assert(RubyRequirements.check([specification("release", ">= 4.0.0")], "4.0.0.preview1").first["status"] == "failed",
       "Prerelease incorrectly satisfied release minimum")

script = File.expand_path("../scripts/check_ruby_requirements.rb", __dir__)
Dir.mktmpdir("ruby-requirements-") do |tmp|
  gem_dir = File.join(tmp, "fixture")
  FileUtils.mkdir_p(File.join(gem_dir, "lib"))
  File.write(File.join(gem_dir, "lib/fixture.rb"), 'raise "Gem runtime must not be required"')
  gemspec = File.join(gem_dir, "fixture.gemspec")
  File.write(gemspec, <<~RUBY)
    Gem::Specification.new do |spec|
      spec.name = "fixture"
      spec.version = "1.0.0"
      spec.summary = "Local test gem"
      spec.authors = ["Test"]
      spec.files = ["lib/fixture.rb"]
      spec.required_ruby_version = ">= 2.7", "< 99"
    end
  RUBY
  File.write(File.join(tmp, "Gemfile"), <<~RUBY)
    puts "GEMFILE_LOG"
    gem "fixture", path: "fixture"
  RUBY
  lockfile = File.join(tmp, "Gemfile.lock")
  lock = <<~LOCK
    PATH
      remote: fixture
      specs:
        fixture (1.0.0)

    GEM
      specs:

    PLATFORMS
      ruby
      #{Gem::Platform.local}

    DEPENDENCIES
      fixture!

    BUNDLED WITH
       #{Bundler::VERSION}
  LOCK
  File.write(lockfile, lock)
  env = ENV.keys.grep(/\ABUNDLE_/).to_h { |key| [key, nil] }
  env.merge!("RUBYOPT" => nil, "BUNDLE_IGNORE_CONFIG" => "1", "BUNDLE_USER_HOME" => File.join(tmp, "bundle-home"))
  run = ->(*args) { Open3.capture3(env, RbConfig.ruby, script, *args, chdir: tmp) }

  out, err, status = run.call("--target", RUBY_VERSION)
  assert(status.success? && JSON.parse(out)["status"] == "passed", "Real frozen bundle check failed: #{err}")
  assert(err.include?("GEMFILE_LOG") && !out.include?("GEMFILE_LOG"), "Gemfile output polluted JSON")
  assert(JSON.parse(out)["checks"].any? { |check| check["name"] == "fixture" }, "Path gem was omitted")
  assert(File.read(lockfile) == lock, "Checker changed lockfile")

  out, _, status = run.call("--target", "99.0.0")
  assert(status.exitstatus == 1 && JSON.parse(out)["checks"].any? { |check| check["name"] == "fixture" && check["status"] == "failed" },
         "Incompatible gem did not fail")
  command = Shellwords.join([RbConfig.ruby, script, "--target", "99.0.0"])
  verifier = File.expand_path("../scripts/verify_upgrade.rb", __dir__)
  out, _, status = Open3.capture3(env, RbConfig.ruby, verifier, "--check", "requirements=#{command}", tmp, chdir: tmp)
  selected = JSON.parse(out)["checks"].find { |check| check["name"] == "requirements" }
  assert(status.exitstatus == 1 && selected["status"] == "failed" && selected["exit_code"] == 1,
         "Verifier lost requirement checker failure")
  _, _, status = run.call("--target", "latest")
  assert(status.exitstatus == 2, "Non-version target was accepted")

  File.open(File.join(tmp, "Gemfile"), "a") { |file| file.puts 'gem "not_in_the_lockfile"' }
  out, _, status = run.call("--target", RUBY_VERSION)
  assert(status.exitstatus == 2 && out.empty? && File.read(lockfile) == lock, "Stale lockfile was resolved or passed")
  File.write(File.join(tmp, "Gemfile"), 'gem "fixture", path: "fixture"')
  File.unlink(gemspec)
  out, _, status = run.call("--target", RUBY_VERSION)
  assert(status.exitstatus == 2 && out.empty? && File.read(lockfile) == lock, "Unavailable locked gem was passed")
  File.unlink(lockfile)
  out, _, status = run.call("--target", RUBY_VERSION)
  assert(status.exitstatus == 2 && out.empty? && !File.exist?(lockfile), "Missing lockfile was generated or passed")
end

puts "PASS: Ruby requirements, real frozen bundle, no autorequire, JSON output and incomplete evidence"
