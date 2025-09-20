#!/bin/bash
# ========================================
# x-ui English Manager v2.0 (Non-systemd)
# Fully patched, deep error handling, wget download
# ========================================

XUI_DIR="/usr/local/x-ui-english"
BIN_DIR="$XUI_DIR/bin"
CONFIG_FILE="$BIN_DIR/config.json"
LOG_FILE="/var/log/x-ui.log"
PID_FILE="/var/run/x-ui.pid"
CHECK_INTERVAL=10

# ===== Functions =====

install_dependencies() {
    echo "📦 Installing dependencies..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y wget curl unzip lsof
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y wget curl unzip lsof
    fi
}

cleanup_old_xui() {
    echo "🗑 Cleaning previous installation..."
    pkill -f "$XUI_DIR/x-ui" 2>/dev/null
    rm -f "$PID_FILE"
    rm -rf "$XUI_DIR"
}

download_xui() {
    echo "🚀 Downloading English x-ui..."
    mkdir -p "$XUI_DIR"
    cd /tmp || exit
    # Download tarball and extract
    wget -qO- https://github.com/NidukaAkalanka/x-ui-english/archive/refs/heads/master.tar.gz | tar xz
    cp -r x-ui-english-master/* "$XUI_DIR"
}

patch_xui_for_non_systemd() {
    echo "🛠 Patching x-ui for non-systemd..."
    cd "$XUI_DIR" || exit

    # Backup original binary/script
    [ -f x-ui.backup ] || cp x-ui x-ui.backup

    # Remove systemd references
    sed -i 's/systemctl start x-ui/nohup .\/x-ui \&/g' x-ui 2>/dev/null
    sed -i 's/systemctl stop x-ui/kill $(cat \/var\/run\/x-ui.pid)/g' x-ui 2>/dev/null
    sed -i 's/systemctl status x-ui/ps aux | grep x-ui/g' x-ui 2>/dev/null
}

setup_xray_config() {
    echo "⚙️ Ensuring bin/config.json exists..."
    mkdir -p "$BIN_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" <<EOF
{
  "language": "en",
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
    cd "$XUI_DIR" || exit
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        return
    fi
    LANG=en_US.UTF-8 LANGUAGE=en_US LC_ALL=en_US.UTF-8 nohup ./x-ui > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "🟢 x-ui started (PID $(cat "$PID_FILE")) in English"
}

deep_error_analysis() {
    echo "🔍 Deep log analysis..."
    recent_lines=$(tail -n 50 "$LOG_FILE")

    # Missing config.json
    if echo "$recent_lines" | grep -iq "config.json"; then
        echo "⚠️ Missing config.json detected, recreating..."
        setup_xray_config
    fi

    # Port conflicts
    if echo "$recent_lines" | grep -iq "address already in use"; then
        port=$(echo "$recent_lines" | grep -i "address already in use" | grep -oE "[0-9]+")
        echo "⚠️ Port $port conflict! Killing conflicting process..."
        pid=$(lsof -ti:$port)
        [ ! -z "$pid" ] && kill -9 $pid && echo "✅ Killed process $pid"
    fi

    # Permissions
    if echo "$recent_lines" | grep -iq "permission denied"; then
        echo "⚠️ Permission issue detected, fixing..."
        chmod 600 "$CONFIG_FILE"
        chown root:root "$CONFIG_FILE"
        echo "✅ Permissions fixed"
    fi

    # General errors
    errors=$(echo "$recent_lines" | grep -iE "error|failed|warning")
    [ ! -z "$errors" ] && echo -e "❌ Recent errors:\n$errors"
}

log_rotation() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $((10*1024*1024)) ]; then
        mv "$LOG_FILE" "$LOG_FILE.$(date +%F-%T)"
        touch "$LOG_FILE"
        echo "📜 Log rotated"
    fi
}

# ===== Main =====
install_dependencies
cleanup_old_xui
download_xui
patch_xui_for_non_systemd
setup_xray_config
start_xui

echo "✅ English x-ui fully installed and patched for non-systemd"
echo "Logs: $LOG_FILE"
echo "PID: $(cat "$PID_FILE")"

# ===== Continuous monitoring loop =====
while true; do
    deep_error_analysis
    if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "⚠️ x-ui crashed, restarting..."
        start_xui
    fi
    log_rotation
    sleep $CHECK_INTERVAL
done
