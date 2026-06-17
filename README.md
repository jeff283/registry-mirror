# Local Registry Mirror

A local registry mirror that caches frequently pulled Docker images, reducing download times for repeated pulls.

## Why?

- A local registry mirror acts as a quick cache for frequently used images — if you pull down and up a compose file with multiple images multiple times a day, this helps reduce download times when nothing has changed upstream.
- Created out of frustration with large images that download slowly.

## How it works

When you pull an image, Docker checks the local mirror first. On a **miss** (first pull), the mirror fetches from Docker Hub and caches it locally. On a **hit** (subsequent pulls), the image is served straight from your machine — no internet needed.

## Files

| File                  | Purpose                                                         |
| --------------------- | --------------------------------------------------------------- |
| `registry-config.yml` | Registry mirror configuration (proxy, storage, metrics)         |
| `daemon.json`         | Docker daemon configuration (points Docker at the local mirror) |
| `setup.sh`            | One-shot setup script for a new machine                         |

## Setup

### Prerequisites

- Docker installed and running
- `curl` available

### Steps

**1. Clone the repo**

```bash
git clone https://github.com/jeff283/registry-mirror
cd registry-mirror
```

**2. Run the setup script**

```bash
chmod +x setup.sh
./setup.sh
```

This will:

- Install `daemon.json` to `/etc/docker/daemon.json`
- Restart the Docker daemon to pick up the mirror config
- Start the `registry-mirror` container with persistent storage
- Verify the registry and metrics endpoints are reachable

**3. Verify it's working**

```bash
# Registry alive
curl http://localhost:55678/v2/

# First pull — should be a miss (fetched from Docker Hub)
docker pull alpine:latest
curl -s http://localhost:55679/metrics | grep registry_proxy_misses
# misses should be > 0

# Remove local image and pull again — should be a hit (served from mirror)
docker rmi alpine:latest
docker pull alpine:latest
curl -s http://localhost:55679/metrics | grep registry_proxy_hits
# hits should now be > 0
```

Pull the same image again and check `registry_proxy_hits_total` to confirm caching is working.

## Ports

| Port    | Purpose                                     |
| ------- | ------------------------------------------- |
| `55678` | Registry API (Docker pulls go through here) |
| `55679` | Debug / Prometheus metrics                  |

## Metrics

The mirror exposes Prometheus metrics at `http://localhost:55679/metrics`. Useful ones:

```sh
registry_proxy_hits_total        # cache hits by type (blob/manifest)
registry_proxy_misses_total      # cache misses by type
registry_proxy_pulled_bytes_total  # bytes fetched from Docker Hub
registry_proxy_pushed_bytes_total  # bytes served to local clients
```

## Notes

- The `daemon.json` includes an `nvidia` runtime block — remove it if the target machine has no GPU or the Docker daemon will fail to start.
- Cached images persist in a Docker volume (`registry-mirror-data`) across container restarts.
- Only Docker Hub images are mirrored. Images from other registries (ghcr.io, gcr.io, etc.) are pulled directly.
