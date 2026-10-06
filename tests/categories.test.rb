# Test custom-image rendering and new categories with real Jekyll reads.
require "jekyll"
require "tmpdir"
require "fileutils"
require_relative "../_plugins/categories"

ROOT = File.expand_path("..", __dir__)

def check(condition, message)
  raise message unless condition
end

Dir.mktmpdir("huashan-category-checks-") do |temporary|
  site = Jekyll::Site.new(Jekyll.configuration(
    "source" => ROOT, "destination" => File.join(temporary, "rendered"),
    "avatar" => "/assets/images/favicon.svg", "quiet" => true
  ))
  site.read
  site.data["categories"]["胶粘剂"]["image"] = "/assets/images/background.webp"
  site.data["categories"]["数据分析"]["image"] = "/assets/images/does-not-exist.png"
  site.generate
  site.render
  site.write
  home = File.read(File.join(site.dest, "index.html"))
  overview = File.read(File.join(site.dest, "categories", "index.html"))
  check(home.include?('class="brand-avatar" src="/assets/images/favicon.svg"'), "Configured avatar was not rendered")
  check(overview.include?('class="category-cover"'), "Configured category cover was not rendered")
  check(!overview.include?("does-not-exist.png"), "Missing cover should keep the default card")
  check(HuashanCategories.optional_image(site, "").nil?, "Empty avatar should keep the default mark")
  check(HuashanCategories.optional_image(site, "/assets/images/missing-avatar.png").nil?, "Missing avatar should keep the default mark")
  check(HuashanCategories.optional_image(site, "https://example.com/avatar.png").nil?, "Optional images must use a local asset")

  source = File.join(temporary, "fixture")
  FileUtils.mkdir_p(File.join(source, "_posts"))
  FileUtils.mkdir_p(File.join(source, "_data"))
  FileUtils.cp(File.join(ROOT, "_data", "topics.yml"), File.join(source, "_data"))
  fixtures = [
    ["2025-01-01-first.md", "胶粘剂概论", "2025-01-01 12:00:00 +0000", "胶粘剂", ""],
    ["2025-02-01-second.md", "第二篇", "2025-02-01 12:00:00 +0000", "胶粘剂", ""],
    ["2025-03-01-new.md", "新主题文章", "2025-03-01 12:00:00 +0000", "新主题", ""],
    ["2025-04-01-hidden.md", "测试", "2025-04-01 12:00:00 +0000", "隐藏主题", "listed: false\n"],
    ["2099-01-01-future.md", "未来文章", "2099-01-01 12:00:00 +0000", "未来主题", ""],
  ]
  fixtures.each do |file, title, date, category, extra|
    File.write(File.join(source, "_posts", file), "---\ntitle: #{title}\ndate: #{date}\ncategories: #{category}\n#{extra}---\n文章正文。\n")
  end
  fixture_site = Jekyll::Site.new(Jekyll.configuration(
    "source" => source, "destination" => File.join(temporary, "fixture-site"), "quiet" => true
  ))
  fixture_site.read
  HuashanCategories::Generator.new.generate(fixture_site)
  catalog = fixture_site.data["category_catalog"]
  check(catalog.keys.sort == ["新主题", "胶粘剂"], "Hidden and future articles must not create categories")
  check(catalog["新主题"]["group_id"] == "other", "New categories must appear under 其他记录")
  check(%w[study tools games life].all? { |id| fixture_site.data["category_groups"].any? { |group| group["id"] == id } }, "Empty topic sections must retain working sidebar anchors")
  page = fixture_site.pages.find { |item| item.data["title"] == "胶粘剂" }
  check(page.data["category_posts"].map { |post| post.data["title"] } == ["胶粘剂概论", "第二篇"], "Category articles must be oldest first")
end
puts "PASS: custom avatar, category cover, missing-image defaults, automatic categories and hidden/future articles."
