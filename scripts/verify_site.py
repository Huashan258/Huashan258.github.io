"""Validate generated pages and preserved URLs; uses only Python's standard library."""
from collections import Counter
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit
import json
import re
import sys
import xml.etree.ElementTree as ET
from verify_categories import verify as verify_categories

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "_site"
ORIGIN = "https://huashan258.github.io"
errors = []


def check(condition, message):
    if not condition:
        errors.append(message)


class Page(HTMLParser):
    def __init__(self, content):
        super().__init__(convert_charrefs=True)
        self.ids = []
        self.links = []
        self.images = []
        self.scripts = []
        self.styles = []
        self.visible_text = []
        self.skip_text = False
        self.h1 = 0
        self.lang = None
        self.canonical = None
        self.locale = None
        self.redirect = None
        self.robots = ""
        self.formulas = []
        self.cards = 0
        self.feed_content = content
        self.feed(content)

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag in ("script", "style"):
            self.skip_text = True
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if tag == "html":
            self.lang = attrs.get("lang")
        if tag == "h1":
            self.h1 += 1
        if tag == "a":
            self.links.append(attrs.get("href", ""))
        if tag == "img":
            self.images.append(attrs)
        if tag == "script" and attrs.get("src"):
            self.scripts.append(attrs["src"])
        if "data-math" in attrs:
            self.formulas.append(attrs["data-math"])
        if tag == "meta" and attrs.get("property") == "og:locale":
            self.locale = attrs.get("content")
        if tag == "meta" and attrs.get("name") == "robots":
            self.robots = attrs.get("content", "")
        if tag == "meta" and attrs.get("http-equiv", "").lower() == "refresh":
            match = re.fullmatch(r"0;url=(/.+)", attrs.get("content", ""))
            self.redirect = match.group(1) if match else None
            check(self.redirect is not None, "Redirect must refresh immediately to a local URL")
        if tag == "link":
            rel = attrs.get("rel", "")
            if rel == "canonical":
                self.canonical = attrs.get("href")
            if rel == "stylesheet":
                self.styles.append(attrs.get("href", ""))
        if "article-card" in attrs.get("class", "").split():
            self.cards += 1

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.skip_text = False

    def handle_data(self, data):
        if not self.skip_text:
            self.visible_text.append(data)


def target_path(url):
    path = unquote(urlsplit(url).path)
    return SITE / (path.lstrip("/") + ("index.html" if path.endswith("/") else ""))


pages = {}
for file in SITE.rglob("*.html"):
    content = file.read_text(encoding="utf-8")
    page = Page(content)
    pages[file.resolve()] = page
    relative = file.relative_to(SITE).as_posix()
    url = "/" + (relative[:-10] if relative.endswith("index.html") else relative)
    check(page.lang == "zh-CN", f"Wrong language: {relative}")
    check(page.h1 == 1, f"Expected one h1: {relative} ({page.h1})")
    check(page.canonical and page.canonical.startswith(ORIGIN), f"Missing absolute canonical: {relative}")
    canonical_path = unquote(urlsplit(page.canonical or "").path)
    if page.redirect:
        check(page.redirect.startswith("/") and not page.redirect.startswith("//"), f"External redirect: {relative}")
        check(canonical_path == unquote(urlsplit(page.redirect).path), f"Redirect canonical is wrong: {relative}")
        check("noindex" in page.robots, f"Redirect must stay out of search engines: {relative}")
    else:
        check(canonical_path == url, f"Canonical path changed: {relative}")
    check(page.locale == "zh_CN", f"Wrong Open Graph locale: {relative}")
    check("胶粘剂" not in "".join(page.visible_text), f"Old terminology remains on page: {relative}")
    check(len(page.ids) == len(set(page.ids)), f"Duplicate heading IDs: {relative}")
    for image in page.images:
        check(image.get("width") and image.get("height"), f"Missing image size: {relative} {image.get('src')}")
        check(image.get("decoding") == "async", f"Missing async image decoding: {relative}")
        check(image.get("loading") in ("eager", "lazy"), f"Missing image loading: {relative}")
        check("latex.codecogs.com" not in image.get("src", ""), f"Remote formula remains: {relative}")
    for resource in page.scripts + page.styles:
        check(resource.startswith("/"), f"Unexpected external script/style: {relative} {resource}")
        check(target_path(resource).is_file(), f"Missing script/style: {relative} {resource}")

for file, page in pages.items():
    relative = file.relative_to(SITE).as_posix()
    if page.redirect:
        target = pages.get(target_path(page.redirect).resolve())
        check(target is not None and target.redirect is None, f"Redirect target missing or chained: {relative}")
    base = ORIGIN + "/" + relative
    for link in page.links + [image.get("src", "") for image in page.images]:
        if not link or link.startswith(("mailto:", "tel:")):
            continue
        url = urlsplit(urljoin(base, link))
        if url.netloc != urlsplit(ORIGIN).netloc:
            continue
        target = target_path(url.geturl()).resolve()
        check(target.is_file(), f"Broken local link: {relative} -> {link}")
        if url.fragment and target in pages:
            check(unquote(url.fragment) in pages[target].ids, f"Broken anchor: {relative} -> {link}")

baseline = json.loads((ROOT / "baseline-urls.json").read_text(encoding="utf-8"))
for url in baseline:
    check(target_path(url).is_file(), f"Old post URL missing: {url}")

documents = json.loads((SITE / "assets/search.json").read_text(encoding="utf-8"))
listed = []
for file in (ROOT / "_posts").glob("*"):
    header = file.read_text(encoding="utf-8").split("---", 2)[1]
    if re.search(r"^(?:listed|published):\s*false\s*$", header, re.M):
        continue
    date = re.search(r"^date:\s*[\"']?(\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}\s*[+-]\d{4})", header, re.M)
    if date:
        value = date.group(1).replace("T", " ")
        published_at = datetime.strptime(value, "%Y-%m-%d %H:%M:%S %z")
        if published_at > datetime.now(timezone.utc):
            continue
    listed.append(file)
check(len(documents) == len(listed), "Some listed posts are missing from search")
check(len({item["url"] for item in documents}) == len(documents), "Duplicate search URLs")
check(all(item["content"] for item in documents), "Empty article content in search")
for item in documents:
    check(target_path(item["url"]).is_file(), f"Search link missing: {item['url']}")
    check("胶粘剂" not in item["title"] + item["content"] + " ".join(item["categories"]), f"Old terminology remains in search: {item['title']}")
check(pages[(SITE / "index.html").resolve()].cards == 8, "Homepage should show eight recent posts")
check("test1" not in {item["title"] for item in documents}, "Test post leaked into search")

ns = {"s": "http://www.sitemaps.org/schemas/sitemap/0.9"}
sitemap = ET.parse(SITE / "sitemap.xml")
locations = {unquote(node.text) for node in sitemap.findall(".//s:loc", ns)}
check(all(url.startswith(ORIGIN) for url in locations), "Sitemap URLs must be absolute")
for item in documents:
    check(ORIGIN + unquote(item["url"]) in locations, f"Article absent from sitemap: {item['title']}")
for file, page in pages.items():
    if page.redirect:
        relative = file.relative_to(SITE).as_posix()
        url = "/" + (relative[:-10] if relative.endswith("index.html") else relative)
        check(ORIGIN + url not in locations, f"Redirect must stay out of sitemap: {url}")
    if file.parent.parent == (SITE / "categories").resolve():
        check(unquote(page.canonical) in locations, f"Category absent from sitemap: {file.parent.name}")
check("Sitemap: " + ORIGIN + "/sitemap.xml" in (SITE / "robots.txt").read_text(), "robots.txt is missing sitemap")
check(not re.search(r"fonts\.googleapis\.com|background\.jpg", (SITE / "assets/css/site.css").read_text()), "Heavy background or remote font still in active CSS")
for file in (SITE / "assets/images").rglob("*.svg"):
    visible = "".join(ET.parse(file).getroot().itertext())
    check("胶粘剂" not in visible, f"Old terminology remains in illustration: {file.name}")

category_errors, category_count = verify_categories(SITE)
errors.extend(category_errors)

if errors:
    for error in errors:
        print("FAIL:", error)
    sys.exit(1)
print(f"PASS: {len(pages)} pages, {len(baseline)} preserved article URLs, {len(documents)} searchable articles, {category_count} chronological category pages, images, anchors and SEO.")
