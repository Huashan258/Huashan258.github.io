# Keep article Markdown intact while improving its generated HTML.
require "cgi"
require "uri"

module HuashanReadability
  def self.text(html)
    CGI.unescapeHTML(html.gsub(/<[^>]*>/, "")).gsub(/\s+/, " ").strip
  end

  def self.normalize_title(value)
    text(value.to_s).gsub(/[\s*#_]/, "")
  end

  def self.prepare(document)
    return unless document.collection.label == "posts"

    body = document.content.gsub(/```.*?```/m, "")
    document.data["math"] = body.include?("latex.codecogs.com") || body.match?(/\$\$|\$[^\s$].*?\$|\\\(|\\\[/m)
    characters = text(document.content).length
    document.data["reading_minutes"] = [(characters / 500.0).ceil, 1].max
    unless document.data["description"]
      paragraph = body.split(/\n\s*\n/).find do |part|
        !part.strip.empty? && !part.strip.match?(/\A(?:\#{1,6}\s|[-*]\s|>\s|!\[|<|```|\|)/)
      end
      description = text(paragraph.to_s).gsub(/!\[[^\]]*\]\([^)]*\)/, "").gsub(/\[([^\]]+)\]\([^)]*\)/, '\1').gsub(/[\*`]/, "")
      document.data["description"] = description.empty? ? "#{document.data['title']}，华扇的学习笔记与生活记录。" : description[0, 150]
    end
  end

  def self.improve(document)
    return unless document.collection.label == "posts"

    html = document.content
    title = normalize_title(document.data["title"])
    html = html.gsub(/<h1\b[^>]*>.*?<\/h1>/m) do |heading|
      normalize_title(heading) == title ? "" : heading
    end
    # Existing posts sometimes use h1 for their sections. The page title owns h1.
    if html.match?(/<h1\b/)
      html = html.gsub(/<(\/?)(h)([1-6])\b/) { "<#{$1}h#{[$3.to_i + 1, 6].min}" }
    end
    dimensions = document.site.data["image_dimensions"] || {}
    image_index = 0
    html = html.gsub(/<img\b[^>]*>/i) do |tag|
      source = tag[/\bsrc=["']([^"']+)["']/i, 1]
      next tag unless source
      source = CGI.unescapeHTML(source)
      if source.match?(%r{\Ahttps://latex\.codecogs\.com/})
        # Percent decoding preserves literal '+' used in equations.
        tex = URI::DEFAULT_PARSER.unescape(source.split("?", 2)[1].to_s)
        escaped = CGI.escapeHTML(tex)
        next %(<span class="math-inline" data-math="#{escaped}"><code>#{escaped}</code></span>)
      end
      path = URI::DEFAULT_PARSER.unescape(source.split(/[?#]/, 2).first)
      size = dimensions[path]
      attributes = ""
      if size
        attributes += %( width="#{size[0]}") unless tag.match?(/\bwidth=/i)
        attributes += %( height="#{size[1]}") unless tag.match?(/\bheight=/i)
      end
      attributes += %( decoding="async") unless tag.match?(/\bdecoding=/i)
      attributes += %( loading="#{image_index.zero? ? 'eager' : 'lazy'}") unless tag.match?(/\bloading=/i)
      image_index += 1
      tag.sub(/\s*\/?\s*>\z/, "#{attributes} />")
    end
    html = html.gsub(/<p>\s*(<span class="math-inline" data-math="[^"]*">.*?<\/span>)\s*<\/p>/m) do
      "<p>#{$1.sub('class="math-inline"', 'class="math-block"')}</p>"
    end
    document.content = html
  end
end

Jekyll::Hooks.register :documents, :pre_render do |document|
  HuashanReadability.prepare(document)
end
Jekyll::Hooks.register :documents, :post_convert do |document|
  HuashanReadability.improve(document)
end
