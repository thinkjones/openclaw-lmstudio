#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# setup.sh — One-command setup for openclaw-lmstudio
# Builds the image, creates workspace directory, and starts the container.
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
  echo "  Please edit .env with your LM Studio model details."
  echo "  Then re-run this script."
  echo ""
  echo "  Required: Set LMSTUDIO_MODEL_ID to match your loaded model."
  echo ""
  exit 0
fi

# --- Load environment ---
set -a
source .env
set +a

# --- Create workspace directory if needed ---
WORKSPACE="${WORKSPACE_PATH:-./workspace}"
if [ ! -d "${WORKSPACE}" ]; then
  echo "Creating workspace directory: ${WORKSPACE}"
  mkdir -p "${WORKSPACE}"
fi

# --- Create OpenClaw data directory (bind-mounted into container) ---
if [ ! -d ".openclaw-data" ]; then
  echo "Creating .openclaw-data directory..."
  mkdir -p ".openclaw-data"
fi

# --- Generate openclaw.json from template ---
echo "Generating openclaw.json..."
MODEL_ID="${LMSTUDIO_MODEL_ID:-qwen3-8b}"
MODEL_NAME="${LMSTUDIO_MODEL_NAME:-Local Model}"
CONTEXT_WINDOW="${LMSTUDIO_CONTEXT_WINDOW:-32768}"
MAX_TOKENS="${LMSTUDIO_MAX_TOKENS:-4096}"
PORT="${LMSTUDIO_PORT:-1234}"

cat > openclaw.json << ENDJSON
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

echo "  Model: ${MODEL_NAME} (${MODEL_ID})"
echo "  LM Studio: http://host.docker.internal:${PORT}/v1"
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
echo "  OpenClaw is running at: http://127.0.0.1:18789"
echo "  Workspace mounted at:   /workspace (-> ${WORKSPACE})"
echo ""
echo "  Commands:"
echo "    docker compose logs -f     # Watch logs"
echo "    docker compose down        # Stop"
echo "    docker compose restart     # Restart"
echo ""
echo "  To open the OpenClaw CLI:"
echo "    docker compose exec openclaw openclaw"
echo ""
