#!/bin/bash

# 기본값 세팅
LABEL="com.user.launchdjob"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/$LABEL.plist"
SCRIPT_PATH="$(pwd)/go.sh"  # 현재 위치한 go.sh 기준
LOG_DIR="$HOME/Library/Logs"
GREPPED=""
INTERVAL=0
WATCH_MODE=false
RUNATLOAD=false

# 로그용 폴더
mkdir -p "$LOG_DIR"

# 파라미터 파싱
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --runatload) RUNATLOAD=true ;;
    --interval) INTERVAL="$2"; shift ;;
    --watch) GREPPED="$2"; WATCH_MODE=true; shift ;;
    *) echo "❌ Unknown parameter: $1"; exit 1 ;;
  esac
  shift
done

# 1. Watch mode만 실행할 경우: 실행 중 아니면 실행
if $WATCH_MODE && [ "$RUNATLOAD" = false ] && [ "$INTERVAL" = 0 ]; then
  if pgrep -f "$GREPPED" > /dev/null; then
    echo "✅ '$GREPPED' is already running."
  else
    echo "⚠️ '$GREPPED' is not running. Starting $SCRIPT_PATH..."
    /bin/bash "$SCRIPT_PATH"
  fi
  exit 0
fi

# 2. launchd plist 생성
mkdir -p "$PLIST_DIR"

cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT_PATH</string>
  </array>

  $( $RUNATLOAD && echo "<key>RunAtLoad</key><true/>" )

  $( [ "$INTERVAL" -gt 0 ] && echo "<key>StartInterval</key><integer>$INTERVAL</integer>" )

  <key>StandardOutPath</key>
  <string>$LOG_DIR/$LABEL.out</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/$LABEL.err</string>
</dict>
</plist>
EOF

# 3. launchctl 등록
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "✅ launchd job '$LABEL' registered at $PLIST_PATH"
$RUNATLOAD && echo "  • Will run at boot/login"
[ "$INTERVAL" -gt 0 ] && echo "  • Will repeat every $INTERVAL seconds"
$WATCH_MODE && echo "  • Watch mode: use this script with --watch \"$GREPPED\" to check running status"
