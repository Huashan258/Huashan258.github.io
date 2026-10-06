const fs = require('node:fs');
const path = require('node:path');
module.exports = function sourcePosts(options = {}) {
  const folder = path.join(__dirname, '../_posts');
  return fs.readdirSync(folder).map(file => fs.readFileSync(path.join(folder, file), 'utf8')).filter(content => {
    const header = content.split('---', 3)[1] || '';
    if (/^published:\s*false\s*$/m.test(header)) return false;
    if (options.listed && /^listed:\s*false\s*$/m.test(header)) return false;
    const match = header.match(/^date:\s*["']?(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2})\s*([+-]\d{4}|Z)/m);
    if (match) {
      const offset = match[3] === 'Z' ? 'Z' : match[3].slice(0, 3) + ':' + match[3].slice(3);
      if (Date.parse(match[1] + 'T' + match[2] + offset) > Date.now()) return false;
    }
    return true;
  });
};
