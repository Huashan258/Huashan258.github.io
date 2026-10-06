# Preserve old article and category URLs when their canonical names change.
require "set"
require "uri"

module HuashanRedirects
  class Generator < Jekyll::Generator
    safe false
    priority :low

    def generate(site)
      documents = site.posts.docs + site.pages.dup
      occupied = (documents + site.static_files).map { |item| decode(item.url) }.to_set
      redirects = {}
      documents.each do |document|
        Array(document.data["redirect_from"]).each do |value|
          old_url = decode(value.to_s)
          unless old_url.start_with?("/") && !old_url.start_with?("//") &&
              !old_url.match?(/[?#\\]/) && (old_url.split("/") & [".", ".."]).empty?
            raise Jekyll::Errors::FatalException, "Redirect must use a local path: #{value}"
          end
          next if old_url == decode(document.url)
          if occupied.include?(old_url) || redirects.key?(old_url)
            raise Jekyll::Errors::FatalException, "Redirect would overwrite an existing URL: #{old_url}"
          end
          redirects[old_url] = document
        end
      end

      redirects.each do |old_url, document|
        page = Jekyll::PageWithoutAFile.new(site, site.source, "", "redirect.html")
        page.data.merge!(
          "layout" => "redirect", "title" => document.data["title"],
          "permalink" => old_url, "redirect_to" => document.url,
          "canonical_url" => site.config["url"].to_s.chomp("/") + site.config["baseurl"].to_s.chomp("/") + document.url,
          "sitemap" => false
        )
        site.pages << page
      end
    end

    private

    def decode(value)
      URI::DEFAULT_PARSER.unescape(value)
    end
  end
end
