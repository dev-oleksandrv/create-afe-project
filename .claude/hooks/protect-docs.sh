#!/usr/bin/env bash
# PreToolUse hook (Edit, Write, MultiEdit, Bash): a change to a path of class approval, and an
# irreversible action, need an explicit owner instruction (AGENTS.md, section 4;
# docs/documentation-rules.md, sections 8 and 9). Class approval are the template-owned files of
# .template/owned.txt, the generated ownership manifest, answers file, and .claude/settings.json,
# the documentation map, .claude/path-classes and its `approval <glob>` lines,
# .claude/settings.project.json, .mcp.json, the glob lines of a legacy .claude/protected-paths,
# ADRs that exist on main, and ADRs that are no longer `proposed`. The irreversible actions are the
# commands that irreversible() below names. A target path is judged by the git repository that holds it when that
# repository has .template/owned.txt, so a sibling worktree or another generated project is
# guarded by its own paths; otherwise by the session's project (CLAUDE_PROJECT_DIR) when the path
# is inside it; any other path is not guarded. A relative path of a shell command resolves
# against the hook input's `cwd`. The hook turns such a change into a
# permission prompt for the owner (`permissionDecision: ask`); in headless runs Claude Code denies
# it. DOCS_GUARD=off in the Claude Code environment disables the guard for scripted owner-driven
# runs, such as a template update. This is a guard against unreviewed changes, not a security
# boundary: a command that hides the target path (for example inside a script file, behind a
# variable, or in a directory changed by a script) is not detected; nor is a command split across
# lines with a backslash, or one behind a prefix such as env, time, or nohup.
# It stays on in GitHub Actions, unlike the other hooks: claude-code-action restores .claude/
# from the base branch there, and this hook runs no file of the working tree, which a pull request
# supplies. It reads its input and writes its answer with `node -e` code of its own, not
# scripts/lib/json.mjs, and only reads the lists it names as data (docs/documentation-rules.md,
# section 7).
set -uo pipefail
[ "${DOCS_GUARD:-on}" = "off" ] && exit 0

# Without Node.js the hook cannot read the tool call; block it rather than allow everything.
command -v node >/dev/null || { echo "protect-docs: Node.js is required (README.md, Checks)" >&2; exit 2; }
# Prints the tool, the cwd, the file path, the command, and the kind of the first known token
# format in what the call writes (content, new_string, edits, command), each followed by a NUL
# byte, an empty string when missing. A match asks the owner; it does not prove a live secret.
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
process.stdout.write([s(d && d.tool_name), s(d && d.cwd), s(t.file_path), s(t.command), hit ? hit[0] : ""].map((x) => x + "\0").join(""));
'
{ IFS= read -r -d '' tool; IFS= read -r -d '' cwd; IFS= read -r -d '' file_path; IFS= read -r -d '' cmd
  IFS= read -r -d '' secret; } < <(node -e "$read_input")
# Prints the PreToolUse answer: $1 the decision (ask or deny), $2 the reason.
answer() {
  node -e 'const [, decision, reason] = process.argv;
process.stdout.write(JSON.stringify({ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: decision, permissionDecisionReason: reason } }) + "\n");' "$1" "$2"
}
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
project="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -n "$project" ] && project=$(cd "$project" 2>/dev/null && pwd -P) || project=

# True when $1 matches a line of the list file $2 (shell glob patterns; '#' starts a comment).
listed() {
  local pat
  [ -f "$2" ] || return 1
  while IFS= read -r pat; do
    case "$pat" in ''|'#'*) continue ;; esac
    # shellcheck disable=SC2254
    case "$1" in $pat) return 0 ;; esac
  done < "$2"
  return 1
}

# Prints why $1 is protected, or nothing when it is not.
protected_reason() {
  local p="$1" abs rel dir rest seg norm climbed=1 root
  case "$p" in /*) abs="$p" ;; *) abs="$cwd/$p" ;; esac
  # Resolve "..", "//", and symbolic links in the part of the path that exists. In the part that
  # does not exist yet, fold "." and "x/.."; a ".." left over climbs from the existing directory,
  # and then the folded path is resolved once more, as it may enter another existing directory.
  while [ -n "$climbed" ]; do
    dir=$(dirname "$abs") rest=$(basename "$abs") norm= climbed=
    while [ ! -d "$dir" ]; do rest="$(basename "$dir")/$rest"; dir=$(dirname "$dir"); done
    dir=$(cd "$dir" && pwd -P) || return 0
    while [ -n "$rest" ]; do
      seg=${rest%%/*}
      if [ "$seg" = "$rest" ]; then rest=; else rest=${rest#*/}; fi
      case "$seg" in
        ''|.) ;;
        ..) if [ -z "$norm" ]; then dir=$(dirname "$dir") climbed=1
            elif [ "${norm%/*}" = "$norm" ]; then norm=
            else norm=${norm%/*}; fi ;;
        *) norm=${norm:+$norm/}$seg ;;
      esac
    done
    abs="$dir/$norm"
  done
  # The generated project that holds the path: its git repository when that has
  # .template/owned.txt (a sibling worktree, another generated project), otherwise the session's
  # project when the path is inside it (no git yet, a nested repository, a missing manifest).
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && root=$(cd "$root" && pwd -P) &&
    [ -f "$root/.template/owned.txt" ] || root=$project
  [ -n "$root" ] || return 0
  rel="${abs#"$root"/}"
  [ "$rel" != "$abs" ] || return 0
  if [ "$rel" = AGENTS.md ]; then
    echo "template-owned outside its project block; only the project block may change here"
    return
  fi
  if approval_listed "$rel" "$root/.claude/path-classes"; then
    echo "class approval in .claude/path-classes"
    return
  fi
  if listed "$rel" "$root/.template/owned.txt"; then
    echo "template-owned; change it in the template repository and update (docs/contributing.md, section 5)"
    return
  fi
  case "$rel" in
    .template/owned.sha256|.afe-answers.json|.copier-answers.yml)
      echo "generated by a template update only" ;;
    .claude/settings.json)
      echo "generated by scripts/gen-settings.sh; change .claude/settings.project.json instead, with the owner" ;;
    .claude/path-classes|.claude/protected-paths)
      echo "the classes of paths, class approval" ;;
    .claude/settings.project.json|.mcp.json)
      echo "permissions and MCP servers, class approval" ;;
    docs/README.md)
      echo "documentation map; structure changes need the owner" ;;
    docs/decisions/README.md)
      ;; # generated by scripts/gen-decisions-index.sh; scripts/check-decisions.sh checks it
    docs/decisions/*.md)
      if git -C "$root" cat-file -e "origin/main:$rel" 2>/dev/null ||
        { ! git -C "$root" rev-parse -q --verify origin/main >/dev/null && git -C "$root" cat-file -e "main:$rel" 2>/dev/null; }; then
        echo "ADR that exists on main; only its status line changes (documentation-rules.md, section 5), otherwise supersede it with a new ADR"
      elif [ -f "$abs" ] && ! head -n 8 "$abs" | grep -q -E '^status:[[:space:]]*proposed'; then
        echo "ADR that is no longer proposed; immutable, supersede it with a new ADR"
      fi ;;
    *)
      listed "$rel" "$root/.claude/protected-paths" && echo "listed in .claude/protected-paths" ;;
  esac
}

# True when $1 matches an `approval <glob>` line of .claude/path-classes, file $2.
approval_listed() {
  local cls pat
  [ -f "$2" ] || return 1
  while read -r cls pat || [ -n "$cls" ]; do
    [ "$cls" = approval ] && [ -n "$pat" ] || continue
    # shellcheck disable=SC2254
    case "$1" in $pat) return 0 ;; esac
  done < "$2"
  return 1
}

# Prints the paths a shell command can write, one per line: redirect targets in every segment, the
# destination of cp, mv, install, and ln, the files of tee, rm, truncate, and touch, dd's of=, the
# files of sed -i, perl -i, and git checkout, restore, rm, mv, and apply, and file-like tokens of an
# interpreter (python, node, ruby, perl, bash, sh), also in the heredoc a python, node, ruby, or
# perl reads; a heredoc on a line where a shell runs (`bash <<EOF`, `cat <<EOF | sh`,
# `source /dev/stdin <<EOF`) is parsed as commands. A relative target is joined to
# the directory of an earlier `cd DIR` with a literal DIR, and a git path argument to a literal
# `git -C DIR`. The body of any other heredoc is text, not commands; `<<<`, `$((1 << n))`, and
# `<<` inside quotes start no heredoc. Input files (<) and sources are not targets.
write_targets() {
  printf '%s\n' "$1" | awk '
    function out(t) { if (t == "") return; if (t !~ /^\// && pre != "") t = pre "/" t; print t }
    function emit_all(from,   x, na, A) { na = split(args, A, " "); for (x = from; x <= na; x++) out(A[x]) }
    function files(text,   tmp) {
      tmp = text
      while (match(tmp, /[A-Za-z0-9_.\/-]*(\.(md|json|jsonc|toml|yml|yaml|sh|txt|sha256|jinja|conf|pem|key)|\.claude\/(protected-paths|path-classes)|\.env[A-Za-z0-9_.]*)/)) {
        out(substr(tmp, RSTART, RLENGTH)); tmp = substr(tmp, RSTART + RLENGTH)
      }
    }
    BEGIN { dir = "" }
    hd != "" { l = $0; gsub(/^[ \t]+|[ \t]+$/, "", l); if (l == hd) { hd = ""; next }; if (hdint) { pre = dir; files($0) }; next }
    {
      line = $0; delim = ""
      if (match(line, /<<-?[ \t]*["\047]?[A-Za-z_][A-Za-z0-9_]*/)) {
        before = substr(line, 1, RSTART - 1); cand = substr(line, RSTART, RLENGTH)
        dq = gsub(/"/, "\"", before); sq = gsub(/\047/, "\047", before)
        if (before !~ /<$/ && before !~ /\$\(\([^)]*$/ && dq % 2 == 0 && sq % 2 == 0) {
          delim = cand; sub(/^<<-?[ \t]*["\047]?/, "", delim)
        }
      }
      n = split(line, segs, /[|;&]+/)
      for (i = 1; i <= n; i++) {
        s = segs[i]; tmp = s; pre = dir
        m = split(s, w, /[ \t]+/); k = 1
        while (k <= m && (w[k] == "" || w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w[k] == "sudo" || w[k] == "command")) k++
        cmd = w[k]; sub(/.*\//, "", cmd)
        if (cmd == "cd") {
          d = w[k + 1]; gsub(/^["\047]+|["\047]+$/, "", d)
          if (d ~ /[$`~*?]/ || d == "" || d == "-") { }
          else if (d ~ /^\//) dir = d; else dir = (dir == "" ? d : dir "/" d)
          continue
        }
        while (match(tmp, />>?[ \t]*["\047]?[A-Za-z0-9_.\/-]+/)) {
          t = substr(tmp, RSTART, RLENGTH); sub(/^>>?[ \t]*["\047]?/, "", t); out(t)
          tmp = substr(tmp, RSTART + RLENGTH)
        }
        if (cmd == "git" && w[k + 1] == "-C") {
          d = w[k + 2]; gsub(/^["\047]+|["\047]+$/, "", d)
          if (d !~ /[$`~*?]/) pre = (d ~ /^\// || dir == "") ? d : dir "/" d
          for (x = k + 1; x + 2 <= m; x++) w[x] = w[x + 2]; m -= 2
        }
        gsub(/[0-9]*>>?[ \t]*["\047]?[^ \t]*/, "", s); gsub(/<<?-?[ \t]*[^ \t]*/, "", s)
        if (cmd != "git") { m = split(s, w, /[ \t]+/); k = 1
          while (k <= m && (w[k] == "" || w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w[k] == "sudo" || w[k] == "command")) k++ }
        args = ""
        for (j = k + 1; j <= m; j++) { a = w[j]; gsub(/^["\047]+|["\047]+$/, "", a); if (a !~ /^-/) args = args " " a }
        if (cmd ~ /^(cp|mv|install|ln)$/) { na = split(args, A, " "); if (na) out(A[na]) }
        else if (cmd ~ /^(tee|rm|truncate|touch)$/) emit_all(1)
        else if (cmd == "dd") { na = split(args, A, " "); for (x = 1; x <= na; x++) if (sub(/^of=/, "", A[x])) out(A[x]) }
        else if (cmd ~ /^(sed|perl)$/ && s ~ /[ \t]-[a-zA-Z]*i/) emit_all(1)
        else if (cmd == "git" && w[k + 1] ~ /^(checkout|restore|rm|mv|apply)$/) emit_all(2)
        if (cmd ~ /^(python3?|node|ruby|perl|bash|sh|zsh)$/) files(segs[i])
        if (delim != "" && segs[i] ~ /<</) hdint = (cmd ~ /^(python3?|node|ruby|perl)$/)
        if (cmd ~ /^(bash|sh|zsh|source|\.)$/) hdsh = 1
      }
      if (delim != "" && !hdsh) hd = delim
      hdsh = 0
    }'
}

# Prints the first irreversible action in a shell command, or nothing: in any segment, `git push`
# (after git's global options such as -C DIR) with --force, --force-with-lease,
# --force-if-includes, --delete, --mirror, --prune, or --tags, a short option that contains f or
# d (-f, -uf, -d), a refspec that starts with + or :, or a tag (refs/tags/..., or v followed by a
# digit, the form of a release); `gh pr merge`; `gh release create` or `gh release delete`;
# `gh repo delete`, `rename`, and `archive`; `gh workflow run`; `gh api` with the method DELETE; a
# change of repository settings: `gh repo edit` with any flags, `scripts/protect-branch.sh` (by any
# path, or through bash, sh, zsh, or source) without --dry-run, and `gh api` with the method PATCH,
# PUT, or POST (-X, --method, or POST implied by -f, -F, --field, --raw-field, or --input) on
# `repos/OWNER/REPO` itself, its `rulesets`, or a `branches/BRANCH/protection`, while other
# endpoints such as comments and replies pass; `gh api graphql` with a `query=` field that holds
# the keyword mutation, or whose text the hook cannot read: `-F query=@file`, `--input`, a value
# that starts with `$` or holds `$(` or a backquote, or a quoted value that spans lines, while a
# query without mutation on one line passes; and
# publishing a package or an image: `npm`, `pnpm`, `yarn`, `bun`, `cargo`, `poetry`, or
# `uv publish`, `twine upload`, `gem push`, `dotnet nuget push`, `docker` or `podman push`.
# A `gh api` endpoint may also be a full URL (https://HOST/, HOST/api/, or HOST/api/v3/).
# With "push" as $2 it prints instead the words of the first `git push` that are not options:
# the remote and the refspecs, one per line, or "-" alone when there are none.
irreversible() {
  printf '%s\n' "$1" | awk -v mode="${2:-}" '
  # The last word of an option value that starts in word j as v: past the closing quote when v
  # opens one, so that a quoted value with spaces ("Accept: x") is not read as an argument. Sets
  # unclosed when the quote does not close in the segment, as in a value that spans lines.
  function vend(j, v,   q, c) {
    unclosed = 0
    if (match(v, /["\047]/)) {
      q = substr(v, RSTART, 1); c = gsub(q, q, v)
      if (c % 2) { unclosed = 1; while (j < m) { j++; if (index(w[j], q)) { unclosed = 0; break } } }
    }
    return j
  }
  # Words j to e of the segment, joined by a space.
  function words(j, e,   r) { r = w[j]; while (j < e) r = r " " w[++j]; return r }
  # Notes the field option o with the value v of gh api: an --input body, or a query= value that
  # is a file (-F or --field with @), a shell expansion, text with the keyword mutation, or a
  # quoted text that does not close on its line, of which the hook reads only the first line.
  function field(o, v) {
    if (o == "--input") { ghid = 1; return }
    gsub(/["\047]/, "", v)
    if (v !~ /^query=/) return
    v = substr(v, 7)
    if ((o ~ /^(-F|--field)$/ && v ~ /^@/) || v ~ /^\$/ || index(v, "$(") || index(v, "`")) ghid = 1
    else if (v ~ /(^|[^A-Za-z0-9_])mutation([^A-Za-z0-9_]|$)/) gmut = 1
    else if (unclosed) ghid = 1
  }
  {
    n = split($0, segs, /[|;&]+/)
    for (i = 1; i <= n; i++) {
      m = split(segs[i], w, /[ \t]+/); k = 1
      while (k <= m && (w[k] == "" || w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/ || w[k] == "sudo" || w[k] == "command")) k++
      cmd = w[k]; sub(/.*\//, "", cmd)
      s = k + 1
      if (cmd == "git") while (s <= m && w[s] ~ /^-/) s += (w[s] == "-C" || w[s] == "-c") ? 2 : 1
      sub1 = w[s]; sub2 = w[s + 1]
      if (cmd == "git" && sub1 == "push") {
        if (mode == "push") {
          out = ""
          for (j = s + 1; j <= m; j++) { a = w[j]; gsub(/^["\047]+|["\047]+$/, "", a); if (a != "" && a !~ /^-/) out = out a "\n" }
          printf "%s", (out == "" ? "-\n" : out); exit
        }
        for (j = s + 1; j <= m; j++) {
          a = w[j]; gsub(/^["\047]+|["\047]+$/, "", a)
          if (a ~ /^--(force|force-with-lease|force-if-includes|delete|mirror|prune|tags)(=.*)?$/ || a ~ /^-[A-Za-z]*[fd][A-Za-z]*$/ || a ~ /^[+:]/ || a ~ /^(refs\/tags\/|v[0-9])/) {
            print "git push " a; exit
          }
        }
      }
      if (mode == "push") continue
      if (cmd == "gh" && ((sub1 == "pr" && sub2 == "merge") || (sub1 == "release" && sub2 ~ /^(create|delete)$/) || (sub1 == "repo" && sub2 ~ /^(delete|edit|rename|archive)$/) || (sub1 == "workflow" && sub2 == "run"))) {
        print "gh " sub1 " " sub2; exit
      }
      scr = cmd; x = k
      if (cmd ~ /^(bash|sh|zsh|source|\.)$/) { x = k + 1; while (x <= m && w[x] ~ /^[-+]/) x += (w[x] ~ /^([-+][oO]|--rcfile|--init-file)$/) ? 2 : 1; scr = w[x]; sub(/.*\//, "", scr) }
      gsub(/["\047]/, "", scr)
      if (scr == "protect-branch.sh") {
        dry = 0
        for (j = x + 1; j <= m; j++) { a = w[j]; if (a ~ /^#/) break; gsub(/^["\047]+|["\047]+$/, "", a); if (a == "--dry-run") dry = 1 }
        if (!dry) { print "scripts/protect-branch.sh without --dry-run"; exit }
      }
      if (cmd == "gh" && sub1 == "api") {
        meth = ""; body = 0; ep = ""; gmut = 0; ghid = 0
        for (j = s + 1; j <= m; j++) {
          a = w[j]; gsub(/^["\047]+|["\047]+$/, "", a)
          if (a ~ /^(-X|--method)$/) { meth = w[j + 1]; j++ }
          else if (a ~ /^--method=/) meth = substr(a, 10)
          else if (a ~ /^-X./) meth = substr(a, 3)
          else if (a ~ /^(-f|-F|--field|--raw-field|--input)$/) { body = 1; e = vend(j + 1, w[j + 1]); field(a, words(j + 1, e)); j = e }
          else if (a ~ /^(-f|-F)./ || a ~ /^--(field|raw-field|input)=/) {
            body = 1; e = vend(j, w[j]); o = a; v = words(j, e)
            if (o ~ /^-[fF]/) { o = substr(o, 1, 2); v = substr(v, 3) } else { sub(/=.*/, "", o); sub(/^[^=]*=/, "", v) }
            field(o, v); j = e
          }
          else if (a ~ /^(-H|--header|-q|--jq|-t|--template|--hostname|-p|--preview|--cache)$/) j = vend(j + 1, w[j + 1])
          else if (a ~ /^--(header|jq|template|hostname|preview|cache)=/) j = vend(j, w[j])
          else if (a !~ /^-/ && ep == "") ep = a
        }
        gsub(/["\047]/, "", meth); meth = toupper(meth)
        if (meth == "" && body) meth = "POST"
        if (meth == "DELETE") { print "gh api DELETE"; exit }
        sub(/^https?:\/\/[^\/]+\/(api\/(v3\/)?)?/, "", ep); sub(/^\//, "", ep); sub(/\?.*/, "", ep)
        if (ep == "graphql" && gmut) { print "gh api graphql with a mutation"; exit }
        if (ep == "graphql" && ghid) { print "gh api graphql with a query from a file, standard input, --input, a shell expansion, or more than one line, which the hook cannot read; it may be a mutation"; exit }
        if (meth ~ /^(PATCH|PUT|POST)$/ && (ep ~ /^repos\/[^\/]+(\/[^\/]+)?\/?$/ || ep ~ /^repos\/[^\/]+(\/[^\/]+)?\/(rulesets|branches\/.+\/protection)(\/|$)/)) {
          print "gh api " meth " " ep; exit
        }
      }
      if ((cmd ~ /^(npm|pnpm|yarn|bun|cargo|poetry|uv)$/ && sub1 == "publish") || (cmd == "twine" && sub1 == "upload") || (cmd == "gem" && sub1 == "push") ||
          (cmd ~ /^(docker|podman)$/ && sub1 == "push") || (cmd == "dotnet" && sub1 == "nuget" && sub2 == "push")) {
        print cmd " " sub1 (cmd == "dotnet" ? " " sub2 : ""); exit
      }
    }
  }'
}

# Prints the default branch when the shell command pushes to it, or nothing. Without a refspec,
# `git push` pushes the current branch. A default branch that the remote does not have yet (the
# first push of a new repository) is left to the owner's prompt, not denied.
pushes_default() {
  local words remote refs r dst def cur
  words=$(irreversible "$1" push)
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

ask_owner() {
  answer ask "Protected file: $1 ($2). Changing it needs an explicit owner instruction (AGENTS.md, section 4). Approve only if you asked for this change; otherwise the agent must report it as an open question."
  exit 0
}

deny_push() {
  answer deny "Pushing to the default branch $1 is not allowed: changes reach it only through a pull request (AGENTS.md, section 4; docs/contributing.md, section 1). Push a branch and open a pull request instead."
  exit 0
}

ask_action() {
  answer ask "Irreversible action: $1. It needs an explicit owner instruction (AGENTS.md, section 4; docs/documentation-rules.md, section 8). Approve only if you asked for it."
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

case "$tool" in
  Edit|Write|MultiEdit)
    path=$file_path
    [ -n "$path" ] || exit 0
    reason=$(protected_reason "$path")
    [ -n "$reason" ] && ask_owner "$path" "$reason"
    ;;
  Bash)
    [ -n "$cmd" ] || exit 0
    # Rewriting the manifest is how a local edit of a template-owned file would be hidden.
    if printf '%s' "$cmd" | grep -q -E 'check-template\.sh[^|;&]*--write'; then
      ask_owner ".template/owned.sha256" "generated by a template update only, via Bash"
    fi
    action=$(irreversible "$cmd")
    [ -n "$action" ] && ask_action "$action"
    targets=$(write_targets "$cmd")
    for tok in $targets; do
      reason=$(protected_reason "$tok")
      [ -n "$reason" ] && ask_owner "$tok" "$reason, via Bash"
    done
    ;;
esac
exit 0
