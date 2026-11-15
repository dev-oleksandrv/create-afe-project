# Sourced by scripts/check-decisions.sh. The path classes: a path takes the highest class among
# the `high <glob>` and `gate <glob>` lines of .claude/path-classes that match it; a path that no
# line matches is low when it is a document (Markdown) or a generated file, otherwise normal. An
# instruction or policy file is normal, Markdown or not, because it changes what agents do:
# AGENTS.md and CLAUDE.md in any directory, the files under a .claude/ directory's skills/,
# rules/, agents/, and commands/, and the generated .claude/settings.json. Low comes only from the
# built-in rule: any other line of the file, such as an `approval` or `low` line of an older
# project, is ignored.

classes_file=.claude/path-classes

class_rank() {
  case "$1" in high) echo 4 ;; gate) echo 3 ;; normal) echo 2 ;; low) echo 1 ;; *) echo 0 ;; esac
}

# True when $1 matches a glob line of the list file $2; '#' starts a comment.
glob_listed() {
  local pat
  [ -f "$2" ] || return 1
  while IFS= read -r pat || [ -n "$pat" ]; do
    case "$pat" in ''|'#'*) continue ;; esac
    # shellcheck disable=SC2254
    case "$1" in $pat) return 0 ;; esac
  done < "$2"
  return 1
}

# class_of <path>: prints the class of the path: high, gate, normal, or low.
class_of() {
  local best=0 name= cls pat r
  if [ -f "$classes_file" ]; then
    while read -r cls pat || [ -n "$cls" ]; do
      case "$cls" in high|gate) ;; *) continue ;; esac
      [ -n "$pat" ] || continue
      # shellcheck disable=SC2254
      case "$1" in $pat) ;; *) continue ;; esac
      r=$(class_rank "$cls")
      [ "$r" -gt "$best" ] && best=$r name=$cls
    done < "$classes_file"
  fi
  if [ -z "$name" ]; then
    case "$1" in
      AGENTS.md|*/AGENTS.md|CLAUDE.md|*/CLAUDE.md|.claude/settings.json) name=normal ;;
      .claude/skills/*|*/.claude/skills/*|.claude/rules/*|*/.claude/rules/*) name=normal ;;
      .claude/agents/*|*/.claude/agents/*|.claude/commands/*|*/.claude/commands/*) name=normal ;;
      *.md|.template/owned.sha256|.afe-answers.json) name=low ;;
      *) name=normal ;;
    esac
  fi
  echo "$name"
}

# answers_version [commit]: prints the _version of .afe-answers.json in the working tree, or in
# the commit; nothing when the file or the field is missing.
answers_version() {
  if [ -n "${1:-}" ]; then git show "$1:.afe-answers.json" 2> /dev/null; else cat .afe-answers.json 2> /dev/null; fi |
    node scripts/lib/json.mjs get _version 2> /dev/null
}

# project_block: prints the lines of the project block of the AGENTS.md read from stdin.
project_block() { awk '$0 == "<!-- project:end -->" {f = 0} f; $0 == "<!-- project:start -->" {f = 1}'; }

# review_level <base> <path>...: the review before the pull request that the paths, changed
# against the base commit, need, by their highest class: two (high: two reviewers), one (gate,
# normal: one reviewer), or none (nothing but class low). A template update needs none, because
# the template repository reviewed it: the _version of .afe-answers.json differs from the base's,
# no path is class high or gate, and every other path is template-owned or generated; AGENTS.md
# counts only when its project block is the one of the base. An update never changes an existing
# seeded file (README.md, CLAUDE.md, .gitignore, .claude/path-classes, .claude/harness.conf,
# .claude/settings.project.json) and keeps the project block, so a change of them is the
# project's and gets the review its class asks for.
review_level() {
  local base=${1:-} p c best=1 update=1 answers=0 old new
  [ "$#" -eq 0 ] || shift
  for p in "$@"; do
    case "$p" in
      .afe-answers.json) answers=1 ;;
      .template/owned.sha256|.claude/settings.json|docs/decisions/README.md) ;;
      AGENTS.md)
        [ -f AGENTS.md ] && [ "$(project_block < AGENTS.md)" = "$(git show "$base:AGENTS.md" 2> /dev/null | project_block)" ] ||
          update=0 ;;
      README.md|CLAUDE.md|.gitignore|.claude/path-classes|.claude/harness.conf|.claude/settings.project.json) update=0 ;;
      *) glob_listed "$p" .template/owned.txt || update=0 ;;
    esac
    c=$(class_rank "$(class_of "$p")")
    [ "$c" -gt "$best" ] && best=$c
  done
  if [ "$update" = 1 ] && [ "$answers" = 1 ] && [ "$best" -le 2 ]; then
    old=$(answers_version "$base") new=$(answers_version)
    [ -n "$old" ] && [ -n "$new" ] && [ "$old" != "$new" ] || update=0
  else
    update=0
  fi
  if [ "$#" -eq 0 ] || [ "$update" = 1 ] || [ "$best" -le 1 ]; then echo none
  elif [ "$best" -ge 4 ]; then echo two
  else echo one; fi
}
