#!/bin/zsh
# The one quality gate: static audit, docs up to date, logic tests + life simulator, iOS compile. Short output, exit 1 on any problem.
# Usage: zsh Tools/check.sh          fast (1 simulated life per scenario), run before every commit (the Git hook does it)
#        zsh Tools/check.sh deep     8 lives per scenario + the real data of the iPhone (bug hunt, /chasse)
root="${0:A:h:h}"
cd "$root"
fail=0
step() { print -P "%B== $1%b" }

# Each expensive step (the two logic passes, the iOS compile) is skipped when its inputs are byte-identical to the last run that
# passed (same day: the simulator reads the clock). The Git hook right after a green check, or a change that only touches docs,
# tests or one side of the code, therefore costs seconds. `deep` never reads nor writes the logic cache.
cache=Tools/.data/check-cache; mkdir -p "$cache"
digest() { { for p in "$@"; do [[ -e $p ]] && find "$p" -type f -not -path '*/.build*' -not -path '*/Sources/HexisLogic/*' -not -name .DS_Store -print0; done } \
  | sort -z | xargs -0 shasum 2>/dev/null | shasum | cut -c1-16; }
cached() { [[ -f "$cache/$1" && "$(<"$cache/$1")" == "$2" ]] }
day=$(date +%F)
logicKey="$day $(digest Hexis/Models Hexis/Services Hexis/App/Edition.swift Hexis/Features/Workout Hexis/Resources HexisElle/Program.json HexisElle/HevyHistory.json HexisShared Tools/LogicTests Tools/logic_tests.sh Tools/check.sh Tools/.data/latest.json Tools/.data/her-latest.json)"
buildKey="$(digest Hexis HexisElle HexisShared HexisWidgets Hexis.xcodeproj)"

# The iOS compile runs alongside the tests (about half the time).
build=$(mktemp)
buildpid=""
if ! cached build "$buildKey"; then
  # Both apps (Hexis and Hexis Elle, same code): one after the other, they share the derived data.
  ( for scheme in Hexis HexisElle; do
      xcodebuild -project Hexis.xcodeproj -scheme $scheme -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath ~/Library/Developer/Xcode/DerivedData/Hexis-cli build 2>&1 || exit 1
    done ) >"$build" 2>&1 &
  buildpid=$!
fi

step "audit"
python3 Tools/audit.py || fail=1

step "doc"
python3 Tools/doc.py --check || fail=1
python3 Tools/exercise_library.py --check || fail=1

seeds=1; [[ "$1" == deep ]] && seeds=8
# One pass per app: his (Hexis), then hers compiled as « Hexis Elle » (flag ELLE: her program, her rules, her lives, no food).
# The last backup of each iPhone (if any) rides along: RealDataTests writes what each will see, diffed below.
logic() { # $1 label, $2 edition, $3 backup, $4 seen file, then swift test arguments
  local label=$1 edition=$2 backup=$3 seen=$4; shift 4
  step "logique + simulateur de vie ($label)"
  local key="logic-${edition:-hexis}"
  if [[ "$deep" != 1 ]] && cached "$key" "$logicKey"; then print "  inchangé depuis le dernier vert (cache)"; return; fi
  rm -f "$seen"
  local data=(); [[ -f "$backup" ]] && data=(HEXIS_DATA="$root/$backup" HEXIS_SEEN="$root/$seen")
  local out=$(env $data HEXIS_EDITION=$edition HEXIS_SEEDS=$seeds LINES_MAX=600 zsh Tools/logic_tests.sh "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
  # Simulated lives: one line each only in deep mode or on failure (they cost tokens on every green run).
  [[ "$deep" == 1 ]] && print -r -- "$out" | grep -E "^life ·" | sed 's/^life · /  /'
  if print -r -- "$out" | grep -qE "✘|error:"; then
    [[ "$deep" == 1 ]] || print -r -- "$out" | grep -E "^life ·" | sed 's/^life · /  /'
    print -r -- "$out" | grep -E "error:|✘ Test .*recorded|Expectation failed|^↳|^    " | grep -v "^↳ ///" | head -60
    fail=1; rm -f "$cache/$key"
  else
    print -r -- "$out" | grep -E "Test run with" | tail -1
    [[ "$deep" == 1 ]] || print -r -- "$logicKey" >"$cache/$key"
  fi
}
# What changes on the iPhone screens with this code (same backup, same moment): to say it before the user finds it.
seen_diff() { # $1 label, $2 seen file, $3 reference of the last green run
  [[ -f "$2" ]] || return
  step "ce que $1 verra (changé depuis le dernier vert)"
  if [[ -f "$3" ]]; then
    local changes=$(diff "$3" "$2" | grep -E "^[<>]" | sed 's/^</  avant :/; s/^>/  après :/')
    [[ -n "$changes" ]] && print -r -- "$changes" | head -30 || print "  rien"
  else
    print "  (première fois : référence posée)"
  fi
}
deep=0; [[ "$1" == deep ]] && deep=1
logic "Hexis" "" Tools/.data/latest.json Tools/.data/seen.txt
logic "Hexis Elle" elle Tools/.data/her-latest.json Tools/.data/her-seen.txt --skip Nutrition
seen_diff "l'utilisateur" Tools/.data/seen.txt Tools/.data/seen-last.txt
seen_diff "elle" Tools/.data/her-seen.txt Tools/.data/her-seen-last.txt

if [[ "$1" == deep ]]; then
  for who in "" elle; do
    [[ -n "$who" && ! -s Tools/.data/her-device ]] && continue
    step "données réelles (iPhone${who:+ d'elle})"
    data=$(zsh Tools/data_check.sh $who 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    print -r -- "$data" | grep -E "sauvegarde|séances|introuvable|aucune|impossible|Données|^    " | head -40
    print -r -- "$data" | grep -q "✘" && fail=1
  done
fi

step "compilation iOS"
if [[ -z "$buildpid" ]]; then
  print "  inchangée depuis le dernier vert (cache)"
elif wait $buildpid; then
  grep -E "error:|BUILD" "$build" | sort -u | head -20
  print -r -- "$buildKey" >"$cache/build"
else
  fail=1; rm -f "$cache/build"
  grep -E "error:|BUILD" "$build" | sort -u | head -20
fi
rm -f "$build"
# Each app must carry its icon (a build without it shows a blank logo on its notifications and home screen).
for app in Hexis HexisElle; do
  plist=$(ls -t ~/Library/Developer/Xcode/DerivedData/Hexis-cli/Build/Products/*-iphonesimulator/$app.app/Info.plist 2>/dev/null | head -1)
  [[ -n "$plist" ]] && ! plutil -extract CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName raw "$plist" >/dev/null 2>&1 \
    && { print "icône absente de $app.app"; fail=1 }
done

(( fail )) || for who in seen her-seen; do [[ -f Tools/.data/$who.txt ]] && cp Tools/.data/$who.txt Tools/.data/$who-last.txt; done
(( fail )) && print -P "%F{red}%BÉCHEC%b%f" || print -P "%F{green}%BOK%b%f"
exit $fail
