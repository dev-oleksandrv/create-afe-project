// Renders template/ with the answers: Jinja syntax through Nunjucks, as Copier did. A file whose
// name ends in .jinja is rendered and loses the suffix; any other file is copied as it is. Every
// path segment is rendered too, and a segment that renders empty drops the file or directory, so
// a module's files use a conditional name such as `{% if code_review %}review-code{% endif %}`.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import nunjucks from 'nunjucks';
import { RENAMES } from './config.js';

const SUFFIX = '.jinja';
const env = new nunjucks.Environment(null, { autoescape: false, throwOnUndefined: true });

/**
 * @param {string} text
 * @param {Record<string, unknown>} context
 * @returns {string}
 */
export function renderString(text, context) {
  return env.renderString(text, context);
}

/**
 * Renders every file of the template directory.
 * @param {string} templateDir
 * @param {Record<string, unknown>} context
 * @returns {Map<string, { content: Buffer | string, mode: number }>} by relative output path
 */
export function renderTemplate(templateDir, context) {
  const out = new Map();
  const walk = (srcDir, outPrefix) => {
    for (const entry of readdirSync(srcDir, { withFileTypes: true })) {
      const src = join(srcDir, entry.name);
      const templated = entry.isFile() && entry.name.endsWith(SUFFIX);
      let name = renderString(templated ? entry.name.slice(0, -SUFFIX.length) : entry.name, context);
      if (!name) continue;
      if (entry.isDirectory()) {
        walk(src, outPrefix ? `${outPrefix}/${name}` : name);
        continue;
      }
      const { mode } = statSync(src);
      let content = readFileSync(src);
      if (templated) {
        content = renderString(content.toString('utf8'), context);
      }
      name = RENAMES[name] ?? name;
      out.set(outPrefix ? `${outPrefix}/${name}` : name, { content, mode });
    }
  };
  walk(templateDir, '');
  return out;
}
