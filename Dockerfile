FROM ghcr.io/openclaw/openclaw:latest

# Store the LM Studio config as a seed template (not in .openclaw — volume will override it)
COPY --chown=node:node openclaw.json /opt/openclaw-seed/openclaw.json

# Copy entrypoint script (--chmod sets executable permission without a separate RUN)
COPY --chmod=755 scripts/start.sh /usr/local/bin/start.sh

# Set working directory to workspace
WORKDIR /workspace

# Healthcheck: verify OpenClaw gateway is responsive
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:18789/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/start.sh"]
