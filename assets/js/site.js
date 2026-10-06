(function () {
  'use strict';
  document.querySelectorAll('img[data-fallback-image]').forEach(function (image) {
    function useDefault() {
      var cover = image.closest('[data-optional-cover]');
      (cover || image).hidden = true;
    }
    image.addEventListener('error', useDefault);
    if (image.complete && image.naturalWidth === 0) useDefault();
  });
  var menu = document.querySelector('.menu-toggle');
  var sidebar = document.getElementById('site-navigation');
  function closeMenu() {
    if (!menu || !sidebar) return;
    sidebar.classList.remove('is-open');
    menu.setAttribute('aria-expanded', 'false');
    menu.setAttribute('aria-label', '展开导航');
  }
  if (menu && sidebar) {
    menu.addEventListener('click', function () {
      var open = !sidebar.classList.contains('is-open');
      sidebar.classList.toggle('is-open', open);
      menu.setAttribute('aria-expanded', String(open));
      menu.setAttribute('aria-label', open ? '收起导航' : '展开导航');
    });
    sidebar.addEventListener('click', function (event) { if (event.target.closest('a')) closeMenu(); });
    document.addEventListener('click', function (event) {
      if (!sidebar.contains(event.target) && !menu.contains(event.target)) closeMenu();
    });
    window.addEventListener('resize', function () { if (window.innerWidth > 860) closeMenu(); });
  }
  var input = document.getElementById('search-input');
  var panel = document.getElementById('search-results');
  var status = document.getElementById('search-status');
  var list = document.getElementById('search-list');
  var searchRoot = document.querySelector('.site-search');
  var prepared = null;
  var pending = null;
  var timer = null;
  var sequence = 0;
  var composing = false;
  function closeSearch() { if (panel) panel.hidden = true; }
  function loadIndex() {
    if (prepared) return Promise.resolve(prepared);
    if (pending) return pending;
    pending = fetch(searchRoot.dataset.indexUrl, { credentials: 'same-origin' }).then(function (response) {
      if (!response.ok) throw new Error('Search index unavailable');
      return response.json();
    }).then(function (documents) {
      if (!Array.isArray(documents)) throw new Error('Invalid search index');
      prepared = window.HuashanSearch.prepare(documents);
      return prepared;
    }).catch(function (error) { pending = null; throw error; });
    return pending;
  }
  function render(query, current) {
    if (!query.trim()) { closeSearch(); list.replaceChildren(); return; }
    panel.hidden = false;
    status.textContent = '正在搜索…';
    list.replaceChildren();
    loadIndex().then(function (documents) {
      if (current !== sequence || !input.value.trim()) return;
      var results = window.HuashanSearch.search(documents, query);
      status.textContent = results.length ? '找到 ' + results.length + ' 篇文章' + (results.length > 20 ? '，显示前 20 篇' : '') : '没有找到相关文章，试试更短的关键词。';
      var fragment = document.createDocumentFragment();
      results.slice(0, 20).forEach(function (result) {
        var item = document.createElement('li');
        var link = document.createElement('a');
        link.href = result.document.url;
        var title = document.createElement('span');
        title.className = 'search-result-title';
        title.textContent = result.document.title;
        var meta = document.createElement('span');
        meta.className = 'search-result-meta';
        meta.textContent = (result.document.categories || []).join(' · ') + ' · ' + result.document.date;
        var excerpt = document.createElement('span');
        excerpt.className = 'search-result-snippet';
        excerpt.textContent = result.snippet;
        link.append(title, meta, excerpt);
        item.append(link);
        fragment.append(item);
      });
      list.append(fragment);
    }).catch(function () {
      if (current !== sequence) return;
      status.textContent = '搜索暂时不可用，请稍后重试，或从「全部文章」浏览。';
    });
  }
  function schedule() {
    sequence += 1;
    window.clearTimeout(timer);
    if (composing) return;
    var current = sequence;
    var query = input.value;
    timer = window.setTimeout(function () { render(query, current); }, 100);
  }
  if (input && panel && searchRoot && window.HuashanSearch) {
    input.addEventListener('input', schedule);
    input.addEventListener('compositionstart', function () { composing = true; sequence += 1; window.clearTimeout(timer); });
    input.addEventListener('compositionend', function () { composing = false; schedule(); });
    input.addEventListener('focus', function () {
      loadIndex().catch(function () {});
      if (input.value.trim()) schedule();
    });
    input.addEventListener('keydown', function (event) {
      if (composing || event.isComposing) return;
      if (event.key === 'Escape') {
        sequence += 1;
        window.clearTimeout(timer);
        input.value = '';
        closeSearch();
      }
      if (event.key === 'ArrowDown' && !panel.hidden && list.querySelector('a')) {
        event.preventDefault();
        list.querySelector('a').focus();
      }
      if (event.key === 'Enter' && !panel.hidden && list.querySelector('a')) {
        event.preventDefault();
        list.querySelector('a').click();
      }
    });
    list.addEventListener('keydown', function (event) {
      var links = Array.from(list.querySelectorAll('a'));
      var index = links.indexOf(document.activeElement);
      if (event.key === 'ArrowDown' && index >= 0) { event.preventDefault(); links[Math.min(index + 1, links.length - 1)].focus(); }
      if (event.key === 'ArrowUp' && index >= 0) { event.preventDefault(); if (index === 0) input.focus(); else links[index - 1].focus(); }
      if (event.key === 'Escape') { sequence += 1; window.clearTimeout(timer); input.value = ''; closeSearch(); input.focus(); }
    });
    document.addEventListener('click', function (event) {
      if (!searchRoot.contains(event.target)) { sequence += 1; window.clearTimeout(timer); closeSearch(); }
    });
    document.addEventListener('keydown', function (event) {
      var target = event.target;
      var editable = target.closest('input, textarea, select, [contenteditable="true"]');
      if (event.key === '/' && !editable) { event.preventDefault(); input.focus(); }
      if (event.key === 'Escape') closeMenu();
    });
  }
  var article = document.querySelector('.article-body');
  var toc = document.querySelector('.article-toc');
  var tocList = document.getElementById('article-toc-list');
  if (article && toc && tocList) {
    var headings = Array.from(article.querySelectorAll('h2, h3'));
    headings.forEach(function (heading, index) {
      if (!heading.id) heading.id = 'section-' + (index + 1);
      var item = document.createElement('li');
      if (heading.tagName === 'H3') item.className = 'toc-subheading';
      var link = document.createElement('a');
      link.href = '#' + encodeURIComponent(heading.id);
      link.textContent = heading.textContent.trim();
      item.append(link);
      tocList.append(item);
    });
    if (headings.length) {
      toc.hidden = false;
      if (window.matchMedia('(max-width: 580px)').matches) toc.open = false;
    }
  }
  document.querySelectorAll('.article-body table, .page-body table').forEach(function (table) {
    if (table.parentElement.classList.contains('table-scroll')) return;
    var wrapper = document.createElement('div');
    wrapper.className = 'table-scroll';
    wrapper.tabIndex = 0;
    wrapper.setAttribute('role', 'region');
    wrapper.setAttribute('aria-label', '可横向滚动的数据表格');
    table.before(wrapper);
    wrapper.append(table);
  });
  if (article && window.katex) {
    article.querySelectorAll('[data-math]').forEach(function (element) {
      window.katex.render(element.dataset.math, element, {
        displayMode: element.classList.contains('math-block'),
        throwOnError: false,
        strict: 'ignore',
        trust: false
      });
    });
  }
  if (article && typeof window.renderMathInElement === 'function') {
    window.renderMathInElement(article, {
      delimiters: [
        { left: '$$', right: '$$', display: true },
        { left: '$', right: '$', display: false },
        { left: '\\(', right: '\\)', display: false },
        { left: '\\[', right: '\\]', display: true }
      ],
      ignoredClasses: ['no-math', 'math-inline', 'math-block'],
      throwOnError: false
    });
  }
}());
