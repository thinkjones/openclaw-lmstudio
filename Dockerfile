FROM ghcr.io/openclaw/openclaw:latest

# --- System packages ---
# Always install: jq, and Homebrew prerequisites (build-essential, procps, etc.)
# Optionally install: Chromium, ffmpeg (large packages, opt-in via build args)
ARG INSTALL_CHROMIUM=false
ARG INSTALL_FFMPEG=false
ARG INSTALL_QMD=false

USER root
RUN set -eux; \
    PACKAGES="jq build-essential procps curl file git"; \
    if [ "${INSTALL_CHROMIUM}" = "true" ]; then \
      PACKAGES="${PACKAGES} chromium fonts-liberation libatk-bridge2.0-0 \
        libatk1.0-0 libcups2 libdbus-1-3 libdrm2 libgbm1 libnspr4 libnss3 \
        libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 xdg-utils"; \
    fi; \
    if [ "${INSTALL_FFMPEG}" = "true" ]; then \
      PACKAGES="${PACKAGES} ffmpeg"; \
    fi; \
    apt-get update && \
    apt-get install -y --no-install-recommends ${PACKAGES} && \
    rm -rf /var/lib/apt/lists/*

# --- Homebrew + OpenClaw tap ---
# Homebrew must be installed as root (creates /home/linuxbrew/.linuxbrew),
# then ownership is transferred to node so `brew install` works unprivileged.
RUN mkdir -p /home/linuxbrew/.linuxbrew && \
    chown -R node:node /home/linuxbrew
USER node
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    brew tap steipete/tap && \
    brew install steipete/tap/gogcli gh && \
    if [ "${INSTALL_QMD}" = "true" ]; then \
      brew install sqlite; \
    fi

# --- Optional: QMD CLI (local markdown/document processing with LLMs) ---
# Requires Bun runtime + SQLite with extensions (installed above via brew).
# QMD auto-downloads GGUF models from HuggingFace on first use.
# Install from npm (pre-built dist/), not GitHub (source-only, requires tsc build).
RUN if [ "${INSTALL_QMD}" = "true" ]; then \
      curl -fsSL https://bun.sh/install | bash && \
      export PATH="/home/node/.bun/bin:${PATH}" && \
      bun install -g @tobilu/qmd; \
    fi
ENV PATH="/home/node/.bun/bin:${PATH}"

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
