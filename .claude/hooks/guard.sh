#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit, Bash). It denies a push to the default branch, and asks
# the owner before a call that writes a known secret format (`permissionDecision: ask`; in headless
# runs Claude Code denies it). The irreversible commands, such as a forced push, a merge, a
# release, a change of repository settings, or publishing, are permission rules of
# .claude/settings.template.json, not this hook. DOCS_GUARD=off in the Claude Code environment
# disables the guard for scripted owner-driven runs.
# This is a guard against unreviewed changes, not a security boundary: a push split across lines
# with a backslash, or behind a prefix such as env, time, or nohup, is not detected.
# It stays on in GitHub Actions, unlike the other hooks: claude-code-action restores .claude/
# from the base branch there, and this hook runs no file of the working tree, which a pull request
# supplies. It reads its input and writes its answer with `node -e` code of its own, not
# scripts/lib/json.mjs.
set -uo pipefail
[ "${DOCS_GUARD:-on}" = "off" ] && exit 0

# Without Node.js the hook cannot read the tool call; block it rather than allow everything.
command -v node >/dev/null || { echo "guard: Node.js is required (README.md, Checks)" >&2; exit 2; }
# Prints the tool, the cwd, the command, and the kind of the first known token format in what the
# call writes (content, new_string, edits, command), each followed by a NUL byte, an empty string
# when missing. A match asks the owner; it does not prove a live secret.
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
process.stdout.write([s(d && d.tool_name), s(d && d.cwd), s(t.command), hit ? hit[0] : ""].map((x) => x + "\0").join(""));
'
{ IFS= read -r -d '' tool; IFS= read -r -d '' cwd; IFS= read -r -d '' cmd; IFS= read -r -d '' secret; } < <(node -e "$read_input")
# Prints the PreToolUse answer: $1 the decision (ask or deny), $2 the reason.
answer() {
  node -e 'const [, decision, reason] = process.argv;
process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: decision, permissionDecisionReason: reason } }) + "\n");' "$1" "$2"
}
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
# Prints the words of the first `git push` in a shell command that are not options: the remote and
# the refspecs, one per line, or "-" alone when there are none; nothing without a `git push`. The
# push may follow git's global options, such as -C DIR, in any segment of the command.
push_words() {
  printf '%s\n' "$1" | awk '{
    n = split($0, segs, /[|;&]+/)
    for (i = 1; i <= n; i++) {
      m = split(segs[i], w, /[ \t]+/); k = 1
      while (k <= m && (w[k] == "" || w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w[k] == "sudo" || w[k] == "command")) k++
      cmd = w[k]; sub(/.*\//, "", cmd)
      if (cmd != "git") continue
      s = k + 1
      while (s <= m && w[s] ~ /^-/) s += (w[s] == "-C" || w[s] == "-c") ? 2 : 1
      if (w[s] != "push") continue
      out = ""
      for (j = s + 1; j <= m; j++) { a = w[j]; gsub(/^["\047]+|["\047]+$/, "", a); if (a != "" && a !~ /^-/) out = out a "\n" }
      printf "%s", (out == "" ? "-\n" : out); exit
    }
  }'
}

# Prints the default branch when the shell command pushes to it, or nothing. Without a refspec,
# `git push` pushes the current branch. A default branch that the remote does not have yet (the
# first push of a new repository) is left to the owner's prompt, not denied.
pushes_default() {
  local words remote refs r dst def cur
  words=$(push_words "$1")
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
if [ "$tool" = Bash ] && [ -n "$cmd" ]; then
  branch=$(pushes_default "$cmd")
  [ -n "$branch" ] && deny_push "$branch"
fi

# A known token format in what the call writes: secrets never go into the repository.
if [ -n "$secret" ] && [[ "$tool" =~ ^(Edit|Write|MultiEdit|Bash)$ ]]; then
  answer ask "Possible secret ($secret) in this change. Secrets never go into the repository or a command line; use an environment variable or the CI secret store. Approve only if it is a placeholder or a test fixture."
  exit 0
fi

exit 0
