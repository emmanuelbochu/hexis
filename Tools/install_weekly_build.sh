#!/bin/zsh
# Installs (or reinstalls) the launchd job (checks every 10 min) that keeps Hexis fresh on the iPhone. Safe to run again.
set -e
ROOT="${0:A:h:h}"
LABEL="com.example.hexis.build"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/usr/bin/python3</string><string>$ROOT/Tools/weekly_build.py</string></array>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
  <key>Nice</key><integer>10</integer>
  <key>EnvironmentVariables</key><dict><key>PATH</key><string>/usr/bin:/bin:/usr/sbin:/sbin:/Applications/Xcode.app/Contents/Developer/usr/bin</string></dict>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/HexisBuild.err</string>
</dict></plist>
PLIST
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed: checks every 10 min, builds at a good moment for new commits (settled 20 min, at most every 6 h) and once the last install is 3+ days old. Log: ~/Library/Logs/HexisBuild.log"
