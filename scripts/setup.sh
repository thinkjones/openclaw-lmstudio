#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# setup.sh — One-command setup for openclaw-lmstudio
# Supports LM Studio (local) and Claude (Anthropic API) providers.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"

cd "${PROJECT_DIR}"

echo "========================================="
echo "  openclaw-lmstudio setup"
echo "========================================="
echo ""

# --- Check prerequisites ---
if ! command -v docker &> /dev/null; then
  echo "ERROR: Docker is not installed. Please install Docker Desktop first."
  echo "  https://www.docker.com/products/docker-desktop/"
  exit 1
fi

if ! docker info &> /dev/null 2>&1; then
  echo "ERROR: Docker daemon is not running. Please start Docker Desktop."
  exit 1
fi

# --- Create .env if missing ---
if [ ! -f .env ]; then
  echo "Creating .env from .env.example..."
  cp .env.example .env
  echo "  Please edit .env to configure your provider."
  echo ""
  echo "  Set PROVIDER=lmstudio (default) or PROVIDER=claude"
  echo "  Then fill in the required variables for your chosen provider."
  echo ""
  exit 0
fi

# --- Load environment ---
set -a
source .env
set +a

PROVIDER="${PROVIDER:-lmstudio}"

# --- Create workspace directory if needed ---
WORKSPACE="${WORKSPACE_PATH:-./workspace}"
if [ ! -d "${WORKSPACE}" ]; then
  echo "Creating workspace directory: ${WORKSPACE}"
  mkdir -p "${WORKSPACE}"
fi

# --- Create .openclaw-files directory structure (bind-mounted into container) ---
if [ ! -d ".openclaw-files/.openclaw" ]; then
  echo "Creating .openclaw-files/.openclaw directory..."
  mkdir -p ".openclaw-files/.openclaw"
fi

if [ ! -d ".openclaw-files/.local/bin" ]; then
  echo "Creating .openclaw-files/.local/bin directory..."
  mkdir -p ".openclaw-files/.local/bin"
fi

if [ ! -d ".openclaw-files/.config" ]; then
  echo "Creating .openclaw-files/.config directory..."
  mkdir -p ".openclaw-files/.config"
fi

# --- Generate openclaw.json based on provider ---
echo "Generating openclaw.json (provider: ${PROVIDER})..."

case "${PROVIDER}" in
  lmstudio)
    MODEL_ID="${LMSTUDIO_MODEL_ID:-qwen3-8b}"
    MODEL_NAME="${LMSTUDIO_MODEL_NAME:-Local Model}"
    CONTEXT_WINDOW="${LMSTUDIO_CONTEXT_WINDOW:-32768}"
    MAX_TOKENS="${LMSTUDIO_MAX_TOKENS:-4096}"
    PORT="${LMSTUDIO_PORT:-1234}"

    cat > .openclaw-files/.openclaw/openclaw.json << ENDJSON
{
  "models": {
    "providers": {
      "lmstudio": {
        "baseUrl": "http://host.docker.internal:${PORT}/v1",
        "apiKey": "lm-studio",
        "api": "openai-completions",
        "models": [
          {
            "id": "${MODEL_ID}",
            "name": "${MODEL_NAME}",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": ${CONTEXT_WINDOW},
            "maxTokens": ${MAX_TOKENS}
          }
        ]
      }
    }
  },
  "gateway": {
    "mode": "local",
    "bind": "lan"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "lmstudio/${MODEL_ID}"
      },
      "sandbox": {
        "mode": "non-main"
      }
    }
  }
}
ENDJSON

    echo "  Provider:  LM Studio (local)"
    echo "  Model:     ${MODEL_NAME} (${MODEL_ID})"
    echo "  Endpoint:  http://host.docker.internal:${PORT}/v1"
    ;;

  claude)
    ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
    CLAUDE_MODEL="${CLAUDE_MODEL:-anthropic/claude-sonnet-4-5}"

    if [ -z "${ANTHROPIC_API_KEY}" ]; then
      echo ""
      echo "ERROR: ANTHROPIC_API_KEY is required when PROVIDER=claude"
      echo ""
      echo "  1. Get your API key from https://console.anthropic.com/settings/keys"
      echo "  2. Set ANTHROPIC_API_KEY in your .env file"
      echo "  3. Re-run this script"
      echo ""
      exit 1
    fi

    cat > .openclaw-files/.openclaw/openclaw.json << ENDJSON
{
  "env": {
    "ANTHROPIC_API_KEY": "${ANTHROPIC_API_KEY}"
  },
  "gateway": {
    "mode": "local",
    "bind": "lan"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "${CLAUDE_MODEL}"
      },
      "sandbox": {
        "mode": "non-main"
      }
    }
  }
}
ENDJSON

    echo "  Provider:  Claude (Anthropic API)"
    echo "  Model:     ${CLAUDE_MODEL}"
    echo "  API Key:   ${ANTHROPIC_API_KEY:0:12}..."
    ;;

  *)
    echo "ERROR: Unknown PROVIDER '${PROVIDER}'"
    echo "  Valid values: lmstudio, claude"
    exit 1
    ;;
esac

echo ""

# --- Build Docker image ---
echo "Building Docker image: openclaw-lmstudio..."
docker compose build
echo ""

# --- Start container ---
echo "Starting openclaw-lmstudio..."
docker compose up -d
echo ""

# --- Done ---
echo "========================================="
echo "  Setup complete!"
echo "========================================="
echo ""
echo "  Provider:            ${PROVIDER}"
echo "  OpenClaw UI:         http://127.0.0.1:18789"
echo "  Workspace mounted:   /workspace (-> ${WORKSPACE})"
echo ""
echo "  Commands:"
echo "    docker compose logs -f     # Watch logs"
echo "    docker compose down        # Stop"
echo "    docker compose restart     # Restart"
echo ""
echo "  To open the OpenClaw TUI:"
echo "    docker compose exec -it openclaw node /app/dist/index.js tui"
echo ""
echo "  TIP: Have an existing ~/.openclaw installation?"
echo "    Run ./scripts/copy-config.sh to copy your auth profiles and settings"
echo "    into .openclaw-files/.openclaw/ for use by the container."
echo ""
