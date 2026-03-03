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
      echo "WARNING: Could not verify Anthropic API connectivity."
      echo "  This may be normal if the container has limited network access."
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
