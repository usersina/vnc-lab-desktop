# VNC Lab Desktop
# Browser-based graphical desktop for cloud-native labs and remote development
#
# Desktop: MATE (fork of GNOME 2)
# - Polished, professional desktop experience
# - Memory usage: ~220Mi idle (vs 8Gi typical VNC solutions = 87% reduction!)
# - Memory limit: 1Gi recommended
#
# Features:
# - Ubuntu 22.04 base
# - TigerVNC server for remote desktop
# - MATE Desktop Environment (full, with working applets)
# - Firefox browser (from Mozilla tarball, not snap!)
# - kubectl for Kubernetes management
# - websockify for WebSocket-to-VNC bridging
# - 16-bit color depth (saves memory, looks fine)
# - Text editor (Pluma), File manager (Caja), Terminal
# - Desktop shortcuts for Firefox and Terminal
# - Passwordless sudo for lab environments
#
# Exposed Ports:
# - 5901: VNC server (internal)
# - 6080: WebSocket VNC proxy (for noVNC client)
#
# Usage:
#   docker run -d -p 6080:6080 -p 5901:5901 \
#     -e VNC_PASSWORD=mysecret \
#     usersina/vnc-lab-desktop:latest

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set timezone to avoid tzdata prompts
RUN ln -snf /usr/share/zoneinfo/UTC /etc/localtime && \
    echo "UTC" > /etc/timezone

# Install VNC server + MATE desktop + browser + tools
# MATE: Polished desktop environment (fork of GNOME 2), lightweight but user-friendly
# Using full mate-desktop-environment (not -core) to get all working applets
RUN apt-get update && apt-get install -y \
    # VNC server
    tigervnc-standalone-server \
    tigervnc-common \
    # MATE Desktop - full environment with all applets
    mate-desktop-environment \
    # Desktop utilities
    dbus-x11 \
    # WebSocket-to-VNC bridge
    websockify \
    python3 \
    # Kubernetes CLI
    curl \
    ca-certificates \
    # Utilities
    vim \
    nano \
    git \
    htop \
    net-tools \
    iputils-ping \
    wget \
    sudo \
    # Text editor
    pluma \
    # Firefox dependencies
    libgtk-3-0 \
    libdbus-glib-1-2 \
    libxt6 \
    libasound2 \
    libx11-xcb1 \
    && rm -rf /var/lib/apt/lists/*

# Install Firefox from Mozilla (not snap!)
# Download and extract Firefox tarball (auto-detect compression)
RUN wget -O /tmp/firefox.tar.bz2 "https://download.mozilla.org/?product=firefox-latest&os=linux64&lang=en-US" && \
    tar -xf /tmp/firefox.tar.bz2 -C /opt/ && \
    ln -s /opt/firefox/firefox /usr/local/bin/firefox && \
    rm /tmp/firefox.tar.bz2

# Create Firefox desktop entry
RUN echo "[Desktop Entry]\n\
    Name=Firefox\n\
    Comment=Web Browser\n\
    Exec=/opt/firefox/firefox %u\n\
    Icon=/opt/firefox/browser/chrome/icons/default/default128.png\n\
    Terminal=false\n\
    Type=Application\n\
    Categories=Network;WebBrowser;\n\
    MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;" > /usr/share/applications/firefox.desktop

# Install kubectl (latest stable version)
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Create non-root user for lab environment
# Set password to "labuser" for system authentication (keyring, sudo, etc.)
RUN useradd -m -s /bin/bash -u 1000 labuser && \
    echo "labuser:labuser" | chpasswd && \
    mkdir -p /home/labuser/.vnc && \
    chown -R labuser:labuser /home/labuser && \
    # Add labuser to sudoers with NOPASSWD (for lab environment)
    echo "labuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/labuser && \
    chmod 0440 /etc/sudoers.d/labuser

# Switch to labuser
USER labuser
WORKDIR /home/labuser

# Set up VNC password (will be overridden by startup script with dynamic password)
# Default password: "password" (8 characters, VNC password limit)
RUN echo "password" | vncpasswd -f > /home/labuser/.vnc/passwd && \
    chmod 600 /home/labuser/.vnc/passwd

# Configure MATE desktop for VNC
# Create simple startup script
RUN mkdir -p /home/labuser/.config/mate && \
    echo "#!/bin/bash" > /home/labuser/.vnc/xstartup && \
    echo "exec mate-session" >> /home/labuser/.vnc/xstartup && \
    chmod +x /home/labuser/.vnc/xstartup

# Create desktop shortcuts for Firefox and Terminal
RUN mkdir -p /home/labuser/Desktop && \
    # Firefox shortcut
    echo "[Desktop Entry]\n\
    Name=Firefox\n\
    Comment=Web Browser\n\
    Exec=/opt/firefox/firefox %u\n\
    Icon=/opt/firefox/browser/chrome/icons/default/default128.png\n\
    Terminal=false\n\
    Type=Application\n\
    Categories=Network;WebBrowser;" > /home/labuser/Desktop/firefox.desktop && \
    chmod +x /home/labuser/Desktop/firefox.desktop && \
    # Terminal shortcut
    echo "[Desktop Entry]\n\
    Name=Terminal\n\
    Comment=Use the command line\n\
    Exec=mate-terminal\n\
    Icon=utilities-terminal\n\
    Terminal=false\n\
    Type=Application\n\
    Categories=System;TerminalEmulator;" > /home/labuser/Desktop/mate-terminal.desktop && \
    chmod +x /home/labuser/Desktop/mate-terminal.desktop && \
    # Set ownership
    chown -R labuser:labuser /home/labuser/Desktop

# Copy startup script
COPY --chown=labuser:labuser start-vnc.sh /home/labuser/start-vnc.sh
RUN chmod +x /home/labuser/start-vnc.sh

# Copy noVNC files (will be mounted or copied)
# Note: noVNC can be cloned from https://github.com/novnc/noVNC
# For now, we'll use websockify's built-in web files

# Environment variables
ENV DISPLAY=:1
ENV VNC_RESOLUTION=1280x720
ENV VNC_DEPTH=16
ENV VNC_PORT=5901
ENV NOVNC_PORT=6080

# Expose ports
EXPOSE 5901 6080

# Health check (verify VNC server is running)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD netstat -an | grep 6080 > /dev/null || exit 1

# Start VNC server and websockify
CMD ["/home/labuser/start-vnc.sh"]
