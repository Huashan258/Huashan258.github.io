"""Check category navigation and chronological contents against the search index."""
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote
import json


class CategoryPage(HTMLParser):
    def __init__(self, content):
        super().__init__(convert_charrefs=True)
        self.cards = []
        self.links = []
        self.articles = []
        self.dates = []
        self.title = ""
        self.article_titles = []
        self.capture = None
        self.feed(content)

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        classes = attrs.get("class", "").split()
        if tag == "h1":
            self.capture = "title"
        if tag == "a":
            self.links.append(unquote(attrs.get("href", "")))
        if tag == "a" and "category-card-link" in classes:
            self.cards.append(unquote(attrs["href"]))
        if tag == "a" and "category-article-link" in classes:
            self.articles.append(unquote(attrs["href"]))
            self.article_titles.append("")
            self.capture = "article"
        if tag == "time":
            self.dates.append(datetime.fromisoformat(attrs["datetime"]))

    def handle_data(self, data):
        if self.capture == "title":
            self.title += data
        if self.capture == "article":
            self.article_titles[-1] += data

    def handle_endtag(self, tag):
        if tag in ("a", "h1"):
            self.capture = None


def verify(site):
    errors = []
    documents = json.loads((site / "assets/search.json").read_text(encoding="utf-8"))
    expected = {}
    for document in documents:
        for category in document["categories"]:
            expected.setdefault(category, set()).add(unquote(document["url"]))
    overview = CategoryPage((site / "categories/index.html").read_text(encoding="utf-8"))
    if len(overview.cards) != len(expected) or len(set(overview.cards)) != len(expected):
        errors.append("Each category must have exactly one overview card")
    if any(unquote(document["url"]) in overview.links for document in documents):
        errors.append("Category overview must not expand article links")
    seen = set()
    for url in overview.cards:
        file = site / url.lstrip("/") / "index.html"
        if not file.is_file():
            errors.append(f"Category detail missing: {url}")
            continue
        page = CategoryPage(file.read_text(encoding="utf-8"))
        name = page.title.strip()
        seen.add(name)
        if set(page.articles) != expected.get(name, set()) or len(page.articles) != len(set(page.articles)):
            errors.append(f"Category detail has missing, extra or duplicate articles: {name}")
        if len(page.dates) != len(page.articles) or page.dates != sorted(page.dates):
            errors.append(f"Category articles must be oldest first: {name}")
        if name == "胶粘剂" and (not page.article_titles or page.article_titles[0] != "胶粘剂概论"):
            errors.append("胶粘剂概论 must be the first article in 胶粘剂")
    if seen != set(expected):
        errors.append("Category detail names do not match visible article categories")
    return errors, len(seen)


if __name__ == "__main__":
    problems, count = verify(Path(__file__).resolve().parents[1] / "_site")
    for problem in problems:
        print("FAIL:", problem)
    if problems:
        raise SystemExit(1)
    print(f"PASS: {count} category cards and complete category pages ordered oldest first.")
