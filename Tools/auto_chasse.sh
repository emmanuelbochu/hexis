#!/bin/zsh
# Automatic bug hunt: Claude runs /chasse alone, on its own branch in a separate worktree, never on main and never pushed.
# Started by weekly_build.py when the report says À CORRIGER, or after enough new sessions or commits (see chasse_due there).
# The result (branch, commits, last words) goes to Tools/.data/chasse.md, shown in the "Chasse" section of report.md;
# the next conversation reviews the diff and merges with `git merge --ff-only chasse/<date>` if it is good.
# Usage: zsh Tools/auto_chasse.sh        Log: ~/Library/Logs/HexisChasse.log
root="${0:A:h:h}"
cd "$root" || exit 1
day=$(date +%Y-%m-%d)
branch="chasse/$day"
tree="${root:h}/Hexis-chasse"
summary="$root/Tools/.data/chasse.md"
log="$HOME/Library/Logs/HexisChasse.log"
claude=$(command -v claude || echo "$HOME/.local/bin/claude")
[[ -x "$claude" ]] || { echo "$(date) claude introuvable" >> "$log"; exit 1; }
[[ -e "$tree" ]] && { echo "$(date) chasse déjà en cours ($tree)" >> "$log"; exit 0; }
git worktree add -q "$tree" -b "$branch" 2>>"$log" || { echo "$(date) worktree impossible" >> "$log"; exit 1; }

# Ignored files the checks need (real data, API key) are copied in, and go away with the worktree.
mkdir -p "$tree/Tools/.data"
for f in latest.json her-latest.json her-device; do [[ -f "$root/Tools/.data/$f" ]] && cp "$root/Tools/.data/$f" "$tree/Tools/.data/"; done
[[ -f "$root/Hexis/Secrets.plist" ]] && cp "$root/Hexis/Secrets.plist" "$tree/Hexis/"

cd "$tree" || exit 1
start=$(git rev-parse HEAD)
echo "$(date) chasse start $branch" >> "$log"
out=$("$claude" -p "/chasse" --model sonnet --max-turns 60 --permission-mode acceptEdits \
  --allowedTools "Bash(zsh Tools/*)" "Bash(python3 Tools/*)" "Bash(git add:*)" "Bash(git commit:*)" "Bash(git diff:*)" \
  "Bash(git log:*)" "Bash(git status:*)" "Read" "Edit" "Write" "Grep" "Glob" 2>>"$log")
code=$?
commits=$(git log --format='- %s' "$start..HEAD")
{
  echo "Chasse du $(date +%Y-%m-%d\ %H:%M), arrêt code $code."
  if [[ -n "$commits" ]]; then echo "Branche $branch à relire puis fusionner : git merge --ff-only $branch. Commits :"; echo "$commits"
  else echo "Aucun bug trouvé (aucun commit)."; fi
  echo "Derniers mots : $(print -r -- "$out" | tail -4 | tr '\n' ' ')"
} > "$summary"
cd "$root"
git worktree remove --force "$tree" >> "$log" 2>&1
# An empty hunt leaves no branch behind.
[[ -z "$commits" ]] && git branch -D "$branch" >> "$log" 2>&1
echo "$(date) chasse end code=$code" >> "$log"
