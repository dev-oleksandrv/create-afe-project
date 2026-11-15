# The generated Claude Code settings: the Read deny rules cover every .env file but
# .env.example, so afe-init needs no `remove` entry that would open them all. Needs $a from
# 10-variant-a.sh.
# Claude Code reads Read rules with gitignore syntax, a `!` rule carving out of the rules listed
# before it (https://code.claude.com/docs/en/permissions); git check-ignore applies that syntax to
# the rules in their order.
echo "== settings: the Read deny rules cover every .env file but .env.example"
envd="$work/env-rules"
git init -q "$envd"
(cd "$a" && node -e 'for (const r of JSON.parse(require("fs").readFileSync(".claude/settings.json", "utf8")).permissions.deny) {
  const m = /^Read\((.*)\)$/.exec(r); if (m) console.log(m[1]); }') > "$envd/.gitignore"
for p in .env .env.local .env.production .env.a-variant-on-no-list app/.env.staging; do
  git -C "$envd" check-ignore -q --no-index "$p" || fail "settings: the Read deny rules do not cover $p"
done
for p in .env.example app/.env.example; do
  ! git -C "$envd" check-ignore -q --no-index "$p" || fail "settings: the Read deny rules cover $p, the file afe-init writes"
done
! grep -n -F -e 'remove` key' -e 'out of the deny list' "$a/.claude/skills/afe-init/SKILL.md" ||
  fail "afe-init still takes a Read rule out of the deny list"
