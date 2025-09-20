#!/bin/bash
# =============================
# Deep Error Management x-ui Manager
# Non-systemd, auto-install, auto-debug
# =============================

XUI_BIN_DIR="/usr/local/x-ui"
BIN_DIR="$XUI_BIN_DIR/bin"
CONFIG_FILE="$BIN_DIR/config.json"
LOG_FILE="/var/log/x-ui.log"
PID_FILE="/var/run/x-ui.pid"
CHECK_INTERVAL=10

# ===== Functions =====
install_dependencies() {
    echo "📦 Installing dependencies..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y wget curl git unzip lsof
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y wget curl git unzip lsof
    fi
}

cleanup_old_xui() {
    echo "🗑 Cleaning old x-ui..."
    pkill -f $XUI_BIN_DIR/x-ui 2>/dev/null
    rm -f "$PID_FILE"
    rm -rf "$XUI_BIN_DIR"
}

download_xui() {
    echo "🚀 Downloading x-ui..."
    mkdir -p $XUI_BIN_DIR
    cd /tmp || exit
    wget -O x-ui-install.sh https://raw.githubusercontent.com/sprov065/x-ui/master/install.sh
    chmod +x x-ui-install.sh
    bash x-ui-install.sh
}

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
        echo "✅ config.json created"
    fi
}

start_xui() {
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        return
    fi
    nohup $XUI_BIN_DIR/x-ui > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "🟢 x-ui started (PID $(cat "$PID_FILE"))"
}

deep_error_analysis() {
    echo "🔍 Deep log error analysis:"
    recent_lines=$(tail -n 50 "$LOG_FILE")
    
    # Check for missing config
    if echo "$recent_lines" | grep -iq "config.json"; then
        echo "⚠️ Detected missing config.json"
        setup_xray_config
    fi

    # Check for port in use
    if echo "$recent_lines" | grep -iq "bind: address already in use"; then
        echo "⚠️ Port conflict detected!"
        conflicting_port=$(echo "$recent_lines" | grep -i "bind: address already in use" | grep -oE "[0-9]+")
        echo "🔧 Killing process using port $conflicting_port"
        pid=$(lsof -ti:$conflicting_port)
        if [ ! -z "$pid" ]; then
            kill -9 $pid
            echo "✅ Process $pid killed"
        fi
    fi

    # Check for permission errors
    if echo "$recent_lines" | grep -iq "permission denied"; then
        echo "⚠️ Detected permission issues"
        chmod 600 "$CONFIG_FILE"
        chown root:root "$CONFIG_FILE"
        echo "✅ Permissions fixed for config.json"
    fi

    # General ERROR/WARNING
    errors=$(echo "$recent_lines" | grep -iE "error|failed|warning")
    if [ ! -z "$errors" ]; then
        echo "❌ Recent errors/warnings:"
        echo "$errors"
    else
        echo "✅ No critical errors detected"
    fi
}

log_rotation() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $((10*1024*1024)) ]; then
        mv "$LOG_FILE" "$LOG_FILE.$(date +%F-%T)"
        touch "$LOG_FILE"
        echo "📜 Log rotated"
    fi
}

# ===== Main Loop =====
install_dependencies
cleanup_old_xui
download_xui
start_xui

echo "✅ x-ui running. Logs: $LOG_FILE"

while true; do
    deep_error_analysis
    if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "⚠️ x-ui crashed, restarting..."
        start_xui
    fi
    log_rotation
    sleep $CHECK_INTERVAL
done
