# Sourced by scripts/check-decisions.sh. The path classes of docs/documentation-rules.md,
# section 8: approval, high, gate, normal, low; a path takes the highest class that applies.
# - approval, built in: AGENTS.md, the template-owned files of .template/owned.txt, the generated
#   .template/owned.sha256, the answers file (.afe-answers.json, or the legacy
#   .copier-answers.yml), and .claude/settings.json, the map
#   docs/README.md, .claude/path-classes, .claude/settings.project.json, .mcp.json, the glob
#   lines of a legacy .claude/protected-paths, any decision record that exists on the base, and
#   any decision record whose status is not `proposed`;
# - then every `<class> <glob>` line of .claude/path-classes that matches;
# - a path that nothing matches is low when it is Markdown or generated, otherwise normal.

classes_file=.claude/path-classes

class_rank() {
  case "$1" in approval) echo 5 ;; high) echo 4 ;; gate) echo 3 ;; normal) echo 2 ;; low) echo 1 ;; *) echo 0 ;; esac
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

# True when path $1 is an approval path by a built-in rule; $2 is the base commit.
builtin_approval() {
  case "$1" in
    AGENTS.md|.template/owned.sha256|.afe-answers.json|.copier-answers.yml|.claude/settings.json|docs/README.md|\
    .claude/path-classes|.claude/settings.project.json|.mcp.json) return 0 ;;
    docs/decisions/README.md) return 1 ;;
    docs/decisions/[0-9][0-9][0-9][0-9]-*.md)
      git cat-file -e "$2:$1" 2>/dev/null && return 0
      [ -f "$1" ] && ! head -n 8 "$1" | grep -q -E '^status:[[:space:]]*proposed' && return 0 ;;
  esac
  glob_listed "$1" .template/owned.txt || glob_listed "$1" .claude/protected-paths
}

# class_of <path> <base commit> [content]: prints the class of the path. With "content", approval
# is left out: the class of what the path contains, which decides its review.
class_of() {
  local best=0 name= cls pat r
  if [ "${3:-}" != content ] && builtin_approval "$1" "$2"; then echo approval; return; fi
  if [ -f "$classes_file" ]; then
    while read -r cls pat || [ -n "$cls" ]; do
      case "$cls" in ''|'#'*) continue ;; esac
      [ -n "$pat" ] || continue
      [ "${3:-}" = content ] && [ "$cls" = approval ] && continue
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

# review_level <base commit> <path>...: the review before the pull request that the paths need,
# by their highest content class: santa (high), one (gate, normal), or none (low). A template
# update needs none, because the template repository reviewed it: a change of
# the answers file whose other paths are all template-owned, generated, or seeded.
review_level() {
  local mb="$1" p c best=1 update=1 answers=0
  shift
  for p in "$@"; do
    case "$p" in
      .afe-answers.json|.copier-answers.yml) answers=1 ;;
      AGENTS.md|.template/owned.sha256|.claude/settings.json|docs/decisions/README.md) ;;
      README.md|CLAUDE.md|.gitignore|docs/README.md|.claude/path-classes|.claude/harness.conf|\
      .claude/settings.project.json|.claude/protected-paths) ;;
      *) glob_listed "$p" .template/owned.txt || update=0 ;;
    esac
    c=$(class_rank "$(class_of "$p" "$mb" content)")
    [ "$c" -gt "$best" ] && best=$c
  done
  if [ "$#" -eq 0 ] || { [ "$update" = 1 ] && [ "$answers" = 1 ]; } || [ "$best" -le 1 ]; then echo none
  elif [ "$best" -ge 4 ]; then echo santa
  else echo one; fi
}
