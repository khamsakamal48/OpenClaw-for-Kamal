# OpenClaw — Self-Hosted AI Assistant (Docker Setup)

Production-ready Docker deployment for [OpenClaw](https://github.com/openclaw/openclaw) on an Oracle Cloud ARM64 free-tier VPS, with Nginx reverse proxy and n8n integration.

## Prerequisites

- Oracle Cloud VPS (ARM64) with Docker Engine + Compose v2 installed
- Nginx installed and running
- n8n already running in Docker on the `n8n-net` network
- Domain `openclaw.k-ai.in` with DNS pointing to the VPS
- certbot + python3-certbot-nginx installed (see OS-specific commands below)
- (Optional) OpenRouter API key from [openrouter.ai/keys](https://openrouter.ai/keys)

## Quick Start

```bash
# 1. Copy files to your VPS (e.g., /opt/openclaw)
scp -r ./* user@your-vps:/opt/openclaw/

# 2. SSH into your VPS
ssh user@your-vps
cd /opt/openclaw

# 3. Run the setup script — creates directories, openclaw.json config, .env, and pulls the image
chmod +x setup.sh
./setup.sh

# 4. Edit .env with your configuration
nano .env
```

### Step 5 — Set Up Nginx (OS-specific)

**Rocky Linux / RHEL / AlmaLinux / Fedora / CentOS:**
```bash
# Install certbot (if not already installed)
sudo dnf install certbot python3-certbot-nginx

# Deploy config — uses conf.d/ (no sites-available on RHEL-based systems)
sudo cp nginx-openclaw.conf /etc/nginx/conf.d/openclaw.conf
sudo nginx -t && sudo systemctl reload nginx

# Issue TLS certificate and let certbot auto-configure Nginx
sudo certbot --nginx -d openclaw.k-ai.in
```

**Ubuntu / Debian:**
```bash
# Install certbot (if not already installed)
sudo apt install certbot python3-certbot-nginx

# Deploy config — uses sites-available/sites-enabled pattern
sudo cp nginx-openclaw.conf /etc/nginx/sites-available/openclaw.conf
sudo ln -s /etc/nginx/sites-available/openclaw.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Issue TLS certificate and let certbot auto-configure Nginx
sudo certbot --nginx -d openclaw.k-ai.in
```

> **Important:** Deploy the config and reload Nginx **before** running certbot.
> The config ships as HTTP-only on purpose — certbot automatically adds the
> HTTPS server block and the HTTP→HTTPS redirect when it runs.

```bash
# 6. Start OpenClaw
docker compose up -d openclaw-gateway

# 7. Verify it's running
docker compose ps
curl http://127.0.0.1:18789/healthz
```

Open **https://openclaw.k-ai.in** in your browser to access the web UI.

## Connecting to the Web UI (First Login)

When you open the web UI for the first time, you'll see a **Gateway Dashboard** login screen asking for a Gateway Token. Follow these steps:

### Step 1 — Get the tokenized dashboard URL

```bash
docker exec openclaw-gateway node openclaw.mjs dashboard
```

This outputs something like:
```
Dashboard URL: http://127.0.0.1:18789/#token=c1d29096c0...
```

### Step 2 — Open it via your domain

Replace `http://127.0.0.1:18789/` with your domain and open it directly in your browser:
```
https://openclaw.k-ai.in/#token=c1d29096c0...
```

This is the recommended way — the token is embedded in the URL and the browser connects automatically.

### Step 3 — Approve the device pairing (one-time, per browser)

Even with the correct token, OpenClaw requires a one-time **device approval** for each new browser session. This is a security feature. After clicking Connect you'll see "pairing required". Approve it via:

```bash
# See the device list (your pending browser session will appear here)
docker exec openclaw-gateway node openclaw.mjs devices list

# Approve the pending request — no request ID needed, it approves whatever is pending
docker exec openclaw-gateway node openclaw.mjs devices approve
```

Then click **Connect** again in the browser — you should be logged in.

> **Note:** Leave the **Password** field empty unless you have explicitly configured
> a gateway password. Entering anything in that field with no password set will cause
> the connection to fail.

Pairing is remembered per browser profile — you won't need to repeat this unless you clear browser storage or connect from a new device/browser.

> **Important:** Do NOT run `openclaw gateway run` inside the container — the gateway
> is already running as the container's main process. Running it again will fail
> because the gateway is already active.

## File Overview

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Gateway + CLI service definitions |
| `.env.example` | Environment variable template |
| `.env` | Your actual config (not committed, chmod 600) |
| `setup.sh` | First-time setup helper |
| `nginx-openclaw.conf` | Nginx reverse proxy config |
| `openclaw-config/openclaw.json` | OpenClaw gateway configuration (JSON5) |
| `openclaw-config/` | Persistent config & state (bind mount → `/home/node/.openclaw`) |
| `openclaw-workspace/` | Workspace data (bind mount → `/home/node/.openclaw/workspace`) |

### About `openclaw.json`

OpenClaw reads its configuration from `~/.openclaw/openclaw.json` (JSON5 format — comments allowed). This maps to `./openclaw-config/openclaw.json` on the host via the volume mount.

> **Critical:** The file **must** be named `openclaw.json`. Any other name (e.g. `config.yaml`, `config.json`) is silently ignored. There are no environment variables for nested config keys like `controlUi.allowedOrigins` — the JSON file is the only way to set them.

Key settings in `openclaw.json`:

| Key | Value | Why |
|-----|-------|-----|
| `gateway.bind` | `"lan"` | Listens on `0.0.0.0` inside container so Docker port publishing works |
| `gateway.controlUi.allowedOrigins` | `["https://openclaw.k-ai.in"]` | Required when `bind=lan`; CSRF protection for the Control UI |

## Common Commands

```bash
# Start / stop / restart the gateway
docker compose up -d openclaw-gateway
docker compose stop openclaw-gateway
docker compose restart openclaw-gateway

# View logs (follow mode)
docker compose logs -f openclaw-gateway

# Get a tokenized dashboard URL (for web UI login)
docker exec openclaw-gateway node openclaw.mjs dashboard

# Run CLI commands (on-demand, auto-removes when done)
docker compose --profile cli run --rm openclaw-cli openclaw doctor
docker compose --profile cli run --rm openclaw-cli openclaw pairing list

# Check health
curl http://127.0.0.1:18789/healthz
curl http://127.0.0.1:18789/readyz

# Update to latest image
docker compose pull
docker compose up -d openclaw-gateway

# Check disk usage
docker system df
df -h
```

## Connecting Messaging Channels

### WhatsApp
No API key needed. WhatsApp uses QR code pairing through the OpenClaw web UI. Navigate to **Settings > Channels > WhatsApp** and scan the QR code with your phone.

### Telegram
1. Message [@BotFather](https://t.me/BotFather) on Telegram to create a bot and get a token
2. Add the token to `.env` as `TELEGRAM_BOT_TOKEN=your-token`
3. Restart the gateway: `docker compose restart openclaw-gateway`

### MS Teams
Requires Azure AD app registration. See the [OpenClaw Teams docs](https://docs.openclaw.ai/channels/teams) for setup instructions. You'll need `TEAMS_APP_ID`, `TEAMS_APP_PASSWORD`, and `TEAMS_TENANT_ID` in your `.env`.

## AI Model Configuration

This setup uses **OpenRouter** for AI model access. You can configure it in two ways:

1. **Environment variable**: Set `OPENROUTER_API_KEY` in `.env` before starting
2. **Web UI**: Start the gateway first, then configure in **Settings > Models** through the browser

OpenRouter gives access to free models (Llama, Mistral, etc.) and paid models (Claude, GPT-4, etc.) through a single API key.

## n8n Integration

The gateway joins the `n8n-net` Docker network, so n8n can reach OpenClaw at `openclaw-gateway:18789` and vice versa. This enables:

- n8n workflows that send messages through OpenClaw channels
- OpenClaw webhooks that trigger n8n workflows
- Shared automation pipelines

If your n8n container is not yet on `n8n-net`, connect it:
```bash
docker network connect n8n-net <your-n8n-container-name>
```

## Security Notes

This deployment includes the following hardening:

- **Non-root execution** — runs as uid 1000 (node user)
- **All capabilities dropped** — `cap_drop: ALL`
- **No privilege escalation** — `no-new-privileges: true`
- **Localhost-only ports** — bound to `127.0.0.1`; Nginx handles external access with TLS
- **Explicit CORS allowlist** — Control UI only accepts connections from `openclaw.k-ai.in`
- **No Docker socket** — sandbox mode is disabled to prevent container escape risks
- **Log rotation** — capped at 30MB per service to protect the 20GB disk
- **Resource limits** — gateway capped at 16GB RAM / 2 CPUs; prevents resource exhaustion

### DM Security
By default, OpenClaw requires pairing approval for unknown senders. Do **not** set `dmPolicy="open"` unless you understand the security implications. Run `openclaw doctor` via the CLI to audit your configuration:

```bash
docker compose --profile cli run --rm openclaw-cli openclaw doctor
```

## Resource Allocation

| Service | RAM Limit | CPU Limit | Notes |
|---------|-----------|-----------|-------|
| openclaw-gateway | 16 GB | 2.0 | Always running |
| openclaw-cli | 8 GB | 1.0 | On-demand only |
| n8n (existing) | — | — | Managed separately |
| **Host overhead** | ~2 GB | 0.5 | OS + Docker engine |

Total VPS: 3 OCPU / 24 GB RAM / 20 GB disk (Oracle Cloud ARM64 free tier).

## Troubleshooting

**Web UI shows "pairing required"**
This is normal — OpenClaw requires one-time device approval for each new browser session.
Use `devices` (not `pairing list`):
```bash
docker exec openclaw-gateway node openclaw.mjs devices list   # view pending session
docker exec openclaw-gateway node openclaw.mjs devices approve # approve it (no ID needed)
```
Then click Connect again. Also ensure the **Password** field is empty — entering anything
there without a configured gateway password will cause connection failure. Pairing is
remembered per browser permanently.

**Web UI shows "unauthorized: gateway token missing"**
The gateway auto-generates a token on first startup. Retrieve it with:
```bash
docker exec openclaw-gateway node openclaw.mjs dashboard
```
Copy the `?token=...` value from the output URL and paste it into the Gateway Token field.

**"Gateway start blocked: set gateway.mode=local or pass --allow-unconfigured"**
This happens if you run `openclaw gateway run` *inside* the container. Don't do this —
the gateway is already running as the container's main process. Use `docker compose logs`
to view its output, or `docker exec -it openclaw-gateway bash` to get a shell.

**502 Bad Gateway / `curl: (56) Recv failure: Connection reset by peer`**
The OpenClaw gateway defaults to `loopback` bind mode, only listening on `127.0.0.1`
inside the container. Fix: set `gateway.bind: "lan"` in `openclaw-config/openclaw.json`.
This is already configured by `setup.sh`. Note: `--bind` only accepts named modes
(`loopback`, `lan`, `tailnet`, `auto`, `custom`) — raw IPs like `0.0.0.0` are rejected.

**"non-loopback Control UI requires gateway.controlUi.allowedOrigins"**
This error appears when `gateway.bind` is `lan` but `controlUi.allowedOrigins` is not set.
Fix: ensure `openclaw-config/openclaw.json` exists with the correct content (created by
`setup.sh`). The file **must** be named `openclaw.json` — not `config.yaml` or anything
else. There are no env vars for these nested config keys.

**certbot fails with "cannot load certificate" error**
This happens when you copy an nginx config that already has `ssl_certificate` lines before
the cert exists. The included `nginx-openclaw.conf` is HTTP-only on purpose — deploy it
first, then run `certbot --nginx` and it will add the HTTPS block automatically.

**nginx -t fails after copying config**
```bash
# Check which config is causing the issue
sudo nginx -T 2>&1 | grep -i error

# Validate the specific file
sudo nginx -c /etc/nginx/nginx.conf -t
```

**Health check failing**
```bash
# Check if the port is listening
docker compose exec openclaw-gateway node -e "fetch('http://localhost:18789/healthz').then(r=>r.text()).then(console.log)"

# Check logs for errors
docker compose logs --tail=50 openclaw-gateway
```

**Disk running low**
```bash
# Clean up unused Docker resources
docker system prune -f

# Check what's using space
docker system df
du -sh openclaw-config/ openclaw-workspace/
```

**ARM64 image not available**
If the pre-built image doesn't support ARM64, you'll need to build from source:
```bash
git clone https://github.com/openclaw/openclaw.git /tmp/openclaw-src
cd /tmp/openclaw-src
docker build -t openclaw-local:latest --build-arg OPENCLAW_INSTALL_BROWSER=1 .
```
Then set `OPENCLAW_IMAGE=openclaw-local:latest` in your `.env`.
