# Test custom-image rendering and new categories with real Jekyll reads.
require "jekyll"
require "tmpdir"
require "fileutils"
require_relative "../_plugins/categories"
require_relative "../_plugins/redirects"

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
  # Inject test data in memory. The user's optional cover configuration may
  # omit either category, so the test must not edit its nested values.
  site.data["categories"] = {
    "胶黏剂" => { "image" => "/assets/images/background.webp", "aliases" => ["胶粘剂"] },
    "数据分析" => { "image" => "/assets/images/does-not-exist.png" },
  }
  site.generate
  site.render
  site.write
  home = File.read(File.join(site.dest, "index.html"))
  overview = File.read(File.join(site.dest, "categories", "index.html"))
  check(home.include?('class="brand-avatar" src="/assets/images/favicon.svg"'), "Configured avatar was not rendered")
  check(overview.include?('class="category-cover"') && overview.include?('src="/assets/images/background.webp"'), "Configured category cover was not rendered")
  check(!overview.include?("does-not-exist.png"), "Missing cover should keep the default card")
  check(overview.include?('id="category-胶粘剂"'), "Old category bookmark must keep working")
  check(URI::DEFAULT_PARSER.unescape(overview).include?('href="/categories/胶黏剂/"'), "Category cards must link to the canonical name")
  adhesives = site.posts.docs.select { |post| post.data["categories"].include?("胶黏剂") }
  check(adhesives.size == 20, "All adhesive articles must share the canonical category")
  aliases = site.pages.select { |page| page.data["redirect_to"] }
  check(aliases.size == adhesives.size + 1, "Old article and category URLs must all be preserved")
  adhesives.each do |post|
    old_url = post.data.fetch("redirect_from").first
    redirect = aliases.find { |page| URI::DEFAULT_PARSER.unescape(page.url) == old_url }
    check(redirect && redirect.data["redirect_to"] == post.url, "Old article URL must reach its matching article")
    html = File.read(redirect.destination(site.dest))
    check(html.include?('name="robots" content="noindex, follow"'), "Alias pages must not compete in search engines")
    check(URI::DEFAULT_PARSER.unescape(html).include?(%(content="0;url=#{URI::DEFAULT_PARSER.unescape(post.url)}")), "Alias pages must refresh to the canonical article")
  end
  category_alias = aliases.find { |page| URI::DEFAULT_PARSER.unescape(page.url) == "/categories/胶粘剂/" }
  check(category_alias && URI::DEFAULT_PARSER.unescape(category_alias.data["redirect_to"]) == "/categories/胶黏剂/", "Old category URL must reach the renamed category")
  check(HuashanCategories.optional_image(site, "").nil?, "Empty avatar should keep the default mark")
  check(HuashanCategories.optional_image(site, "/assets/images/missing-avatar.png").nil?, "Missing avatar should keep the default mark")
  check(HuashanCategories.optional_image(site, "https://example.com/avatar.png").nil?, "Optional images must use a local asset")

  source = File.join(temporary, "fixture")
  FileUtils.mkdir_p(File.join(source, "_posts"))
  FileUtils.mkdir_p(File.join(source, "_data"))
  FileUtils.cp(File.join(ROOT, "_data", "topics.yml"), File.join(source, "_data"))
  fixtures = [
    ["2025-01-01-first.md", "胶黏剂概论", "2025-01-01 12:00:00 +0000", "胶黏剂", ""],
    ["2025-02-01-second.md", "第二篇", "2025-02-01 12:00:00 +0000", "胶黏剂", ""],
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
  # A differently named key and a blank YAML entry must both keep defaults.
  fixture_site.data["categories"] = { "无关分类" => {}, "新主题" => nil }
  HuashanCategories::Generator.new.generate(fixture_site)
  catalog = fixture_site.data["category_catalog"]
  check(catalog.keys.sort == ["新主题", "胶黏剂"], "Hidden and future articles must not create categories")
  check(catalog["新主题"]["group_id"] == "other", "New categories must appear under 其他记录")
  check(catalog["胶黏剂"]["image"].nil?, "A category omitted from cover settings must keep the default card")
  check(catalog["新主题"]["image"].nil?, "An empty cover setting must keep the default card")
  check(%w[study tools games life].all? { |id| fixture_site.data["category_groups"].any? { |group| group["id"] == id } }, "Empty topic sections must retain working sidebar anchors")
  page = fixture_site.pages.find { |item| item.data["title"] == "胶黏剂" }
  check(page.data["category_posts"].map { |post| post.data["title"] } == ["胶黏剂概论", "第二篇"], "Category articles must be oldest first")
  # A mistyped alias must fail rather than overwrite an existing page.
  fixture_site.posts.docs.first.data["redirect_from"] = ["/categories/胶黏剂/"]
  begin
    HuashanRedirects::Generator.new.generate(fixture_site)
    raise "Conflicting alias silently overwrote an existing URL"
  rescue Jekyll::Errors::FatalException => error
    check(error.message.include?("overwrite"), "A conflicting alias must explain the existing URL")
  end
end
puts "PASS: custom avatar, category cover, defaults, automatic categories, old URL redirects and hidden/future articles."
