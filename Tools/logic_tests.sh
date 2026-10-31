#!/bin/zsh
# Runs the logic tests: links the app's Models and platform-free Services into a macOS package and runs `swift test`.
# HEXIS_EDITION=elle compiles them as « Hexis Elle » (flag ELLE, own build folder): her program, her rules, her lives.
set -e
root="${0:A:h:h}"
pkg="$root/Tools/LogicTests"
src="$pkg/Sources/HexisLogic"
rm -rf "$src" && mkdir -p "$src"
# Services bound to iOS-only frameworks are skipped; sound, notifications and Live Activity are stubbed (Stubs/), so the
# real workout view model runs too (the life simulator drives it like a thumb would).
skip=(AutoBackup MetricsReporter LocationService NotificationService ProfileExpiry ReceiptOCR ReceiptParser RestActivity SoundService)
for f in "$root"/Hexis/Models/*.swift "$root"/Hexis/Models/Schema/*.swift "$root"/Hexis/Services/*.swift \
         "$root"/Hexis/App/Edition.swift "$root"/Hexis/Features/Workout/WorkoutViewModel*.swift "$pkg"/Stubs/*.swift; do
  name="${f:t:r}"
  [[ " ${skip[*]} " == *" $name "* ]] && continue
  ln -s "$f" "$src/${f:t}"
done
edition=(); [[ "$HEXIS_EDITION" == elle ]] && edition=(-Xswiftc -DELLE --scratch-path "$pkg/.build-elle")
cd "$pkg" && swift test $edition "$@" 2>&1 | grep -vE "^\[|Compiling|Build|Planning|warning:|note:|^.{250}" | tail -${LINES_MAX:-60}
