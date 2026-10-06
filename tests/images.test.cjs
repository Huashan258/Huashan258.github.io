'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

test('failed optional images restore the avatar or the plain category card', () => {
  const cover = {hidden: false};
  function image(complete, naturalWidth, parent = null) {
    return {complete, naturalWidth, hidden: false, handlers: {},
      closest: () => parent,
      addEventListener(event, callback) {this.handlers[event] = callback;}};
  }
  const avatar = image(true, 44);
  const lazyCover = image(false, 0, cover);
  const cachedFailure = image(true, 0);
  const document = {
    querySelector: () => null,
    getElementById: () => null,
    querySelectorAll: selector => selector === 'img[data-fallback-image]' ? [avatar, lazyCover, cachedFailure] : []
  };
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, '../assets/js/site.js'), 'utf8'), {document, window: {}});
  assert.equal(avatar.hidden, false);
  assert.equal(cover.hidden, false, 'not-yet-loaded lazy covers must remain visible');
  assert.equal(cachedFailure.hidden, true);
  avatar.handlers.error();
  assert.equal(avatar.hidden, true);
  lazyCover.handlers.error();
  assert.equal(cover.hidden, true);
});
