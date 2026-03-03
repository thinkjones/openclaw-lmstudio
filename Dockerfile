FROM ghcr.io/openclaw/openclaw:latest

# Store the config as a seed template (not in .openclaw — volume will override it)
# setup.sh writes the real config to .openclaw-files/.openclaw/openclaw.json
COPY --chown=node:node .openclaw-files/.openclaw/openclaw.json /opt/openclaw-seed/openclaw.json

# Copy entrypoint script (--chmod sets executable permission without a separate RUN)
COPY --chmod=755 scripts/start.sh /usr/local/bin/start.sh

# Set working directory to workspace
WORKDIR /workspace

# Healthcheck: verify OpenClaw gateway is responsive
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:18789/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/start.sh"]
