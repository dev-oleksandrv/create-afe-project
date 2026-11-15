# update stays inside the project: it refuses an entry of .template/owned.txt that leaves the
# project, and a symbolic link on the way to a file it would read, write, or remove, before it
# changes anything. Needs $sample from 90-update.sh.
echo "== update stays inside the project"
pc="$work/pc"
mkdir -p "$pc"
cli "$pc/base" "${sample[@]}" > "$work/pc.log" 2>&1 || { cat "$work/pc.log"; fail "update path test: create fails"; }
# refused <case> <text>: the update of $pc/<case> fails, its message names <text>, and the project
# has no change.
refused() {
  (cd "$pc/$1" && cli update --defaults > "$work/pc-$1.log" 2>&1) && { fail "update path test: $1: the update runs"; return; }
  grep -q -F -- "$2" "$work/pc-$1.log" || { cat "$work/pc-$1.log"; fail "update path test: $1: the message does not name $2"; }
  [ -z "$(git -C "$pc/$1" status --porcelain)" ] || { git -C "$pc/$1" status --short | head; fail "update path test: $1: the refused update changed the project"; }
}
# A ../ entry names a file in a directory of its own: removing it would prune that directory too.
cp -R "$pc/base" "$pc/up" && mkdir -p "$pc/out-up/a" && echo keep > "$pc/out-up/a/only.txt"
echo '../out-up/a/only.txt' >> "$pc/up/.template/owned.txt" && gitc "$pc/up" commit -q -am "an entry outside"
refused up '../out-up/a/only.txt'
[ -f "$pc/out-up/a/only.txt" ] || fail "update path test: a ../ entry of .template/owned.txt deletes a file outside the project"
[ -d "$pc/out-up/a" ] || fail "update path test: the pruning of empty directories leaves the project"

cp -R "$pc/base" "$pc/abs" && echo keep > "$pc/out-abs.txt"
echo "$pc/out-abs.txt" >> "$pc/abs/.template/owned.txt" && gitc "$pc/abs" commit -q -am "an absolute entry"
refused abs "$pc/out-abs.txt"
[ -f "$pc/out-abs.txt" ] || fail "update path test: an absolute entry of .template/owned.txt deletes a file outside the project"

# A symbolic link as a parent directory: of a file to remove, and of template-owned files to write.
cp -R "$pc/base" "$pc/link" && mkdir -p "$pc/out-link" && echo keep > "$pc/out-link/only.txt"
ln -s "$pc/out-link" "$pc/link/gone" && echo 'gone/only.txt' >> "$pc/link/.template/owned.txt" &&
  gitc "$pc/link" add -A && gitc "$pc/link" commit -q -m "an entry through a link"
refused link 'gone/only.txt'
[ -f "$pc/out-link/only.txt" ] || fail "update path test: the update deletes through a symbolic link"
cp -R "$pc/base" "$pc/rules" && mv "$pc/rules/.claude/rules" "$pc/out-rules" && echo keep > "$pc/out-rules/docs.md" &&
  ln -s "$pc/out-rules" "$pc/rules/.claude/rules" && gitc "$pc/rules" add -A && gitc "$pc/rules" commit -q -m "rules through a link"
refused rules '.claude/rules'
[ "$(cat "$pc/out-rules/docs.md")" = keep ] || fail "update path test: the update writes through a symbolic link of a parent directory"

# A symbolic link at a template-owned file: writing and chmod would follow it.
cp -R "$pc/base" "$pc/target" && echo keep > "$pc/out-target.txt" && chmod 644 "$pc/out-target.txt" &&
  ln -s -f "$pc/out-target.txt" "$pc/target/scripts/lib/stamp.sh" && gitc "$pc/target" commit -q -am "a template-owned file as a link"
refused target 'scripts/lib/stamp.sh'
[ "$(cat "$pc/out-target.txt")" = keep ] && [ ! -x "$pc/out-target.txt" ] ||
  fail "update path test: the update writes or changes the mode of a file through a symbolic link"

# A seeded file that is a symbolic link, such as CLAUDE.md to AGENTS.md, stays and is no reason to refuse.
cp -R "$pc/base" "$pc/seed" && ln -s -f AGENTS.md "$pc/seed/CLAUDE.md" && gitc "$pc/seed" commit -q -am "CLAUDE.md as a link"
(cd "$pc/seed" && cli update --defaults > "$work/pc-seed.log" 2>&1) || { cat "$work/pc-seed.log"; fail "update path test: a seeded file as a symbolic link stops the update"; }
[ -L "$pc/seed/CLAUDE.md" ] || fail "update path test: the update replaces a seeded symbolic link"
