# CI/CD Pipeline Explanation

## Overview: Two-Phase Build Strategy

The Docker build workflow uses a **test-first approach** with two separate builds:

### Phase 1: Build & Test (linux/amd64 only)

```yaml
- name: Build Docker image for testing
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64
    load: true # Load into local Docker daemon
    tags: ${{ env.IMAGE_NAME }}:test
```

**Why amd64 only?**

- GitHub Actions runners are `linux/amd64` machines
- `load: true` requires building for the **runner's native platform**
- You can't load an ARM image into an x86 Docker daemon
- This allows us to actually **run and test** the container

**Purpose:** Validate the image works before spending time on multi-platform builds

### Phase 2: Multi-Platform Build & Push

```yaml
- name: Build and push multi-platform image
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64,linux/arm/v7
    push: true # Push to registry (can't load multi-arch)
```

**Why push instead of load?**

- Multi-platform builds create a **manifest list** (collection of images for different architectures)
- Your local Docker daemon can only hold ONE architecture at a time
- `push: true` sends all architectures to the registry where they're stored together
- When users `docker pull`, Docker automatically selects the right architecture

---

## How Cross-Platform Builds Work

### 1. **QEMU Setup**

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3
```

**QEMU** is a CPU emulator that allows:

- Building ARM binaries on x86 machines
- Running ARM containers on x86 hosts (slower, but works!)

**How it works:**

- Registers binary format handlers in the Linux kernel
- When Docker tries to run an ARM binary, kernel intercepts and routes to QEMU
- QEMU translates ARM instructions to x86 on-the-fly

**Analogy:** Like running Windows apps on Mac using Rosetta 2

### 2. **Docker Buildx**

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
  with:
    driver-opts: |
      image=moby/buildkit:latest
      network=host
```

**Buildx** is Docker's modern build system that supports:

- Multi-platform builds
- Build caching
- Parallel builds
- Remote builders

**Why `buildkit:latest`?** Latest features and performance improvements

**Why `network=host`?** Allows build containers to access host network (useful for downloading packages during build)

### 3. **The Build Process**

When you specify `platforms: linux/amd64,linux/arm64,linux/arm/v7`:

```txt
┌────────────────────────────────────────────────┐
│ GitHub Actions Runner (linux/amd64)            │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │ BuildKit + QEMU                          │  │
│  │                                          │  │
│  │  Build linux/amd64  ────► Native build   │  │
│  │                           (fast!)        │  │
│  │                                          │  │
│  │  Build linux/arm64  ────► QEMU emulation │  │
│  │                           (slower)       │  │
│  │                                          │  │
│  │  Build linux/arm/v7 ────► QEMU emulation │  │
│  │                           (slower)       │  │
│  └──────────────────────────────────────────┘  │
│                      │                         │
│                      ▼                         │
│  ┌──────────────────────────────────────────┐  │
│  │ Docker Registry (Docker Hub)             │  │
│  │                                          │  │
│  │  Manifest List (multi-arch index)        │  │
│  │  ├─ linux/amd64 → sha256:abc123...       │  │
│  │  ├─ linux/arm64 → sha256:def456...       │  │
│  │  └─ linux/arm/v7 → sha256:ghi789...      │  │
│  └──────────────────────────────────────────┘  │
└────────────────────────────────────────────────┘
```

**Result:** One tag (`latest`) points to 3 different images!

---

## Why This Architecture?

### ✅ **Cache Efficiency**

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

- Phase 1 builds amd64 and caches layers
- Phase 2 reuses cached amd64 layers (doesn't rebuild!)
- Only ARM builds happen from scratch in Phase 2
- Saves ~5-10 minutes per workflow run

### ✅ **Fast Feedback**

- Test on amd64 (native, fast) before committing to 60-minute multi-platform build
- If tests fail, you know in ~5 minutes, not after building all architectures

### ✅ **Cost Optimization**

- GitHub Actions charges for minutes
- ARM emulation is **10-20x slower** than native builds
- Only pay for ARM build time if tests pass

### ✅ **User Experience**

```bash
# Mac M1/M2 user (ARM):
docker pull usersina/vnc-lab-desktop
# ↑ Automatically gets linux/arm64 image

# Intel/AMD user:
docker pull usersina/vnc-lab-desktop
# ↑ Automatically gets linux/amd64 image

# Raspberry Pi user:
docker pull usersina/vnc-lab-desktop
# ↑ Automatically gets linux/arm/v7 image
```

**Docker client** checks your CPU architecture and pulls the matching image from the manifest list!

---

## The Manifest List (Docker's Magic)

When you push with `platforms: linux/amd64,linux/arm64,linux/arm/v7`, Docker creates:

```json
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
  "manifests": [
    {
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": { "architecture": "amd64", "os": "linux" },
      "digest": "sha256:abc123..."
    },
    {
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": { "architecture": "arm64", "os": "linux" },
      "digest": "sha256:def456..."
    },
    {
      "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
      "platform": { "architecture": "arm", "variant": "v7", "os": "linux" },
      "digest": "sha256:ghi789..."
    }
  ]
}
```

**One tag, multiple images!** Docker CLI automatically selects the right one.

---

## Why Can't We Test ARM Images?

```yaml
# ❌ This would fail:
platforms: linux/amd64,linux/arm64
load: true # ERROR: Can't load multiple platforms to local daemon
```

**Problem:** Your local Docker daemon is single-architecture. It can hold:

- ✅ linux/amd64 image (native)
- ✅ linux/arm64 image (via QEMU)
- ❌ **BOTH at the same time under one tag**

**Solution:** Test amd64 locally, trust that ARM builds work the same (they usually do since it's the same Dockerfile!)

---

## Performance Numbers

Approximate build times on GitHub Actions:

| Phase | Platform     | Build Time | Method               |
| ----- | ------------ | ---------- | -------------------- |
| Test  | linux/amd64  | ~3-5 min   | Native build         |
| Push  | linux/amd64  | ~1 min     | Cached from Phase 1! |
| Push  | linux/arm64  | ~15-20 min | QEMU emulation       |
| Push  | linux/arm/v7 | ~25-30 min | QEMU emulation       |

**Total:** ~45-60 minutes (with 60-minute timeout as safety)

**Without caching:** Would be ~70-80 minutes!

---

## Workflow Steps Breakdown

### 1. Checkout Repository

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
```

Gets the latest code from the repository.

### 2. Set Up QEMU

```yaml
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3
```

Installs QEMU for ARM emulation on the x86 runner.

### 3. Set Up Docker Buildx

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
  with:
    driver-opts: |
      image=moby/buildkit:latest
      network=host
```

Configures the modern Docker build system with caching and multi-platform support.

### 4. Log In to Docker Hub

```yaml
- name: Log in to Docker Hub
  if: github.event_name != 'pull_request'
  uses: docker/login-action@v3
  with:
    registry: ${{ env.REGISTRY }}
    username: ${{ vars.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
```

Authenticates with Docker Hub. Skipped for pull requests (no push needed).

### 5. Extract Metadata

```yaml
- name: Extract metadata (tags, labels)
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
    tags: |
      type=ref,event=pr          # pr-123
      type=semver,pattern={{version}}  # 1.2.3
      type=semver,pattern={{major}}.{{minor}}  # 1.2
      type=semver,pattern={{major}}  # 1
      type=sha,format=long       # sha-abc123def456...
      type=raw,value=latest,enable={{is_default_branch}}  # latest
```

Generates Docker tags based on Git events:

- **PR:** `pr-123`
- **Semver tag:** `v1.2.3` → tags `1.2.3`, `1.2`, `1`, `latest`
- **Main push:** `sha-abc123...`, `latest`

### 6. Build Docker Image for Testing

```yaml
- name: Build Docker image for testing
  id: build-test
  uses: docker/build-push-action@v5
  with:
    context: .
    platforms: linux/amd64
    load: true
    tags: ${{ env.IMAGE_NAME }}:test
    cache-from: type=gha
    cache-to: type=gha,mode=max
    provenance: false
    sbom: false
```

Builds amd64-only image, loads it into local Docker daemon for testing.

**Cache settings:**

- `cache-from: type=gha` - Restore cache from GitHub Actions cache
- `cache-to: type=gha,mode=max` - Save all layers to cache (not just final image)

**Disabled features:**

- `provenance: false` - Skip attestation metadata (saves time)
- `sbom: false` - Skip Software Bill of Materials (saves time)

### 7. Test Image

```yaml
- name: Test image
  run: |
    docker run -d \
      --name vnc-desktop \
      -p 6080:6080 \
      -e VNC_PASSWORD=password \
      ${{ env.IMAGE_NAME }}:test

    echo "Waiting for container to become healthy..."
    timeout 60s bash -c 'until docker inspect --format="{{.State.Health.Status}}" vnc-desktop | grep -q healthy; do sleep 2; echo "  Health status: $(docker inspect --format="{{.State.Health.Status}}" vnc-desktop)"; done' || {
      echo "Container failed to become healthy"
      docker logs vnc-desktop
      exit 1
    }

    echo "=== Container is healthy ==="
    docker logs vnc-desktop

    echo "=== Checking if websockify is listening on port 6080 ==="
    docker exec vnc-desktop netstat -tulpn | grep 6080 || exit 1

    echo "=== Checking if VNC server is running ==="
    docker exec vnc-desktop vncserver -list || exit 1

    echo "=== Checking WebSocket endpoint is responding ==="
    curl -i -H "Connection: Upgrade" -H "Upgrade: websocket" http://localhost:6080 2>&1 | grep -i "websockify" || exit 1

    echo "=== All tests passed! ==="
    docker stop vnc-desktop
    docker rm vnc-desktop
```

**Test steps:**

1. Start container with VNC password
2. Wait up to 60 seconds for health check to pass
3. Verify websockify listening on port 6080
4. Verify VNC server is running
5. Test WebSocket endpoint responds correctly
6. Clean up container

**If any test fails:** Workflow stops, ARM builds don't run (saving time and cost)

### 8. Build and Push Multi-Platform Image

```yaml
- name: Build and push multi-platform image
  if: github.event_name != 'pull_request'
  uses: docker/build-push-action@v5
  with:
    context: .
    platforms: linux/amd64,linux/arm64,linux/arm/v7
    push: true
    tags: ${{ steps.meta.outputs.tags }}
    labels: ${{ steps.meta.outputs.labels }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
    provenance: false
    sbom: false
```

Only runs if:

- Tests pass ✅
- Not a pull request (no push to registry from PRs)

Builds all three platforms and pushes to Docker Hub with proper tags.

### 9. Update Docker Hub Description

```yaml
- name: Update Docker Hub Description
  if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'
  uses: peter-evans/dockerhub-description@v4
  with:
    username: ${{ vars.DOCKER_USERNAME }}
    password: ${{ secrets.DOCKER_PASSWORD }}
    repository: usersina/vnc-lab-desktop
    short-description: 'Browser-based Ubuntu desktop with MATE, Firefox, kubectl. Memory-optimized for K8s labs.'
    readme-filepath: ./README.md
```

Only runs on main branch pushes (not tags, not PRs).

Syncs:

- **Short description:** Shown in Docker Hub search results (max 100 chars)
- **Full description:** Syncs README.md to Docker Hub repository page

---

## Alternative Approaches (Not Used)

### 1. **Native ARM Runners**

```yaml
# Use actual ARM machines
jobs:
  build-arm:
    runs-on: [self-hosted, linux, arm64]
```

**Pros:** Much faster ARM builds (native speed)  
**Cons:** Need to maintain your own ARM runners (expensive!)

### 2. **Build Matrix**

```yaml
strategy:
  matrix:
    platform: [linux/amd64, linux/arm64]
```

**Pros:** Parallel builds  
**Cons:** More complex, separate images need manual merging into manifest list

### 3. **Skip Testing**

```yaml
# Just build and push everything
platforms: linux/amd64,linux/arm64,linux/arm/v7
push: true
```

**Pros:** Simpler workflow  
**Cons:** No validation before pushing broken images!

---

## Summary

**This workflow is optimal for:**

- ✅ Fast feedback (test amd64 first)
- ✅ Cost efficiency (cache reuse, only build ARM if tests pass)
- ✅ User experience (automatic platform detection)
- ✅ Reliability (health checks before pushing)

**The key insight:** Build for testing ≠ Build for distribution. Separate concerns for better workflow! 🚀

---

## Debugging Tips

### View workflow logs

```bash
# In GitHub UI:
Actions → Latest workflow run → Build and push

# Or use GitHub CLI:
gh run list
gh run view <run-id> --log
```

### Test locally (amd64 only)

```bash
# Build and test like CI does
docker buildx build --platform linux/amd64 -t vnc-lab-desktop:test --load .

docker run -d --name vnc-desktop -p 6080:6080 -e VNC_PASSWORD=password vnc-lab-desktop:test

# Wait for health check
watch docker inspect --format='{{.State.Health.Status}}' vnc-desktop

# Test
docker exec vnc-desktop netstat -tulpn | grep 6080
```

### Test ARM build locally (slow!)

```bash
# Install QEMU (if not already installed)
docker run --privileged --rm tonistiigi/binfmt --install all

# Build ARM image (will take 20-30 minutes)
docker buildx build --platform linux/arm64 -t vnc-lab-desktop:arm64 --load .
```

### Inspect manifest list

```bash
# After images are pushed
docker buildx imagetools inspect usersina/vnc-lab-desktop:latest

# Shows all architectures
```
