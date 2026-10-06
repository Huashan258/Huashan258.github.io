'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const katex = require('../assets/vendor/katex/katex.min.js');
const sourcePosts = require('./source-posts.cjs');
const root = path.join(__dirname, '..');
function walk(folder) {
  return fs.readdirSync(folder, {withFileTypes: true}).flatMap(entry => {
    const file = path.join(folder, entry.name);
    return entry.isDirectory() ? walk(file) : [file];
  });
}
function unescape(text) {
  return text.replace(/&(?:amp|quot|lt|gt|#39);/g, entity => ({'&amp;':'&','&quot;':'"','&lt;':'<','&gt;':'>','&#39;':"'"})[entity]);
}
test('remote formula images become valid local KaTeX formulas', () => {
  const sourceCount = sourcePosts().reduce((count, content) => count + (content.match(/https:\/\/latex\.codecogs\.com\//g) || []).length, 0);
  let converted = 0;
  for (const file of walk(path.join(root, '_site')).filter(file => file.endsWith('.html'))) {
    for (const match of fs.readFileSync(file, 'utf8').matchAll(/data-math="([^"]*)"/g)) {
      const tex = unescape(match[1]);
      assert.doesNotThrow(() => katex.renderToString(tex, {throwOnError: true, strict: 'ignore', trust: false}), path.relative(root, file));
      converted++;
    }
  }
  assert.equal(converted, sourceCount);
  assert(converted > 0);
});
