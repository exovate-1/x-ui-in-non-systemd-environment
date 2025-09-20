#!/bin/bash
# =============================
# Robust x-ui Manager (Non-systemd)
# - Fully self-contained
# - Cleans old installations
# - Auto-install dependencies
# - Auto-debug and auto-restart
# - Log rotation included
# =============================

# ===== CONFIG =====
XUI_BIN_DIR="/usr/local/x-ui"
LOG_FILE="/var/log/x-ui.log"
PID_FILE="/var/run/x-ui.pid"
CHECK_INTERVAL=60  # in seconds, interval to check and auto-restart

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
        echo "⚠️ Unknown package manager. Make sure wget, git, curl installed."
    fi
}

cleanup_old_xui() {
    echo "🗑 Removing old x-ui installation..."
    if [ -d "$XUI_BIN_DIR" ]; then
        sudo /etc/init.d/x-ui stop 2>/dev/null || true
        sudo rm -rf "$XUI_BIN_DIR"
        sudo rm -f /etc/init.d/x-ui
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

create_service() {
    echo "🛠 Setting up non-systemd service..."
    sudo tee /etc/init.d/x-ui >/dev/null <<EOF
#!/bin/sh
XUI_BIN="$XUI_BIN_DIR/x-ui"
PID_FILE="$PID_FILE"
LOG_FILE="$LOG_FILE"

start() {
    echo "Starting x-ui..."
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "x-ui already running with PID \$(cat \$PID_FILE)"
        return 1
    fi
    nohup \$XUI_BIN >> "\$LOG_FILE" 2>&1 &
    echo \$! > \$PID_FILE
    echo "x-ui started with PID \$(cat \$PID_FILE)"
}

stop() {
    echo "Stopping x-ui..."
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        kill \$(cat \$PID_FILE)
        rm -f \$PID_FILE
        echo "x-ui stopped."
    else
        echo "x-ui not running."
    fi
}

status() {
    if [ -f "\$PID_FILE" ] && kill -0 \$(cat "\$PID_FILE") 2>/dev/null; then
        echo "x-ui running with PID \$(cat \$PID_FILE)"
    else
        echo "x-ui not running"
    fi
}

restart() {
    stop
    start
}

case "\$1" in
    start|stop|status|restart)
        \$1
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|restart}"
        exit 1
        ;;
esac
EOF

    sudo chmod +x /etc/init.d/x-ui
}

auto_debug() {
    echo "🔍 Checking x-ui status..."
    # Reinstall if binary missing
    if [ ! -f "$XUI_BIN_DIR/x-ui" ]; then
        echo "❌ x-ui binary missing, reinstalling..."
        install_xui
    fi

    # Start if not running
    if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat $PID_FILE) 2>/dev/null; then
        echo "⚠️ x-ui not running, starting service..."
        sudo /etc/init.d/x-ui start
    fi
}

log_rotation() {
    # Rotate logs if > 10MB
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
create_service
auto_debug

echo "✅ x-ui fully installed, managed, and running!"
echo "Manage x-ui with: sudo /etc/init.d/x-ui {start|stop|restart|status}"
echo "Starting auto-restart monitor..."

# Start auto-restart loop in the background
auto_restart_loop
