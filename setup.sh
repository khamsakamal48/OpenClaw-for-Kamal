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
mkdir -p openclaw-config openclaw-workspace openclaw-homebrew
sudo chown 1000:1000 openclaw-config openclaw-workspace openclaw-homebrew
echo "  Done: openclaw-config/, openclaw-workspace/, openclaw-homebrew/ (owned by uid 1000)"

# ---- 2. Create openclaw.json config file ------------------------------------
# OpenClaw reads its config from ~/.openclaw/openclaw.json (JSON5 format).
# This maps to openclaw-config/openclaw.json via the volume mount.
# NOTE: This file must be named "openclaw.json" — YAML/other names are ignored.
if [ -f openclaw-config/openclaw.json ]; then
  echo "  openclaw-config/openclaw.json already exists — skipping."
else
  echo "  Creating openclaw-config/openclaw.json..."
  cat > openclaw-config/openclaw.json << 'JSONEOF'
{
  // OpenClaw configuration (JSON5 format — comments are allowed)
  // File path in container: /home/node/.openclaw/openclaw.json
  // Full config reference: https://docs.openclaw.ai/config/gateway

  "gateway": {
    // "lan" = listen on 0.0.0.0 inside the container so Docker port
    // publishing works. Do NOT use "loopback" — it breaks the Nginx proxy.
    "bind": "lan",

    "controlUi": {
      // Required when bind != loopback. Only requests from these origins
      // are accepted by the Control UI (CSRF protection).
      "allowedOrigins": ["https://openclaw.k-ai.in"]
    }
  }
}
JSONEOF
  sudo chown 1000:1000 openclaw-config/openclaw.json
  echo "  Done."
fi

# ---- 3. Create the shared Docker network if it doesn't exist ----------------
if docker network inspect n8n-net >/dev/null 2>&1; then
  echo "  Docker network 'n8n-net' already exists — skipping."
else
  echo "  Creating Docker network 'n8n-net'..."
  docker network create n8n-net
  echo "  Done. Remember to also connect your n8n container:"
  echo "    docker network connect n8n-net <your-n8n-container-name>"
fi

# ---- 4. Create .env from template if it doesn't exist -----------------------
if [ -f .env ]; then
  echo "  .env already exists — skipping."
else
  echo "  Copying .env.example to .env..."
  cp .env.example .env
  chmod 600 .env
  echo "  Done. Edit .env to add your API keys and tokens."
fi

# ---- 5. Pull the container image --------------------------------------------
echo "  Pulling OpenClaw image (this may take a few minutes)..."
docker compose pull openclaw-gateway
echo "  Done."

echo ""
echo "==> Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your API keys (or configure later in the web UI)"
echo "  2. Start the gateway:   docker compose up -d openclaw-gateway"
echo "  3. Check health:        docker compose ps"
echo "  4. View logs:           docker compose logs -f openclaw-gateway"
echo "  5. Get dashboard URL:   docker exec openclaw-gateway node openclaw.mjs dashboard"
echo "     Copy the token from the URL and paste it into the web UI Gateway Token field."
echo "  6. Open the web UI:     https://openclaw.k-ai.in"
echo "  7. Run CLI commands:    docker compose --profile cli run --rm openclaw-cli <command>"
