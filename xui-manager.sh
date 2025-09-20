#!/bin/bash
# =============================
# Robust x-ui Manager (Non-systemd)
# - Fully self-contained
# - Cleans old installations
# - Auto-install dependencies
# - Auto-debug & auto-restart
# - Runs x-ui directly without systemd
# =============================

# ===== CONFIG =====
XUI_BIN_DIR="/usr/local/x-ui"
LOG_FILE="/var/log/x-ui.log"
PID_FILE="/var/run/x-ui.pid"
CHECK_INTERVAL=10  # seconds between auto-restart checks

# ===== FUNCTIONS =====
install_dependencies() {
    echo "📦 Installing dependencies..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y wget curl git unzip
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y wget curl git unzip
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --noconfirm wget curl git unzip
    else
        echo "⚠️ Unknown package manager. Ensure wget, git, curl installed."
    fi
}

cleanup_old_xui() {
    echo "🗑 Removing old x-ui installation..."
    if [ -d "$XUI_BIN_DIR" ]; then
        kill $(cat "$PID_FILE") 2>/dev/null || true
        sudo rm -rf "$XUI_BIN_DIR"
        sudo rm -f "$PID_FILE"
        echo "✅ Old x-ui removed."
    fi
}

install_xui() {
    echo "🚀 Installing x-ui..."
    mkdir -p $XUI_BIN_DIR
    cd /tmp || exit
    wget -O x-ui-install.sh https://raw.githubusercontent.com/sprov065/x-ui/master/install.sh
    chmod +x x-ui-install.sh
    bash x-ui-install.sh
}

start_xui_direct() {
    echo "🟢 Starting x-ui directly (no systemd)..."
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "x-ui already running with PID $(cat $PID_FILE)"
        return
    fi
    nohup $XUI_BIN_DIR/x-ui > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "x-ui started with PID $(cat $PID_FILE)"
}

stop_xui_direct() {
    echo "🔴 Stopping x-ui..."
    if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        kill $(cat "$PID_FILE")
        rm -f "$PID_FILE"
        echo "x-ui stopped."
    else
        echo "x-ui is not running."
    fi
}

auto_debug() {
    if [ ! -f "$XUI_BIN_DIR/x-ui" ]; then
        echo "❌ x-ui binary missing, reinstalling..."
        install_xui
    fi

    if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat $PID_FILE) 2>/dev/null; then
        echo "⚠️ x-ui not running, starting..."
        start_xui_direct
    fi
}

log_rotation() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $((10*1024*1024)) ]; then
        mv "$LOG_FILE" "$LOG_FILE.$(date +%F-%T)"
        touch "$LOG_FILE"
        echo "📜 Log rotated"
    fi
}

auto_restart_loop() {
    echo "🔁 Starting auto-restart monitor (Ctrl+C to stop)..."
    while true; do
        auto_debug
        log_rotation
        sleep $CHECK_INTERVAL
    done
}

# ===== MAIN =====
install_dependencies
cleanup_old_xui
install_xui
start_xui_direct

echo "✅ x-ui installed and running directly (no systemd)"
echo "Logs: $LOG_FILE"
echo "PID: $(cat $PID_FILE)"
echo "Starting auto-restart monitor..."
auto_restart_loop
