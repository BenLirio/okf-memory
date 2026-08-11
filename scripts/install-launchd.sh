#!/bin/zsh
# Install (or reinstall) the launchd agent that keeps the okf-memory server running.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
UV="$HOME/.local/bin/uv"
PLIST="$HOME/Library/LaunchAgents/com.benlirio.okf-memory.plist"
LOGDIR="$HOME/Library/Logs/okf-memory"
mkdir -p "$LOGDIR" "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.benlirio.okf-memory</string>
  <key>ProgramArguments</key>
  <array>
    <string>$UV</string>
    <string>run</string>
    <string>uvicorn</string>
    <string>app.main:app</string>
    <string>--host</string><string>127.0.0.1</string>
    <string>--port</string><string>8090</string>
  </array>
  <key>WorkingDirectory</key><string>$REPO/server</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$LOGDIR/server.log</string>
  <key>StandardErrorPath</key><string>$LOGDIR/server.err.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.benlirio.okf-memory" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "installed and started com.benlirio.okf-memory (logs: $LOGDIR)"
