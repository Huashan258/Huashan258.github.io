(function (root, factory) {
  'use strict';
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.HuashanSearch = factory();
}(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  function normalize(value) {
    return String(value || '').normalize('NFKC').toLowerCase().replace(/粘/g, '黏').replace(/\s+/g, ' ').trim();
  }
  function prepare(documents) {
    return documents.filter(function (doc) {
      return doc && typeof doc.url === 'string' && doc.url.charAt(0) === '/' && doc.url.slice(0, 2) !== '//';
    }).map(function (doc) {
      return {
        document: doc,
        title: normalize(doc.title),
        categories: normalize((doc.categories || []).join(' ')),
        content: normalize(doc.content)
      };
    });
  }
  function snippet(content, query) {
    var text = String(content || '').replace(/\s+/g, ' ').trim();
    var words = normalize(query).split(' ');
    var position = -1;
    var normalized = normalize(text);
    words.forEach(function (word) {
      var index = normalized.indexOf(word);
      if (index >= 0 && (position < 0 || index < position)) position = index;
    });
    var start = position > 24 ? position - 24 : 0;
    return (start > 0 ? '…' : '') + text.slice(start, start + 110) + (text.length > start + 110 ? '…' : '');
  }
  function search(prepared, query, limit) {
    var phrase = normalize(query).slice(0, 120);
    if (!phrase) return [];
    var terms = Array.from(new Set(phrase.split(' ')));
    var results = [];
    prepared.forEach(function (entry) {
      var haystack = entry.title + ' ' + entry.categories + ' ' + entry.content;
      if (!terms.every(function (term) { return haystack.indexOf(term) >= 0; })) return;
      var score = entry.title === phrase ? 1200 : (entry.title.indexOf(phrase) >= 0 ? 600 : 0);
      terms.forEach(function (term) {
        if (entry.title.indexOf(term) >= 0) score += 180;
        if (entry.categories.indexOf(term) >= 0) score += 35;
        if (entry.content.indexOf(term) >= 0) score += 8;
      });
      results.push({ document: entry.document, score: score, snippet: snippet(entry.document.content, phrase) });
    });
    results.sort(function (a, b) {
      return b.score - a.score || String(b.document.date || '').localeCompare(String(a.document.date || '')) || a.document.url.localeCompare(b.document.url);
    });
    return typeof limit === 'number' ? results.slice(0, limit) : results;
  }
  return { normalize: normalize, prepare: prepare, search: search, snippet: snippet };
}));
