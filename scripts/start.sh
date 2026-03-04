#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# start.sh — Entrypoint for openclaw-lmstudio container
# Validates provider connectivity before launching OpenClaw gateway.
# =============================================================================

PROVIDER="${PROVIDER:-lmstudio}"
LMSTUDIO_URL="${LMSTUDIO_BASE_URL:-http://host.docker.internal:1234}"
MAX_RETRIES=10
RETRY_DELAY=3
OPENCLAW_DIR="/home/node/.openclaw"
SEED_DIR="/opt/openclaw-seed"

# --- Seed config on first run ---
if [ ! -f "${OPENCLAW_DIR}/openclaw.json" ]; then
  echo "First run: seeding OpenClaw config..."
  mkdir -p "${OPENCLAW_DIR}"
  cp "${SEED_DIR}/openclaw.json" "${OPENCLAW_DIR}/openclaw.json"
fi

# --- Clean up legacy auth-profiles.json (written by older start.sh) ---
# OpenClaw now reads ANTHROPIC_API_KEY from the environment directly.
# The old hand-written auth-profiles.json causes "ignored invalid auth profile" warnings.
LEGACY_AUTH="${OPENCLAW_DIR}/agents/main/agent/auth-profiles.json"
if [ -f "${LEGACY_AUTH}" ]; then
  echo "Removing legacy auth-profiles.json (no longer needed)..."
  rm -f "${LEGACY_AUTH}"
fi

# --- Ensure Node compile cache directory exists ---
if [ -n "${NODE_COMPILE_CACHE:-}" ]; then
  mkdir -p "${NODE_COMPILE_CACHE}"
fi

# --- Ensure user-local bin directory exists and is on PATH ---
LOCAL_BIN="/home/node/.local/bin"
mkdir -p "${LOCAL_BIN}"
export PATH="${LOCAL_BIN}:${PATH}"

# --- Optional runtime dependencies ---
# Installed once, persisted on the .local volume. Each check is idempotent.
# Failures are non-fatal (warn and continue).

install_go() {
  if [ "${INSTALL_GO:-false}" != "true" ]; then return; fi
  local GO_DIR="/home/node/.local/go"
  if [ -x "${GO_DIR}/bin/go" ]; then
    echo "[deps] Go already installed — skipping"
  else
    echo "[deps] Installing Go runtime..."
    local GO_VERSION="1.22.5"
    local ARCH
    ARCH="$(uname -m)"
    case "${ARCH}" in
      x86_64)  ARCH="amd64" ;;
      aarch64) ARCH="arm64" ;;
    esac
    local TARBALL="go${GO_VERSION}.linux-${ARCH}.tar.gz"
    if curl -fsSL "https://go.dev/dl/${TARBALL}" -o "/tmp/${TARBALL}"; then
      mkdir -p "${GO_DIR}"
      tar -C "/home/node/.local" -xzf "/tmp/${TARBALL}"
      rm -f "/tmp/${TARBALL}"
      echo "[deps] Go ${GO_VERSION} installed to ${GO_DIR}"
    else
      echo "[deps] WARNING: Failed to download Go — skill 'blogwatcher' may not work"
    fi
  fi
  export PATH="${GO_DIR}/bin:${PATH}"
  export GOPATH="/home/node/.local/gopath"
  mkdir -p "${GOPATH}"
}

install_uv() {
  if [ "${INSTALL_UV:-false}" != "true" ]; then return; fi
  if command -v uv &> /dev/null; then
    echo "[deps] uv already installed — skipping"
  else
    echo "[deps] Installing uv..."
    if curl -fsSL https://astral.sh/uv/install.sh | UV_INSTALL_DIR="/home/node/.local/bin" sh; then
      echo "[deps] uv installed"
    else
      echo "[deps] WARNING: Failed to install uv — skill 'mcporter' may not work"
    fi
  fi
}

install_npm_globals() {
  if [ "${INSTALL_NPM_GLOBALS:-false}" != "true" ]; then return; fi
  local NPM_PREFIX="/home/node/.local"
  for pkg in clawhub gifgrep; do
    if [ -x "${NPM_PREFIX}/bin/${pkg}" ]; then
      echo "[deps] ${pkg} already installed — skipping"
    else
      echo "[deps] Installing ${pkg}..."
      if npm install -g --prefix "${NPM_PREFIX}" "${pkg}" 2>/dev/null; then
        echo "[deps] ${pkg} installed"
      else
        echo "[deps] WARNING: Failed to install ${pkg}"
      fi
    fi
  done
}

install_go
install_uv
install_npm_globals

# --- Persist .bashrc customizations ---
# OpenClaw may modify .bashrc (e.g. adding PATH entries for installed tools).
# The container's /home/node/.bashrc is ephemeral, so we:
#   1. Save any .bashrc changes to the persistent volume on shutdown (via trap)
#   2. Restore them on startup from the persistent volume
PERSISTENT_BASHRC="${OPENCLAW_DIR}/.bashrc.local"
CONTAINER_BASHRC="/home/node/.bashrc"

# Restore persisted bashrc customizations
if [ -f "${PERSISTENT_BASHRC}" ]; then
  # Append persistent customizations to container's bashrc
  if ! grep -q "# openclaw-persistent-bashrc" "${CONTAINER_BASHRC}" 2>/dev/null; then
    {
      echo ""
      echo "# openclaw-persistent-bashrc"
      cat "${PERSISTENT_BASHRC}"
    } >> "${CONTAINER_BASHRC}"
  fi
fi

# Ensure .local/bin is always on PATH in .bashrc for interactive shells
if ! grep -q '\.local/bin' "${CONTAINER_BASHRC}" 2>/dev/null; then
  echo 'export PATH="/home/node/.local/bin:${PATH}"' >> "${CONTAINER_BASHRC}"
fi

# On shutdown, save any new .bashrc lines to the persistent volume
save_bashrc() {
  if [ -f "${CONTAINER_BASHRC}" ]; then
    # Extract lines added after our marker (or save the whole file if no marker)
    if grep -q "# openclaw-persistent-bashrc" "${CONTAINER_BASHRC}"; then
      sed -n '/# openclaw-persistent-bashrc/,$ p' "${CONTAINER_BASHRC}" \
        | tail -n +2 > "${PERSISTENT_BASHRC}"
    else
      cp "${CONTAINER_BASHRC}" "${PERSISTENT_BASHRC}"
    fi
  fi
}
trap save_bashrc EXIT

echo "========================================="
echo "  openclaw-lmstudio (${PROVIDER})"
echo "========================================="
echo ""

case "${PROVIDER}" in
  lmstudio)
    echo "LM Studio endpoint: ${LMSTUDIO_URL}"
    echo "Workspace:           /workspace"
    echo ""

    # --- Wait for LM Studio to be reachable ---
    echo "Checking LM Studio connectivity..."
    attempt=0
    until curl -fsS "${LMSTUDIO_URL}/v1/models" > /dev/null 2>&1; do
      attempt=$((attempt + 1))
      if [ "${attempt}" -ge "${MAX_RETRIES}" ]; then
        echo ""
        echo "ERROR: Cannot reach LM Studio at ${LMSTUDIO_URL}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Is LM Studio running on your host machine?"
        echo "  2. Did you click 'Start Server' in LM Studio's Local Server tab?"
        echo "  3. Is a model loaded in LM Studio?"
        echo "  4. Is the server listening on port ${LMSTUDIO_PORT:-1234}?"
        echo ""
        echo "On Linux, you may need to use your machine's LAN IP"
        echo "instead of host.docker.internal."
        exit 1
      fi
      echo "  Waiting for LM Studio... (attempt ${attempt}/${MAX_RETRIES})"
      sleep "${RETRY_DELAY}"
    done

    echo "LM Studio is reachable."
    echo ""

    # --- List available models ---
    echo "Available models:"
    curl -sS "${LMSTUDIO_URL}/v1/models" | node -e "
      const data = [];
      process.stdin.on('data', c => data.push(c));
      process.stdin.on('end', () => {
        try {
          const models = JSON.parse(Buffer.concat(data)).data || [];
          models.forEach(m => console.log('  - ' + m.id));
          if (models.length === 0) console.log('  (none loaded — load a model in LM Studio)');
        } catch { console.log('  (could not parse model list)'); }
      });
    " 2>/dev/null || echo "  (could not retrieve model list)"
    echo ""
    ;;

  claude)
    echo "Provider:  Claude (Anthropic API)"
    echo "Workspace: /workspace"
    echo ""

    # --- Validate API key is present ---
    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
      echo "ERROR: ANTHROPIC_API_KEY environment variable is not set."
      echo ""
      echo "  Set it in your .env file and re-run setup."
      exit 1
    fi

    echo "API Key:   ${ANTHROPIC_API_KEY:0:12}..."
    echo ""

    # OpenClaw picks up ANTHROPIC_API_KEY from the environment natively.
    # No manual auth-profiles.json seeding needed.

    # --- Quick connectivity check to Anthropic API ---
    echo "Checking Anthropic API connectivity..."
    if curl -fsS --max-time 10 https://api.anthropic.com/v1/messages \
         -H "x-api-key: ${ANTHROPIC_API_KEY}" \
         -H "anthropic-version: 2023-06-01" \
         -H "content-type: application/json" \
         -d '{"model":"claude-sonnet-4-5-20241022","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}' \
         > /dev/null 2>&1; then
      echo "Anthropic API is reachable."
    else
      echo "WARNING: Could not fully verify Anthropic API (this may be normal for setup tokens)."
      echo "  OpenClaw will attempt to connect when you send a message."
    fi
    echo ""
    ;;

  *)
    echo "ERROR: Unknown PROVIDER '${PROVIDER}'"
    echo "  Valid values: lmstudio, claude"
    exit 1
    ;;
esac

# --- Launch OpenClaw ---
CMD="${1:-gateway}"
shift 2>/dev/null || true

echo "Starting OpenClaw (${CMD})..."
exec node /app/dist/index.js "${CMD}" "$@"
