# VNC Lab Desktop

[![Docker Hub](https://img.shields.io/docker/pulls/usersina/vnc-lab-desktop.svg)](https://hub.docker.com/r/usersina/vnc-lab-desktop)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A Docker image providing browser-based graphical desktop access for cloud-native labs, training, and remote development. Built on Ubuntu 22.04 with MATE Desktop, optimized for memory efficiency (220Mi idle vs 8Gi typical desktop VNC solutions). Perfect for Kubernetes workshops, CKA/CKAD prep, and scenarios requiring GUI tools.

**✨ Key Highlights:**

- 🚀 Browser-based access via noVNC (no VNC client needed)
- 💾 Memory efficient: 220Mi idle RAM usage
- 🔧 Pre-installed: Firefox, kubectl, development tools
- 🎯 Ready for DevOps training, labs, and remote work

## Table of Contents

- [Features](#features)
- [Image Size & Performance](#image-size--performance)
- [Quick Start](#quick-start)
- [Environment Variables](#environment-variables)
- [Use Cases](#use-cases)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Features

- **Ubuntu 22.04** base image
- **TigerVNC Server** for remote desktop access
- **MATE Desktop** - Polished desktop environment (fork of GNOME 2)
- **Firefox** browser from Mozilla (not snap) for web testing
- **kubectl** for Kubernetes management
- **websockify** for WebSocket-to-VNC bridging (noVNC compatible)
- **Desktop shortcuts** - Firefox and Terminal pre-configured on desktop
- **Passwordless sudo** - Full sudo access for package installation
- **16-bit color depth** - Memory optimized while maintaining visual quality

## Image Size & Performance

- **Image Size**: 2.11GB (full MATE desktop with Firefox)
- **RAM Usage**: ~220Mi idle, 1Gi limit recommended
- **CPU Usage**: 0.5-1 CPU per session
- **Startup Time**: 15-25 seconds

**Memory Optimization:** 87% reduction vs XFCE (1Gi vs 8Gi limit)

- XFCE required 8Gi memory limit due to X11 virtual memory allocation
- MATE with optimizations runs comfortably in 1Gi
- Actual usage: ~220Mi idle, ~500Mi with Firefox open

Compare to terminal-only image: ~50MB image, ~100-200MB RAM

## Quick Start

### Using Docker Hub (Recommended)

```bash
# Pull the latest image
docker pull usersina/vnc-lab-desktop:latest

# Run container
docker run -d \
  -p 6080:6080 \
  -p 5901:5901 \
  -e VNC_PASSWORD=password \
  --name vnc-desktop \
  usersina/vnc-lab-desktop:latest

# Access via a vnc client on 5901
vncviewer localhost:5901
```

## Accessing the Desktop

Once the container is running, you have two options:

1. **Browser with noVNC Client (Recommended)**: Use the [example React app](./example/) or integrate noVNC into your own application
2. **VNC Client**: Connect to `localhost:5901` using any VNC client (e.g., TigerVNC Viewer, RealVNC)

### Quick Start with Example App

```bash
# Start VNC container
docker run -d -p 6080:6080 -e VNC_PASSWORD=password usersina/vnc-lab-desktop

# Run the example React app
cd example
npm install
npm run dev
```

Then open the example app and click "Connect to Desktop". See [example/README.md](./example/README.md) for details.

## Environment Variables

| Variable         | Default    | Description                                       |
| ---------------- | ---------- | ------------------------------------------------- |
| `VNC_PASSWORD`   | `password` | VNC server password (8 chars max)                 |
| `VNC_RESOLUTION` | `1280x720` | Desktop resolution                                |
| `VNC_DEPTH`      | `16`       | Color depth in bits (16 saves memory, looks fine) |
| `VNC_PORT`       | `5901`     | VNC server port (internal)                        |
| `NOVNC_PORT`     | `6080`     | WebSocket proxy port (exposed)                    |
| `DISPLAY`        | `:1`       | X display number                                  |

## Desktop Shortcuts

The desktop comes with pre-configured shortcuts for quick access:

- **Firefox** - Double-click to launch web browser
- **Terminal** - Double-click to open MATE Terminal with kubectl

These shortcuts are automatically created on first desktop load, providing immediate access to the most commonly used tools.

## sudo Access

The `labuser` account has **passwordless sudo** for all commands:

```bash
# Install packages without password prompt
sudo apt-get update
sudo apt-get install helm

# Any sudo command works
sudo systemctl status <service>  # (note: systemd limited in containers)
```

This is standard for lab environments and allows students to:

- Install tools like `helm`, `k9s`, `terraform`, etc.
- Practice real-world K8s scenarios
- Follow CKA/CKAD exam-style workflows

**Security Note:** Safe for labs because sessions are isolated, ephemeral, and have no access to sensitive data.

## Use Cases

Perfect for scenarios requiring GUI access in containerized environments:

- **Kubernetes Training**: CKA/CKAD exam prep, workshops, interactive labs
- **Remote Development**: Browser-based IDE access, debugging GUI applications
- **Testing**: Cross-browser testing, web application development
- **Education**: Teaching Linux desktop environments, GUI tool demonstrations
- **Remote Access**: Secure browser-based access to desktop environments
- **Cloud Workspaces**: Ephemeral developer workstations in Kubernetes

## Security Considerations

### ⚠️ Lab Environment Security

This image is designed for **lab and training environments**. For production deployments:

- **VNC Password**: Always set a strong `VNC_PASSWORD` environment variable
- **Network Isolation**: Use network policies to restrict access
- **Resource Limits**: Set appropriate memory and CPU limits in Kubernetes
- **Encryption**: Use TLS/HTTPS for WebSocket connections in production
- **Authentication**: Implement proper authentication before VNC access
- **Timeouts**: Configure session timeouts to auto-terminate inactive sessions

### Production Hardening Recommendations

1. **Generate unique VNC password per session** (not hardcoded)
2. **Implement rate limiting** on WebSocket endpoints
3. **Message size limits** to prevent abuse
4. **Connection timeouts** (auto-close after configurable period)
5. **Read-only filesystem** where possible using Docker volumes
6. **Resource monitoring** to prevent desktop CPU/RAM abuse
7. **Network isolation** to restrict access

## Testing

### Quick Connection Test

```bash
# Test WebSocket is responding
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  http://localhost:6080

# Or test with wscat
npm install -g wscat
wscat -c ws://localhost:6080
```

### Integration with Web Apps

See [`frontend-guide.md`](frontend-guide.md) for integration examples with React/Next.js applications.

### Test Desktop Features

Once connected to VNC desktop:

```bash
# In MATE Terminal (double-click desktop shortcut)

# Test kubectl
kubectl version

# Test passwordless sudo (no password prompt!)
sudo apt-get update
sudo apt-get install -y htop

# Test Firefox
# Double-click Firefox desktop shortcut
# Navigate to any website

# Test file manager
# Applications → Accessories → Caja (File Manager)
```

## Troubleshooting

### VNC Server Won't Start

```bash
# Check logs
docker logs vnc-desktop

# Common issue: X11 lock file
docker exec -it vnc-desktop rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
docker restart vnc-desktop
```

### WebSocket Connection Refused

```bash
# Verify websockify is running
docker exec -it vnc-desktop netstat -tulpn | grep 6080

# Check VNC server
docker exec -it vnc-desktop vncserver -list
```

### Desktop Not Responding

```bash
# Restart VNC server
docker exec -it vnc-desktop vncserver -kill :1
docker exec -it vnc-desktop vncserver :1 -geometry 1280x720 -depth 16
```

### IndicatorApplet Error on First Connection

**Symptom:** Error popup saying "The panel encountered a problem while loading IndicatorAppletComplete"

**Solution:** This is a **one-time cosmetic issue**:

1. Click the **"Delete"** button on the error dialog
2. The applet will be removed from the panel
3. Error won't appear again in this session

**Why it happens:** MATE's indicator applet is not needed for lab environment, but is configured by default. First connection removes it.

### sudo Commands Not Working

If `sudo` commands fail:

```bash
# Verify labuser has sudo access
docker exec -it vnc-desktop sudo -l

# Should show: (ALL) NOPASSWD: ALL
```

This is pre-configured in the image. If missing, the image build may have failed.

## Performance Optimization

### Already Implemented ✅

- **MATE Desktop** instead of XFCE (87% memory reduction: 1Gi vs 8Gi)
- **16-bit color depth** (default) - saves memory without visual degradation
- **Firefox from Mozilla tarball** - avoids snap overhead
- **Desktop shortcuts pre-configured** - faster student onboarding
- **Passwordless sudo** - no workflow interruptions

### Further Optimization Options

If you need even lower resource usage:

**Reduce RAM:**

- Lower resolution: `VNC_RESOLUTION=1024x768` (saves ~50Mi)
- Close Firefox when not needed (saves ~300Mi)

**Reduce Image Size:**

- Remove unused MATE components
- Use minimal browser build

**Improve Startup Time:**

- Use image caching in Kubernetes (ImagePullPolicy: IfNotPresent)
- Pre-pull images to nodes
- Keep pods warm between sessions

**Current Settings Recommended:** The default 1Gi limit provides excellent balance between resource efficiency and user experience.

## Comparison to Terminal-Only

| Aspect               | Terminal-Only (kubectl) | VNC Desktop (MATE) | Trade-off      |
| -------------------- | ----------------------- | ------------------ | -------------- |
| **Image Size**       | 50MB                    | 2.11GB             | 42x larger     |
| **RAM Usage**        | 100-200MB               | 220-500Mi          | 2-3x more      |
| **CPU Usage**        | 0.1-0.2 CPU             | 0.5-1 CPU          | 5x more        |
| **Startup Time**     | 5-10s                   | 15-25s             | 2-3x slower    |
| **Use Cases**        | CLI labs                | GUI labs           | Specialized    |
| **Concurrent Users** | 20 per 4GB node         | 8-10 per 4GB node  | 2x fewer       |
| **Browser Access**   | ❌                      | ✅ Firefox         | Essential GUI  |
| **sudo Available**   | ✅                      | ✅                 | Both supported |

**Recommendation**: Use VNC for labs that **require** GUI access (browser, visual monitoring tools, desktop apps). Default to terminal-only for pure CLI-based Kubernetes labs.

**Memory Efficiency Note:** The MATE-based VNC environment is surprisingly efficient (~220Mi idle), making it viable for more concurrent users than traditional heavy desktop VNC solutions.

## Architecture

```bash
┌─────────────────────────────────────────────┐
│  Browser (noVNC Client)                     │
│  - JavaScript-based VNC viewer              │
│  - Renders desktop in HTML5 canvas          │
└───────────────┬─────────────────────────────┘
                │ WebSocket (ws://host:6080)
                │
┌───────────────▼─────────────────────────────┐
│  VNC Container (vnc-lab-desktop)            │
│                                             │
│  ┌──────────────────────────────────┐       │
│  │ websockify (port 6080)           │       │
│  │ - Listens on WebSocket           │       │
│  │ - Translates to VNC protocol     │       │
│  └────────────┬─────────────────────┘       │
│               │ VNC protocol (port 5901)    │
│  ┌────────────▼─────────────────────┐       │
│  │ TigerVNC Server (display :1)     │       │
│  │ - Manages X11 desktop            │       │
│  │ - Handles keyboard/mouse input   │       │
│  └────────────┬─────────────────────┘       │
│               │ X11 protocol                │
│  ┌────────────▼─────────────────────┐       │
│  │ MATE Desktop Environment         │       │
│  │ - Marco window manager           │       │
│  │ - Firefox browser (Mozilla)      │       │
│  │ - MATE Terminal with kubectl     │       │
│  │ - Caja file manager              │       │
│  │ - Desktop shortcuts              │       │
│  └──────────────────────────────────┘       │
└─────────────────────────────────────────────┘
```

## Features Status

- ✅ Ubuntu 22.04 base image
- ✅ TigerVNC Server for remote desktop
- ✅ MATE Desktop Environment optimized for memory efficiency
- ✅ Firefox browser from Mozilla (not snap)
- ✅ kubectl pre-installed
- ✅ websockify for noVNC compatibility
- ✅ Desktop shortcuts (Firefox, Terminal)
- ✅ Passwordless sudo access
- ✅ Memory optimization (220Mi idle vs 8Gi typical solutions)
- ✅ Docker and Docker Compose support
- ✅ noVNC integration guide

## Why MATE Desktop?

We chose MATE (fork of GNOME 2) over other desktop environments after extensive testing:

**❌ XFCE4** (original choice):

- Required **8Gi memory limit** due to X11 virtual memory allocation
- Actual usage only ~200Mi, but cgroups counted virtual memory
- OOMKilled with any limit below 8Gi
- Unsustainable for multi-tenant K8s

**❌ Openbox** (tried):

- Only ~50Mi memory usage
- But **too bare-bones** - no menu, no working desktop
- Students would be confused and frustrated
- Not suitable for lab environment

**✅ MATE** (current):

- **Professional, polished UI** - full desktop experience
- **Lightweight** - only ~220Mi idle memory usage
- **Works with 1Gi limit** - 87% reduction vs XFCE!
- **Complete** - menus, panels, file manager all work
- **Familiar** - traditional desktop layout students expect

**Result:** Best of both worlds - professional UX with efficient resource usage.

## Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/usersina/vnc-lab-desktop.git
cd vnc-lab-desktop

# Build the image
docker build -t vnc-lab-desktop .

# Run locally
docker run -d -p 6080:6080 -p 5901:5901 -e VNC_PASSWORD=password vnc-lab-desktop
```

### Pushing to Registry

```bash
# Tag image
docker tag vnc-lab-desktop:latest usersina/vnc-lab-desktop:latest

# Push to Docker Hub
docker push usersina/vnc-lab-desktop:latest
```

## Contributing

Contributions are welcome! Please check out the [contributing guidelines](CONTRIBUTING.md) for more details.

**Areas for improvement:**

- Additional desktop environments (XFCE, LXQt)
- Pre-installed development tools
- Better resource optimization
- Security hardening options
- Documentation and examples

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Resources

- [noVNC GitHub](https://github.com/novnc/noVNC)
- [TigerVNC Documentation](https://tigervnc.org/)
- [websockify GitHub](https://github.com/novnc/websockify)
- [MATE Desktop Documentation](https://mate-desktop.org/)
- [Mozilla Firefox Downloads](https://www.mozilla.org/firefox/all/)

## Support

- **Issues**: [GitHub Issues](https://github.com/usersina/vnc-lab-desktop/issues)
- **Discussions**: [GitHub Discussions](https://github.com/usersina/vnc-lab-desktop/discussions)
- **Docker Hub**: [usersina/vnc-lab-desktop](https://hub.docker.com/r/usersina/vnc-lab-desktop)
