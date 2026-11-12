# Sourced by scripts/check-decisions.sh. The path classes: a path takes the highest class among
# the `high <glob>` and `gate <glob>` lines of .claude/path-classes that match it; a path that no
# line matches is low when it is Markdown or a generated file, otherwise normal. Low comes only
# from that built-in rule: any other line of the file, such as an `approval` or `low` line of an
# older project, is ignored.

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
      *.md|.template/owned.sha256|.afe-answers.json|.copier-answers.yml|.claude/settings.json) name=low ;;
      *) name=normal ;;
    esac
  fi
  echo "$name"
}

# review_level <path>...: the review before the pull request that the paths need, by their
# highest class: two (high: two reviewers), one (gate, normal: one reviewer), or none (nothing
# but class low). A template update needs none, because the template repository reviewed it: a
# change of the answers file whose other paths are all template-owned, generated, or seeded.
review_level() {
  local p c best=1 update=1 answers=0
  for p in "$@"; do
    case "$p" in
      .afe-answers.json|.copier-answers.yml) answers=1 ;;
      AGENTS.md|.template/owned.sha256|.claude/settings.json|docs/decisions/README.md) ;;
      README.md|CLAUDE.md|.gitignore|docs/README.md|.claude/path-classes|.claude/harness.conf|\
      .claude/settings.project.json) ;;
      *) glob_listed "$p" .template/owned.txt || update=0 ;;
    esac
    c=$(class_rank "$(class_of "$p")")
    [ "$c" -gt "$best" ] && best=$c
  done
  if [ "$#" -eq 0 ] || { [ "$update" = 1 ] && [ "$answers" = 1 ]; } || [ "$best" -le 1 ]; then echo none
  elif [ "$best" -ge 4 ]; then echo two
  else echo one; fi
}
