#!/bin/zsh
# Her iPhone, by hand (the launchd job of weekly_build.py already reinstalls Hexis Elle on it before the 7 days run out, and
# reads her backup into the daily report, whenever it answers on the Mac's Wi-Fi). Never touches the other phone.
# Usage: zsh Tools/her_phone.sh pair      lists the connected devices; pick hers with: echo <Identifier> > Tools/.data/her-device
#        zsh Tools/her_phone.sh           builds Release, installs it now, then checks her real data (data_check.sh elle)
root="${0:A:h:h}"; cd "$root"
file="Tools/.data/her-device"
mkdir -p Tools/.data

if [[ "$1" == pair ]]; then
  xcrun devicectl list devices; print "\nThen: echo <Identifier of her iPhone> > $file"; exit 0
fi
[[ -s "$file" ]] || { print "Pas de téléphone choisi : zsh Tools/her_phone.sh pair"; exit 1 }
udid=$(<"$file")
xcrun devicectl list devices 2>/dev/null | grep -i "$udid" | grep -qE "connected|available" || { print "Son téléphone n'est pas connecté."; exit 1 }
xcodebuild -project Hexis.xcodeproj -scheme HexisElle -configuration Release -destination "id=$udid" \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/HexisElle-device -allowProvisioningUpdates build 2>&1 \
  | grep -E "error:|BUILD" | sort -u
app=~/Library/Developer/Xcode/DerivedData/HexisElle-device/Build/Products/Release-iphoneos/HexisElle.app
[[ -d "$app" ]] || exit 1
xcrun devicectl device install app --device "$udid" "$app" >/dev/null && print "Installé sur son téléphone." || exit 1
# The automatic job counts from this install too.
state=~/Library/Application\ Support/HexisBuild; mkdir -p "$state"; date +%s > "$state/her_last_success"
zsh Tools/data_check.sh elle
