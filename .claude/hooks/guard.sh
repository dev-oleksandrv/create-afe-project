#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit, Bash). It denies a push to the default branch, and asks
# the owner before a call that writes a known secret format (`permissionDecision: ask`; in headless
# runs Claude Code denies it). The irreversible commands, such as a forced push, a merge, a
# release, a change of repository settings, or publishing, are permission rules of
# .claude/settings.template.json, not this hook. DOCS_GUARD=off in the Claude Code environment
# disables the guard for scripted owner-driven runs.
# This is a guard against unreviewed changes, not a security boundary: a push behind a prefix such
# as env, time, or nohup, or in a script file that a command runs, is not detected.
# It stays on in GitHub Actions, unlike the other hooks: claude-code-action restores .claude/
# from the base branch there, and this hook runs no file of the working tree, which a pull request
# supplies. It reads its input and writes its answer with `node -e` code of its own, not
# scripts/lib/json.mjs.
set -uo pipefail
[ "${DOCS_GUARD:-on}" = "off" ] && exit 0

# Without Node.js the hook cannot read the tool call; block it rather than allow everything.
command -v node >/dev/null || { echo "guard: Node.js is required (README.md, Checks)" >&2; exit 2; }
# Prints the tool, the cwd, the command, the kind of the first known token format in what the call
# writes (content, new_string, edits, command), and the push words of the command (below), each
# followed by a NUL byte, an empty string when missing. A token match asks the owner; it does not
# prove a live secret.
# The push words: one line for each `git push` in the command, at any depth, with the words of
# that push that are not options, the remote and the refspecs, separated by the byte 0x1f, or "-"
# alone when there are none; nothing without a `git push`. The command is read as words: a quoted part is part of its word, so adjacent quotes
# around a word are that word and quoted data (a commit message, the text of echo or printf) is no
# command; a backslash takes the next character, and one before a line end joins the lines. The
# commands are the parts between ; & | ( ) ` and line ends, a command substitution inside double
# quotes, and the command string of bash, sh, zsh, dash, or ksh -c and of eval, each scanned in
# turn. A push may follow assignments, sudo, command, and git's global options, such as -C DIR.
# This is a word scan, not a shell parser.
read_input='
const SECRETS = [
  ["AWS access key", /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/],
  ["GitHub token", /\bgh[pousr]_[A-Za-z0-9]{36,}\b|\bgithub_pat_[A-Za-z0-9_]{60,}/],
  ["GitLab token", /\bglpat-[A-Za-z0-9_-]{20,}/],
  ["Slack token", /\bxox[abposr]-[A-Za-z0-9-]{10,}/],
  ["Stripe live key", /\b[rs]k_live_[A-Za-z0-9]{20,}/],
  ["Google API key", /\bAIza[0-9A-Za-z_-]{35}\b/],
  ["Anthropic API key", /\bsk-ant-[A-Za-z0-9_-]{20,}/],
  ["OpenAI API key", /\bsk-(?:proj-)?[A-Za-z0-9_-]{40,}/],
  ["npm token", /\bnpm_[A-Za-z0-9]{36}\b/],
  ["private key", /-----BEGIN (?:[A-Z]+ )*PRIVATE KEY(?: BLOCK)?-----/],
];
let d = null;
try { d = JSON.parse(require("node:fs").readFileSync(0, "utf8") || "null"); } catch {}
const t = (d && d.tool_input) || {};
const s = (v) => (v == null ? "" : typeof v === "string" ? v : JSON.stringify(v));
const edits = Array.isArray(t.edits) ? t.edits.map((e) => e && e.new_string) : [];
const text = [t.content, t.new_string, t.command, ...edits].filter((x) => typeof x === "string").join("\n");
const hit = SECRETS.find(([, re]) => re.test(text));
const Q = String.fromCharCode(39);
// Each command it scans in turn is shorter than the text it comes from, so the scan ends.
function pushWords(line, all) {
  const segs = [], subs = [];
  let words = [], word = null;
  const end = () => { if (word !== null) words.push(word); word = null; };
  const cut = () => { end(); if (words.length) segs.push(words); words = []; };
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === "\\") {
      if (line[i + 1] !== "\n") word = (word ?? "") + (line[i + 1] ?? "");
      i++;
    } else if (c === Q) {
      const j = line.indexOf(Q, i + 1);
      word = (word ?? "") + line.slice(i + 1, j < 0 ? line.length : j);
      i = j < 0 ? line.length : j;
    } else if (c === "\"") {
      let q = "", j = i + 1;
      for (; j < line.length && line[j] !== "\""; j++) q += line[j] === "\\" && j + 1 < line.length ? line[++j] : line[j];
      for (const m of q.matchAll(/\$\(([^)]*)\)|`([^`]*)`/g)) subs.push(m[1] ?? m[2]);
      word = (word ?? "") + q;
      i = j;
    } else if (c === " " || c === "\t") end();
    else if (";&|()`\n".includes(c)) cut();
    else word = (word ?? "") + c;
  }
  cut();
  for (const w of segs) {
    let k = 0;
    while (k < w.length && (/^[A-Za-z_][A-Za-z0-9_]*=/.test(w[k]) || w[k] === "sudo" || w[k] === "command")) k++;
    const name = (w[k] ?? "").replace(/.*\//, "");
    let inner = null;
    if (/^(bash|sh|zsh|dash|ksh)$/.test(name)) {
      for (let j = k + 1; j < w.length && w[j].startsWith("-"); j++) if (/^-[A-Za-z]*c[A-Za-z]*$/.test(w[j])) { inner = w[j + 1] ?? ""; break; }
    } else if (name === "eval") inner = w.slice(k + 1).join(" ");
    if (inner !== null) {
      pushWords(inner, all);
      continue;
    }
    if (name !== "git") continue;
    let j = k + 1;
    while (j < w.length && w[j].startsWith("-")) j += w[j] === "-C" || w[j] === "-c" ? 2 : 1;
    if (w[j] !== "push") continue;
    const out = w.slice(j + 1).filter((a) => a !== "" && !a.startsWith("-")).map((a) => a.replace(/[\n\x1f]/g, " "));
    all.push(out.length ? out : ["-"]);
  }
  for (const sub of subs) pushWords(sub, all);
  return all;
}
const push = typeof t.command === "string" ? pushWords(t.command, []) : [];
process.stdout.write([s(d && d.tool_name), s(d && d.cwd), s(t.command), hit ? hit[0] : "", push.map((p) => p.join("\x1f")).join("\n")].map((x) => x + "\0").join(""));
'
{ IFS= read -r -d '' tool; IFS= read -r -d '' cwd; IFS= read -r -d '' cmd; IFS= read -r -d '' secret; IFS= read -r -d '' push; } < <(node -e "$read_input")
# Prints the PreToolUse answer: $1 the decision (ask or deny), $2 the reason.
answer() {
  node -e 'const [, decision, reason] = process.argv;
process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: decision, permissionDecisionReason: reason } }) + "\n");' "$1" "$2"
}
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
# Prints the default branch when the push words $1 push to it, or nothing. Without a refspec,
# `git push` pushes the current branch. A default branch that the remote does not have yet (the
# first push of a new repository) is left to the owner's prompt, not denied.
pushes_default() {
  local words=$1 remote refs r dst def cur
  [ -n "$words" ] || return 0
  def=$(git -C "$cwd" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) && def=${def#origin/} || def=main
  if [ "$words" = - ]; then refs=; remote=origin; else remote=$(printf '%s\n' "$words" | head -n 1); refs=$(printf '%s\n' "$words" | tail -n +2); fi
  if [ -z "$refs" ]; then
    cur=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null) || return 0
    refs=$cur
  fi
  while IFS= read -r r; do
    dst=${r#+}; dst=${dst##*:}; dst=${dst#refs/heads/}
    [ "$dst" = HEAD ] && dst=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null)
    if [ "$dst" = "$def" ]; then
      git -C "$cwd" ls-remote --exit-code --heads "$remote" "$def" > /dev/null 2>&1 && echo "$def"
      return 0
    fi
  done <<< "$refs"
}

deny_push() {
  answer deny "Pushing to the default branch $1 is not allowed: changes reach it only through a pull request. Push a branch and open a pull request instead."
  exit 0
}

# A push to the default branch is denied before anything asks: an approved prompt must never let
# it through.
# Every push of the command is checked; one to the default branch denies the call.
if [ "$tool" = Bash ] && [ -n "$cmd" ] && [ -n "$push" ]; then
  while IFS= read -r p; do
    branch=$(pushes_default "$(printf '%s' "$p" | tr '\037' '\n')")
    [ -n "$branch" ] && deny_push "$branch"
  done <<< "$push"
fi

# A known token format in what the call writes: secrets never go into the repository.
if [ -n "$secret" ] && [[ "$tool" =~ ^(Edit|Write|MultiEdit|Bash)$ ]]; then
  answer ask "Possible secret ($secret) in this change. Secrets never go into the repository or a command line; use an environment variable or the CI secret store. Approve only if it is a placeholder or a test fixture."
  exit 0
fi

exit 0
