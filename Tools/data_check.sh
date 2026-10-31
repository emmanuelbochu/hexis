#!/bin/zsh
# Fetches the latest automatic backup from the iPhone (cable or Wi-Fi, read only) and runs the checks on the real history,
# then prints the next session of each template as the app would prefill it. The file stays in Tools/.data (ignored by Git).
# Usage: zsh Tools/data_check.sh [backup.json]        his iPhone (never hers): the newest hexis-auto-*.json of Hexis
#        zsh Tools/data_check.sh elle [backup.json]   her iPhone (Tools/.data/her-device): Hexis Elle, checked as her app
root="${0:A:h:h}"
dir="$root/Tools/.data"
mkdir -p "$dir"
her=""; [[ -s "$dir/her-device" ]] && her=$(<"$dir/her-device")
if [[ "$1" == elle ]]; then
  shift
  edition=elle; bundle=com.example.Hexis.Elle; out="$dir/her-latest.json"; device="$her"
  [[ -z "$device" && -z "$1" ]] && { echo "son iPhone n'est pas choisi : zsh Tools/her_phone.sh pair"; exit 1; }
else
  edition=""; bundle=com.example.Hexis; out="$dir/latest.json"
  device=$(xcrun devicectl list devices 2>/dev/null | grep -E "connected|available" | grep -vi "${her:-^$}" \
    | grep -oE "[0-9A-F]{8}-[0-9A-F]{16}|[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}" | head -1)
fi
file="$1"
if [[ -z "$file" ]]; then
  [[ -z "$device" ]] && { echo "iPhone introuvable : le brancher (ou Wi-Fi) puis relancer"; exit 1; }
  args=(--device "$device" --domain-type appDataContainer --domain-identifier $bundle)
  name=$(xcrun devicectl device info files $args --subdirectory Documents 2>/dev/null | grep -oE "hexis-auto-[0-9T-]+\.json" | sort | tail -1)
  [[ -z "$name" ]] && { echo "aucune sauvegarde auto sur l'iPhone"; exit 1; }
  xcrun devicectl device copy from $args --source "Documents/$name" --destination "$out" >/dev/null 2>&1 \
    || { echo "copie de $name impossible"; exit 1; }
  file="$out"
  echo "sauvegarde : $name"
fi
HEXIS_EDITION=$edition HEXIS_DATA="${file:A}" LINES_MAX=${LINES_MAX:-80} zsh "$root/Tools/logic_tests.sh" --filter RealDataTests \
  | grep -vE "^(◇|↳ /// )" | sed 's/^data · //'
