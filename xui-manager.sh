#!/bin/bash
# =============================
# x-ui Debug Monitor (Non-systemd)
# - Shows x-ui and xray logs live
# - Shows process status
# - Auto-restarts x-ui/xray if crashed
# =============================

XUI_BIN_DIR="/usr/local/x-ui"
BIN_DIR="$XUI_BIN_DIR/bin"
CONFIG_FILE="$BIN_DIR/config.json"
LOG_FILE="/var/log/x-ui.log"
PID_FILE="/var/run/x-ui.pid"
CHECK_INTERVAL=10  # seconds

# ===== FUNCTIONS =====

# Check and create default xray config
setup_xray_config() {
    mkdir -p "$BIN_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "⚠️ Missing config.json, creating default..."
        cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
        chmod 600 "$CONFIG_FILE"
        chown root:root "$CONFIG_FILE"
        echo "✅ Default config.json created"
    fi
}

# Start x-ui directly
start_xui() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        return
    fi
    nohup $XUI_BIN_DIR/x-ui > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "🟢 x-ui started with PID $(cat $PID_FILE)"
}

# Check status
check_status() {
    echo "=============================="
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "✅ x-ui running (PID $(cat $PID_FILE))"
    else
        echo "❌ x-ui not running, restarting..."
        start_xui
    fi

    if [ -f "$CONFIG_FILE" ]; then
        echo "📂 xray config: exists"
    else
        echo "⚠️ xray config: missing"
    fi
    echo "=============================="
}

# Tail log file
tail_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi
    tail -n 20 -f "$LOG_FILE" &
    TAIL_PID=$!
}

# ===== MAIN =====
setup_xray_config
start_xui
tail_logs

# Continuous debug loop
while true; do
    clear
    echo "📊 x-ui Debug Monitor"
    check_status
    echo "📝 Showing last 20 lines of x-ui log:"
    tail -n 20 "$LOG_FILE"
    echo "🔁 Auto-refresh in $CHECK_INTERVAL seconds..."
    sleep $CHECK_INTERVAL
done
