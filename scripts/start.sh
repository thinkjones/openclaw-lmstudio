#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# start.sh — Entrypoint for openclaw-lmstudio container
# Validates LM Studio connectivity before launching OpenClaw.
# =============================================================================

LMSTUDIO_URL="${LMSTUDIO_BASE_URL:-http://host.docker.internal:1234}"
MAX_RETRIES=10
RETRY_DELAY=3
OPENCLAW_DIR="/home/node/.openclaw"
SEED_DIR="/opt/openclaw-seed"

# --- Seed config on first run ---
# The named volume starts empty; copy the baked-in config if openclaw.json is missing.
if [ ! -f "${OPENCLAW_DIR}/openclaw.json" ]; then
  echo "First run: seeding OpenClaw config..."
  mkdir -p "${OPENCLAW_DIR}"
  cp "${SEED_DIR}/openclaw.json" "${OPENCLAW_DIR}/openclaw.json"
fi

echo "========================================="
echo "  openclaw-lmstudio"
echo "========================================="
echo ""
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
    echo "On Linux, you may need to set LMSTUDIO_HOST in your .env file"
    echo "to your machine's LAN IP instead of host.docker.internal."
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

# --- Launch OpenClaw ---
# Default to starting the gateway if no command is provided
CMD="${1:-gateway}"
shift 2>/dev/null || true

echo "Starting OpenClaw (${CMD})..."
exec node /app/dist/index.js "${CMD}" "$@"
