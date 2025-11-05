#!/bin/bash
# VNC Lab Desktop Startup Script
# Launches VNC server (MATE Desktop) and websockify proxy for browser-based desktop access
# MATE: Polished desktop environment, memory-efficient (~220Mi idle)

set -e

echo "==========================================="
echo "VNC Lab Desktop with MATE Starting..."
echo "==========================================="

# Configure VNC password from environment variable (if provided)
# Otherwise use default password
VNC_PASSWORD="${VNC_PASSWORD:-password}"
echo "Configuring VNC password from environment..."
mkdir -p ~/.vnc
echo "$VNC_PASSWORD" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

# Set display resolution from environment variables
RESOLUTION="${VNC_RESOLUTION:-1280x720}"
DEPTH="${VNC_DEPTH:-16}"
# TigerVNC uses 5900 + display number, so display :1 = port 5901
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

echo "Configuration:"
echo "  Display: $DISPLAY"
echo "  Resolution: $RESOLUTION"
echo "  Color Depth: $DEPTH bits"
echo "  Desktop: MATE"
echo "  VNC Port: $VNC_PORT"
echo "  noVNC Port: $NOVNC_PORT"
echo ""

# Clean up any existing VNC locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1

# Disable keyring password prompts for this session
export GNOME_KEYRING_CONTROL=
export GNOME_KEYRING_PID=

# Start VNC server
echo "Starting VNC server with MATE desktop..."
vncserver $DISPLAY \
    -geometry $RESOLUTION \
    -depth $DEPTH \
    -localhost no \
    -SecurityTypes VncAuth \
    2>&1 | tee ~/.vnc/vncserver.log

# Wait for VNC server to be ready
echo "Waiting for VNC server to start..."
for i in {1..10}; do
    if [ -S /tmp/.X11-unix/X1 ]; then
        echo "VNC server started successfully!"
        break
    fi
    if [ $i -eq 10 ]; then
        echo "ERROR: VNC server failed to start"
        cat ~/.vnc/*.log
        exit 1
    fi
    sleep 1
done

# Display VNC server info
echo ""
echo "VNC Server Details:"
vncserver -list || true
echo ""

# Start websockify proxy (WebSocket to VNC bridge)
echo "Starting websockify (WebSocket-to-VNC bridge)..."
echo "  Listening on: 0.0.0.0:$NOVNC_PORT"
echo "  Proxying to: localhost:$VNC_PORT"
echo ""

# Run websockify in foreground (keeps container alive)
# The --web option serves noVNC client files if available
# For MVP, we'll skip --web and let frontend handle noVNC client
exec websockify \
    --verbose \
    0.0.0.0:$NOVNC_PORT \
    localhost:$VNC_PORT

# Note: This script runs in foreground. When websockify exits, container stops.
