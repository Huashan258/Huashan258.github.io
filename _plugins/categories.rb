# Build category landing pages from the same visible posts used by search.
require "digest"
require "uri"

module HuashanCategories
  def self.optional_image(site, value)
    path = value.to_s.strip
    return nil if path.empty?

    decoded = URI::DEFAULT_PARSER.unescape(path)
    source = File.expand_path(decoded.delete_prefix("/"), site.source)
    image = decoded.start_with?("/assets/images/") &&
      source.start_with?(File.join(site.source, "assets", "images") + File::SEPARATOR) &&
      decoded.match?(/\.(?:avif|gif|jpe?g|png|svg|webp)\z/i) && File.file?(source)
    return path if image

    Jekyll.logger.warn("Optional image:", "#{path} is unavailable; keeping the default appearance.")
    nil
  end

  class Generator < Jekyll::Generator
    safe false
    priority :normal

    def generate(site)
      site.data["brand_avatar"] = HuashanCategories.optional_image(site, site.config["avatar"])
      visible_posts = site.posts.docs.reject { |post| post.data["listed"] == false }
      topics = site.data["topics"] || []
      settings = site.data["categories"] || {}
      by_category = {}
      visible_posts.each do |post|
        post.data["categories"].each do |name|
          (by_category[name] ||= []) << post
        end
      end

      catalog = {}
      used_slugs = []
      by_category.keys.sort.each do |name|
        posts = by_category[name].sort_by { |post| [post.date, post.relative_path] }
        options = settings[name] || {}
        group = topics.find { |topic| topic["categories"].include?(name) }
        slug = Jekyll::Utils.slugify(name, :mode => "default")
        slug = "#{slug}-#{Digest::SHA256.hexdigest(name)[0, 8]}" if slug.empty? || used_slugs.include?(slug)
        used_slugs << slug
        url = "/categories/#{slug}/"
        description = options["description"].to_s.strip
        image = HuashanCategories.optional_image(site, options["image"])
        entry = {
          "name" => name, "url" => url, "count" => posts.size,
          "description" => description, "image" => image,
          "symbol" => group ? group["symbol"] : "记",
          "group_id" => group ? group["id"] : "other",
          "group_name" => group ? group["name"] : "其他记录",
          "first_date" => posts.first.date, "last_date" => posts.last.date,
        }
        catalog[name] = entry
        page = Jekyll::PageWithoutAFile.new(site, site.source, "categories/#{slug}", "index.html")
        page.data.merge!(
          "layout" => "category", "title" => name, "permalink" => url,
          "description" => description.empty? ? "#{name}分类的全部#{posts.size}篇文章，按发表时间从早到晚排列。" : description,
          "category_info" => entry, "category_posts" => posts,
          "last_modified_at" => posts.last.date
        )
        page.data["image"] = image if image
        site.pages << page
      end

      groups = topics.map do |group|
        entries = group["categories"].filter_map { |name| catalog[name] }
        group.merge("entries" => entries)
      end
      other = catalog.values.select { |entry| entry["group_id"] == "other" }
      unless other.empty?
        groups << { "id" => "other", "name" => "其他记录", "description" => "新主题也会自动出现在这里", "entries" => other }
      end
      site.data["category_catalog"] = catalog
      site.data["category_groups"] = groups
    end
  end
end
