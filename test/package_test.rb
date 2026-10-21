# frozen_string_literal: true

require "yaml"
require "open3"
require "rbconfig"
require "uri"

root = File.expand_path("..", __dir__)
entrypoint = File.read(File.join(root, "SKILL.md"))
frontmatter = entrypoint.match(/\A---\r?\n(.*?)\r?\n---\r?\n/m)
raise "Missing skill frontmatter" unless frontmatter
metadata = YAML.safe_load(frontmatter[1])
raise "Incorrect skill name" unless metadata["name"] == "rails-update"
raise "Missing skill description" unless metadata["description"].is_a?(String) && !metadata["description"].strip.empty?
version = metadata.fetch("metadata", {})["version"]
raise "Missing stable semantic skill version" unless version.is_a?(String) && version.match?(/\A(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\z/)
changelog = File.read(File.join(root, "CHANGELOG.md"))
unless changelog.match?(/^## #{Regexp.escape(version)} — \d{4}-\d{2}-\d{2}$/)
  raise "Missing dated changelog entry for skill version #{version}"
end

links = 0
Dir.glob(File.join(root, "{*.md,references/*.md}")).each do |path|
  File.read(path).scan(/\[[^\]]*\]\(([^\s)]+)\)/).flatten.each do |target|
    next if target.start_with?("#") || target.match?(/\A[a-z][a-z0-9+.-]*:/i)

    relative = URI::DEFAULT_PARSER.unescape(target.split("#", 2).first)
    destination = File.expand_path(relative, File.dirname(path))
    raise "Link escapes package: #{path}: #{target}" unless destination.start_with?(root + File::SEPARATOR)
    raise "Broken local link: #{path}: #{target}" unless File.file?(destination)
    links += 1
  end
end

scripts = Dir.glob(File.join(root, "scripts/*.rb"))
raise "Missing helper scripts" if scripts.empty?
scripts.each do |script|
  out, err, status = Open3.capture3(RbConfig.ruby, script, "--help", chdir: __dir__)
  raise "Helper help failed: #{script}: #{err}" unless status.success? && out.include?("Usage:")
end

puts "PASS: skill #{version}, frontmatter, #{links} local file links and #{scripts.size} helper CLIs"
