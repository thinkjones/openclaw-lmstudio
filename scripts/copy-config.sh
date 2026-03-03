#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# copy-config.sh — Copy existing ~/.openclaw config into .openclaw-files/
#
# Copies your working OpenClaw installation (auth profiles, settings, agent
# configs) so the Docker container can reuse them. Adjusts gateway.bind to
# "lan" for Docker port forwarding.
#
# Also creates empty .local/bin/ and .config/ directories (populated at
# runtime by OpenClaw, persisted by volume mounts).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
SOURCE_DIR="${HOME}/.openclaw"
TARGET_BASE="${PROJECT_DIR}/.openclaw-files"
TARGET_OPENCLAW="${TARGET_BASE}/.openclaw"

FORCE=false
if [[ "${1:-}" == "-f" || "${1:-}" == "--force" ]]; then
  FORCE=true
fi

echo "========================================="
echo "  Copy existing OpenClaw config"
echo "========================================="
echo ""

# --- Validate source exists ---
if [ ! -d "${SOURCE_DIR}" ]; then
  echo "ERROR: ${SOURCE_DIR} does not exist."
  echo "  This script copies an existing OpenClaw installation."
  echo "  If you don't have one, use ./scripts/setup.sh instead."
  exit 1
fi

if [ ! -f "${SOURCE_DIR}/openclaw.json" ]; then
  echo "ERROR: ${SOURCE_DIR}/openclaw.json not found."
  echo "  Your OpenClaw installation appears incomplete."
  exit 1
fi

# --- Run-once guard ---
if [ -f "${TARGET_OPENCLAW}/openclaw.json" ]; then
  if [ "${FORCE}" = true ]; then
    echo "WARNING: Overwriting existing config (--force)"
    echo ""
  else
    echo "Already configured: ${TARGET_OPENCLAW}/openclaw.json exists."
    echo ""
    echo "  To overwrite, run: ./scripts/copy-config.sh --force"
    exit 0
  fi
fi

# --- Directories to copy (skip large/transient data) ---
EXCLUDE_PATTERNS=(
  "--exclude=.DS_Store"
  "--exclude=logs/"
  "--exclude=sessions/"
  "--exclude=workspace/"
  "--exclude=*.jsonl"
  "--exclude=openclaw.json.bak*"
)

# --- Copy ~/.openclaw -> .openclaw-files/.openclaw/ ---
echo "Copying ${SOURCE_DIR} -> ${TARGET_OPENCLAW}..."
mkdir -p "${TARGET_OPENCLAW}"

rsync -a "${EXCLUDE_PATTERNS[@]}" "${SOURCE_DIR}/" "${TARGET_OPENCLAW}/"

echo "  Copied directory structure (excluding logs, sessions, workspace)."

# --- Create empty .local/bin/ and .config/ ---
mkdir -p "${TARGET_BASE}/.local/bin"
mkdir -p "${TARGET_BASE}/.config"
echo "  Created .local/bin/ (populated at runtime by OpenClaw)"
echo "  Created .config/ (populated at runtime)"

# --- Patch openclaw.json for Docker ---
echo "Updating openclaw.json for Docker compatibility..."

export OPENCLAW_JSON="${TARGET_OPENCLAW}/openclaw.json"

if command -v python3 &> /dev/null; then
  python3 << 'PYEOF'
import json
import sys
import os

config_path = os.environ.get("OPENCLAW_JSON", "")
if not config_path:
    sys.exit(1)

with open(config_path, "r") as f:
    config = json.load(f)

# Set gateway.bind to "lan" for Docker port forwarding
if "gateway" not in config:
    config["gateway"] = {}
config["gateway"]["bind"] = "lan"
config["gateway"]["mode"] = "local"

# Remove host-specific workspace path (container uses /workspace)
agents = config.get("agents", {})
defaults = agents.get("defaults", {})
if "workspace" in defaults:
    del defaults["workspace"]

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

PYEOF
  echo "  gateway.bind set to \"lan\""
  echo "  Removed host-specific workspace path"
else
  # Fallback: use sed for the critical gateway.bind change
  if grep -q '"bind"' "${OPENCLAW_JSON}"; then
    sed -i.bak 's/"bind"[[:space:]]*:[[:space:]]*"[^"]*"/"bind": "lan"/' "${OPENCLAW_JSON}"
    rm -f "${OPENCLAW_JSON}.bak"
  fi
  echo "  gateway.bind set to \"lan\" (sed fallback)"
  echo "  WARNING: python3 not found. Manual review of openclaw.json recommended."
fi

echo ""

# --- Verify ---
echo "Verifying..."

ERRORS=0

if [ ! -f "${TARGET_OPENCLAW}/openclaw.json" ]; then
  echo "  FAIL: openclaw.json missing"
  ERRORS=$((ERRORS + 1))
else
  echo "  OK: openclaw.json exists"
fi

if grep -q '"lan"' "${TARGET_OPENCLAW}/openclaw.json" 2>/dev/null; then
  echo "  OK: gateway.bind is \"lan\""
else
  echo "  WARN: gateway.bind may not be set to \"lan\""
fi

if [ -d "${TARGET_OPENCLAW}/agents" ]; then
  echo "  OK: agents/ directory exists"
else
  echo "  WARN: agents/ directory not found"
fi

if [ -d "${TARGET_OPENCLAW}/credentials" ]; then
  echo "  OK: credentials/ directory exists"
else
  echo "  INFO: credentials/ directory not found (may not be needed)"
fi

if [ -d "${TARGET_BASE}/.local/bin" ]; then
  echo "  OK: .local/bin/ directory exists"
else
  echo "  FAIL: .local/bin/ directory missing"
  ERRORS=$((ERRORS + 1))
fi

if [ -d "${TARGET_BASE}/.config" ]; then
  echo "  OK: .config/ directory exists"
else
  echo "  FAIL: .config/ directory missing"
  ERRORS=$((ERRORS + 1))
fi

echo ""

if [ "${ERRORS}" -gt 0 ]; then
  echo "Copy completed with ${ERRORS} error(s). Please check above."
  exit 1
fi

echo "========================================="
echo "  Config copied successfully!"
echo "========================================="
echo ""
echo "  Source:  ${SOURCE_DIR}"
echo "  Target:  ${TARGET_BASE}/"
echo "    .openclaw/  — auth profiles, settings, agent configs"
echo "    .local/     — empty (runtime binaries persist here)"
echo "    .config/    — empty (runtime config persists here)"
echo ""
echo "  Next steps:"
echo "    1. Review .openclaw-files/.openclaw/openclaw.json"
echo "    2. docker compose build && docker compose up -d"
echo "    3. docker compose logs -f"
echo ""
echo "  NOTE: Sensitive data (API keys, tokens) was copied as-is."
echo "  The .openclaw-files/ directory is in .gitignore."
echo ""
