'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const engine = require('../assets/js/search-engine.js');
const sourcePosts = require('./source-posts.cjs');
const documents = JSON.parse(fs.readFileSync(path.join(__dirname, '../_site/assets/search.json'), 'utf8'));
const index = engine.prepare(documents);
const titles = query => engine.search(index, query).map(result => result.document.title);

test('every listed post enters the generated index, including new posts', () => {
  const listed = sourcePosts({listed: true});
  assert.equal(documents.length, listed.length);
  assert(!titles('test1').includes('test1'));
  assert.equal(titles('小炒秋葵')[0], '小炒秋葵');
  assert.equal(titles('蒜蓉生菜')[0], '蒜蓉生菜');
  assert.equal(titles('酸菜鱼')[0], '酸菜鱼');
});
test('Chinese full titles rank first and short Chinese words work', () => {
  assert.equal(titles('木材与水分')[0], '木材与水分');
  assert(titles('木材').includes('木材与水分'));
  assert.equal(titles('字体参数')[0], '字体参数');
});
test('search includes article body text and multiple terms', () => {
  assert(titles('红葱油').includes('小炒秋葵'));
  assert(titles('秋葵 五花肉').includes('小炒秋葵'));
  assert.deepEqual(titles('秋葵 WSGI'), []);
});
test('English, full-width characters and 黏/粘 are normalized', () => {
  assert(titles('FLASK').includes('flask中config的内容'));
  assert.deepEqual(titles('ｆｌａｓｋ'), titles('flask'));
  assert.deepEqual(titles('胶黏剂'), titles('胶粘剂'));
  assert.equal(engine.normalize('胶黏剂'), '胶黏剂');
});
test('adhesive articles use 胶黏剂 in titles, bodies, categories and canonical URLs', () => {
  const adhesives = documents.filter(doc => doc.categories.includes('胶黏剂'));
  assert.equal(adhesives.length, 20);
  assert(adhesives.some(doc => doc.title === '胶黏剂概论'));
  for (const doc of documents) {
    assert(!JSON.stringify(doc).includes('胶粘剂'), 'Old terminology in ' + doc.title);
  }
  for (const doc of adhesives) {
    assert(decodeURI(doc.url).startsWith('/胶黏剂/'));
    assert(!decodeURI(doc.url).includes('胶粘剂'));
  }
});
test('blank and missing keywords return no results', () => {
  assert.deepEqual(titles('  '), []);
  assert.deepEqual(titles('不存在的关键词987654321'), []);
});
test('only local article URLs are accepted', () => {
  const data = engine.prepare([{title: 'bad', url: '//example.com'}, {title: 'bad', url: 'javascript:alert(1)'}, {title: 'good', url: '/post.html'}]);
  assert.equal(data.length, 1);
  assert.equal(data[0].document.title, 'good');
});
