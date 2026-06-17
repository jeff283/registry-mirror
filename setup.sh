#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Install daemon.json
echo "→ Installing daemon.json..."
sudo cp "$SCRIPT_DIR/daemon.json" /etc/docker/daemon.json

# 2. Restart docker to pick up daemon.json
echo "→ Restarting Docker daemon..."
sudo systemctl restart docker

# 3. Start registry mirror
echo "→ Starting registry mirror..."
docker run -d \
  --name registry-mirror \
  --restart always \
  -p 55678:5000 \
  -p 55679:5001 \
  -v registry-mirror-data:/var/lib/registry \
  -v "$SCRIPT_DIR/registry-config.yml":/etc/distribution/config.yml \
  registry:3

# 4. Verify
echo "→ Verifying..."
sleep 2
curl -sf http://localhost:55678/v2/ && echo "Registry OK"
curl -sf http://localhost:55679/metrics | grep -c "registry_" && echo "Metrics OK"

echo "Done. Pull an image to seed the cache:"
echo "  docker pull alpine:latest"