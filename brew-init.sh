#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# brew-init.sh — OpenClaw container bootstrap
#
# Runs as the container entrypoint (user node / uid 1000, non-root) before
# the main process. On first run it installs Homebrew into the persistent
# /home/node/.linuxbrew volume (./openclaw-homebrew on the host), then uses
# Homebrew to install Python 3 and supercronic (a rootless cron replacement
# designed for containers). Subsequent starts skip straight to step 2 since
# everything is already cached in the volume.
#
# OpenClaw's resolveBrewExecutable() automatically checks /home/node/.linuxbrew
# so no extra environment variables are needed for it to find Homebrew tools.
# ---------------------------------------------------------------------------
set -euo pipefail

BREW_PREFIX="/home/node/.linuxbrew"
CRONTAB_FILE="/home/node/.openclaw/crontab"

# ---- 1. Bootstrap Homebrew if not yet installed ----------------------------
if [ ! -x "${BREW_PREFIX}/bin/brew" ]; then
    echo "[brew-init] Homebrew not found — installing to ${BREW_PREFIX} ..."
    NONINTERACTIVE=1 CI=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "[brew-init] Homebrew already installed."
fi

# ---- 2. Activate Homebrew environment --------------------------------------
eval "$("${BREW_PREFIX}/bin/brew" shellenv)"

# ---- 3. Install Python 3 if not present ------------------------------------
if ! command -v python3 &>/dev/null; then
    echo "[brew-init] Installing Python 3 ..."
    brew install python3
else
    echo "[brew-init] Python 3 already available: $(python3 --version)"
fi

# ---- 4. Install supercronic (rootless cron for containers) if not present --
# supercronic reads a standard crontab file and runs jobs as the current user
# without requiring a cron daemon or root privileges.
if ! command -v supercronic &>/dev/null; then
    echo "[brew-init] Installing supercronic ..."
    brew install supercronic
else
    echo "[brew-init] supercronic already available."
fi

# ---- 5. Start supercronic in background if a crontab file exists -----------
# Place scheduled jobs in openclaw-config/crontab on the host
# (maps to /home/node/.openclaw/crontab inside the container).
# Uses standard 5-field cron syntax, e.g.:
#   0 * * * *  python3 /home/node/.openclaw/workspace/my-script.py
if [ -f "${CRONTAB_FILE}" ] && [ -s "${CRONTAB_FILE}" ]; then
    echo "[brew-init] Starting supercronic with ${CRONTAB_FILE} ..."
    supercronic "${CRONTAB_FILE}" &
fi

# ---- 6. Hand off to the main process (node openclaw.mjs gateway ...) -------
echo "[brew-init] Initialization complete. Executing: $*"
exec "$@"
