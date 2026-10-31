#!/bin/zsh
# Start of a conversation in one call (CLAUDE.md « Démarrer »): next action, backlog titles, last commits, daily report verdict,
# pending hunt branch. Short on purpose: everything else is read only when the task needs it.
root="${0:A:h:h}"
cd "$root" || exit 1
print "== Prochaine action"
awk '/^## Prochaine action/{on=1;next} /^## /{on=0} on && NF' ROADMAP.md | cut -c1-400
print "== À faire"
awk '/^## À faire/{on=1;next} /^## /{on=0} on && /^[0-9]/' ROADMAP.md | cut -c1-110
print "== Commits"
git log --oneline -8 | cut -c1-110
print "== Rapport"
report=Tools/.data/report.md
if [[ -f $report ]]; then
  sed -n "1p;3p" $report
  grep -E "^- .*(✘|À CORRIGER|problème|Accueil a montré)" $report | head -10
else
  print "pas de rapport"
fi
for b in $(git branch --list 'chasse/*' --format='%(refname:short)'); do
  n=$(git rev-list --count main..$b)
  (( n )) && print "branche $b : $n commit(s) à relire puis git merge --ff-only $b"
done
[[ -n "$(git status --porcelain)" ]] && print "== Non commité" && git status --short | head -10
