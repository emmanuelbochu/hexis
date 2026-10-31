#!/bin/zsh
# Clean public snapshot of the project, without Git history and without personal data. Never pushes anything.
# Usage: zsh Tools/publish.sh <new-or-empty-folder>      Rules: Tools/publish_redact.txt (private, ignored by Git; see the .example)
exec python3 "${0:A:h}/publish.py" "$@"
