#!/usr/bin/env node
// Internal link check of the Markdown files, with Node.js only: every relative link and image
// points at an existing file or directory, and every #anchor at a heading or an HTML id/name of
// the target Markdown file (the anchors GitHub generates). External links (with a scheme, such as
// https: or mailto:) are not checked: the author verifies them when adding them. Files ignored by
// Git are skipped; a file is read whole, so a link inside a fenced code block or a code span is
// not a link.
//
// Code paths, in the Markdown files under docs/ and in AGENTS.md: every backticked token outside
// fenced code blocks that is a path candidate exists. A candidate contains "/", has no
// whitespace, none of * ? < > { } $ |, and no scheme, and its first segment is the name of an
// entry in the repository root; a trailing ":line", "#anchor", or "::name" is stripped first.
// Any other token, such as origin/main or owner/name, is not a path and is not checked. The root
// entries and the existence of a path come from Git (tracked and untracked files that are not
// ignored, and their directories), compared case-sensitively, so an ignored directory such as
// dist/ names no root entry and scripts/Check.sh is not scripts/check.sh on a case-insensitive
// file system; a path inside a submodule exists when the file system has it. Outside a Git
// repository: the file system.
//
// Usage: node scripts/check-links.mjs [file.md ...]   default: every Markdown file of the repository
//   Run from the repository root; a file argument is relative to it or absolute.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync, realpathSync, statSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve } from 'node:path';

const root = process.cwd();

function markdownFiles() {
  try {
    const out = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', '*.md'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    });
    return out.split('\0').filter((f) => f && existsSync(f));
  } catch {
    const found = [];
    const walk = (dir) => {
      for (const e of readdirSync(dir, { withFileTypes: true })) {
        if (e.name === 'node_modules' || e.name === '.git') continue;
        const p = join(dir, e.name);
        if (e.isDirectory()) walk(p);
        else if (e.name.endsWith('.md')) found.push(relative(root, p));
      }
    };
    walk(root);
    return found;
  }
}

// Blanks fenced code blocks, HTML comments, and code spans, keeping line numbers and offsets.
function prose(text) {
  const blank = (m) => m.replace(/[^\n]/g, ' ');
  return text
    .replace(/^( {0,3})(`{3,}|~{3,})[^\n]*\n[\s\S]*?(?:^\1?\2[^\n]*$|(?![\s\S]))/gm, blank)
    .replace(/<!--[\s\S]*?-->/g, blank)
    .replace(/(`+)(?!`)[\s\S]*?[^`]\1(?!`)/g, blank);
}

// The anchor GitHub derives from a heading: lowercase, punctuation removed, spaces to hyphens.
function slug(heading) {
  const plain = heading
    .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/<[^>]+>/g, '')
    .replace(/(^|\W)[*_]{1,3}|[*_]{1,3}(?=\W|$)/g, '$1')
    .replace(/`/g, '');
  return plain
    .trim()
    .toLowerCase()
    .replace(/[^\p{L}\p{M}\p{N}\p{Pc} -]/gu, '')
    .replace(/ /g, '-');
}

const anchorCache = new Map();
function anchors(file) {
  if (anchorCache.has(file)) return anchorCache.get(file);
  const text = readFileSync(file, 'utf8');
  const lines = text.replace(/^( {0,3})(`{3,}|~{3,})[^\n]*\n[\s\S]*?(?:^\1?\2[^\n]*$|(?![\s\S]))/gm, (m) => m.replace(/[^\n]/g, ' ')).split('\n');
  const found = new Set();
  const seen = new Map();
  const add = (heading) => {
    const base = slug(heading);
    const n = seen.get(base) ?? 0;
    seen.set(base, n + 1);
    found.add(n ? `${base}-${n}` : base);
  };
  lines.forEach((line, i) => {
    const atx = /^ {0,3}#{1,6}[ \t]+(.*?)(?:[ \t]+#+)?[ \t]*$/.exec(line);
    if (atx) add(atx[1]);
    else if (i > 0 && lines[i - 1].trim() && /^ {0,3}(=+|-+)[ \t]*$/.test(line) && !/^ {0,3}([-*_])( *\1){2,} *$/.test(lines[i - 1])) {
      add(lines[i - 1].trim());
    }
    for (const m of line.matchAll(/<[a-z][^>]*\s(?:id|name)=["']([^"']+)["']/gi)) found.add(m[1]);
  });
  anchorCache.set(file, found);
  return found;
}

function* links(text) {
  const src = prose(text);
  const lineOf = (i) => src.slice(0, i).split('\n').length;
  // Inline links and images: [text](target "title"), with one level of nested brackets.
  for (const m of src.matchAll(/!?\[(?:[^\[\]]|\[[^\]]*\])*\]\(\s*(<[^>]*>|[^\s)]*(?:\([^\s)]*\)[^\s)]*)*)(?:\s+(?:"[^"]*"|'[^']*'|\([^)]*\)))?\s*\)/g)) {
    yield { target: m[1].replace(/^<|>$/g, ''), line: lineOf(m.index) };
  }
  // Reference definitions: [id]: target
  for (const m of src.matchAll(/^ {0,3}\[[^\]]+\]:[ \t]*(<[^>]*>|\S+)/gm)) {
    yield { target: m[1].replace(/^<|>$/g, ''), line: lineOf(m.index) };
  }
  // HTML links and images.
  for (const m of src.matchAll(/<(?:a|img)\b[^>]*\s(?:href|src)=["']([^"']*)["']/gi)) {
    yield { target: m[1], line: lineOf(m.index) };
  }
}

// The fenced code blocks of a text blanked, keeping line numbers and offsets.
function unfenced(text) {
  return text.replace(/^( {0,3})(`{3,}|~{3,})[^\n]*\n[\s\S]*?(?:^\1?\2[^\n]*$|(?![\s\S]))/gm, (m) => m.replace(/[^\n]/g, ' '));
}

// The files and directories Git knows (null outside a Git repository), and the root entries.
let known;
let rootEntries;
function gitPaths() {
  if (known !== undefined) return known;
  try {
    const out = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      maxBuffer: 1 << 30,
    });
    known = new Set();
    for (const f of out.split('\0')) {
      if (!f) continue;
      const parts = f.split('/');
      for (let i = 1; i <= parts.length; i++) known.add(parts.slice(0, i).join('/'));
    }
  } catch {
    known = null;
  }
  return known;
}

// Does the path exist: known to Git and present, or inside a submodule (a known path that is a
// directory with files Git does not list) and present; outside Git, present.
function exists(path) {
  const p = path.replace(/\/+$/, '');
  if (!existsSync(join(root, p))) return false;
  const paths = gitPaths();
  if (!paths || paths.has(p)) return true;
  const parts = p.split('/');
  for (let i = parts.length - 1; i > 0; i--) {
    const prefix = parts.slice(0, i).join('/');
    if (paths.has(prefix)) return existsSync(join(root, prefix, '.git'));
  }
  return false;
}

// The path that a backticked token names, or null when the token is no path candidate.
function candidate(token) {
  if (!token.includes('/') || /[\s*?<>{}$|]/.test(token) || /^[a-z][a-z0-9+.-]*:/i.test(token)) return null;
  const path = token.replace(/::[^/]*$/, '').replace(/#[^/]*$/, '').replace(/(:\d+)+$/, '');
  if (rootEntries === undefined) {
    const paths = gitPaths();
    rootEntries = paths ? new Set([...paths].map((p) => p.split('/')[0])) : new Set(readdirSync(root));
  }
  return path && rootEntries.has(path.split('/')[0]) ? path : null;
}

// Does the file take the code-path check: Markdown under docs/, or AGENTS.md at the root.
function codePathFile(file) {
  const rel = relative(root, resolve(root, file)).split('\\').join('/');
  return rel === 'AGENTS.md' || (rel.startsWith('docs/') && rel.endsWith('.md'));
}

function codePaths(file, text) {
  const problems = [];
  const src = unfenced(text);
  const lineOf = (i) => src.slice(0, i).split('\n').length;
  for (const m of src.matchAll(/(`+)(?!`)([\s\S]*?[^`])\1(?!`)/g)) {
    const path = candidate(m[2].trim());
    if (path && !exists(path)) problems.push(`${file}:${lineOf(m.index)}: \`${path}\`: no such file or directory`);
  }
  return problems;
}

function check(file) {
  const problems = [];
  if (codePathFile(file)) problems.push(...codePaths(file, readFileSync(file, 'utf8')));
  for (const { target, line } of links(readFileSync(file, 'utf8'))) {
    if (!target || /^[a-z][a-z0-9+.-]*:/i.test(target) || target.startsWith('//')) continue;
    const hash = target.indexOf('#');
    const pathPart = (hash === -1 ? target : target.slice(0, hash)).replace(/\?.*$/, '');
    const fragment = hash === -1 ? '' : target.slice(hash + 1);
    let dest = file;
    if (pathPart) {
      let decoded;
      try {
        decoded = decodeURIComponent(pathPart);
      } catch {
        decoded = pathPart;
      }
      dest = decoded.startsWith('/') ? join(root, decoded) : resolve(dirname(file), decoded);
      if (!existsSync(dest)) {
        problems.push(`${file}:${line}: ${target}: no such file or directory`);
        continue;
      }
    }
    if (!fragment || !dest.endsWith('.md') || !statSync(dest).isFile()) continue;
    let anchor;
    try {
      anchor = decodeURIComponent(fragment);
    } catch {
      anchor = fragment;
    }
    if (!anchors(dest).has(anchor) && !anchors(dest).has(anchor.toLowerCase())) {
      problems.push(`${file}:${line}: ${target}: no heading or anchor #${anchor} in ${relative(root, dest) || file}`);
    }
  }
  return problems;
}

// An absolute argument is made relative to the root, through its real path (macOS: /var is /private/var).
const arg = (f) => (isAbsolute(f) && existsSync(f) ? relative(root, realpathSync(f)) || f : f);
const files = process.argv.length > 2 ? process.argv.slice(2).map(arg) : markdownFiles();
const problems = files.flatMap(check);
for (const p of problems) console.log(`FAIL: ${p}`);
console.log(`== links: ${files.length} Markdown files, ${problems.length} broken`);
process.exit(problems.length ? 1 : 0);
