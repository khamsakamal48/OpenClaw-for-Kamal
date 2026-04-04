#!/usr/bin/env bash
###############################################################################
# OpenClaw — First-time setup helper
# Run this once on your VPS before `docker compose up`.
###############################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> OpenClaw setup"

# ---- 1. Create data directories with correct ownership (uid 1000 = node) ---
echo "  Creating data directories..."
mkdir -p openclaw-config openclaw-workspace
sudo chown 1000:1000 openclaw-config openclaw-workspace
echo "  Done: openclaw-config/ and openclaw-workspace/ (owned by uid 1000)"

# ---- 2. Create the shared Docker network if it doesn't exist ----------------
if docker network inspect n8n-net >/dev/null 2>&1; then
  echo "  Docker network 'n8n-net' already exists — skipping."
else
  echo "  Creating Docker network 'n8n-net'..."
  docker network create n8n-net
  echo "  Done. Remember to also connect your n8n container:"
  echo "    docker network connect n8n-net <your-n8n-container-name>"
fi

# ---- 3. Create .env from template if it doesn't exist -----------------------
if [ -f .env ]; then
  echo "  .env already exists — skipping."
else
  echo "  Copying .env.example to .env..."
  cp .env.example .env
  chmod 600 .env
  echo "  Done. Edit .env to add your API keys and tokens."
fi

# ---- 4. Pull the container image ---------------------------------------------
echo "  Pulling OpenClaw image (this may take a few minutes)..."
docker compose pull openclaw-gateway
echo "  Done."

echo ""
echo "==> Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your API keys (or configure later in the web UI)"
echo "  2. Start the gateway:  docker compose up -d openclaw-gateway"
echo "  3. Check health:       docker compose ps"
echo "  4. View logs:          docker compose logs -f openclaw-gateway"
echo "  5. Open the web UI:    https://openclaw.k-ai.in"
echo "  6. Run CLI commands:   docker compose --profile cli run --rm openclaw-cli <command>"
