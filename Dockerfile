FROM ghcr.io/openclaw/openclaw:latest

# --- System packages ---
# Always install: jq, Homebrew prerequisites, Python/pip for skill deps
# Optionally install: Chromium, ffmpeg (large packages, opt-in via build args)
ARG INSTALL_CHROMIUM=false
ARG INSTALL_FFMPEG=false
ARG INSTALL_QMD=false

USER root
RUN set -eux; \
    PACKAGES="jq build-essential procps curl file git python3-pip python3-venv"; \
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

# --- Make system Python writable by node user ---
# This lets the agent pip-install skill deps at runtime without root
RUN chmod -R a+w /usr/lib/python3/dist-packages/ 2>/dev/null || true && \
    chmod -R a+w /usr/local/lib/python*/dist-packages/ 2>/dev/null || true && \
    chmod a+w /usr/local/bin/

# --- Pre-install common Python skill dependencies ---
# These are needed by managed skills that can't self-install easily
RUN pip install --break-system-packages \
    duckduckgo-search \
    markitdown \
    yt-dlp

# --- uv (fast Python package manager) ---
# Lets the agent install Python packages quickly at runtime
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:/home/node/.local/bin:${PATH}"

# --- Homebrew + OpenClaw tap ---
# Homebrew installed as root, ownership transferred to node so `brew install`
# works unprivileged at runtime for brew-based skills.
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

# --- Optional: QMD CLI ---
RUN if [ "${INSTALL_QMD}" = "true" ]; then \
      curl -fsSL https://bun.sh/install | bash && \
      export PATH="/home/node/.bun/bin:${PATH}" && \
      bun install -g @tobilu/qmd; \
    fi
ENV PATH="/home/node/.bun/bin:${PATH}"

# Store the config as a seed template (not in .openclaw — volume will override it)
COPY --chown=node:node .openclaw-files/.openclaw/openclaw.json /opt/openclaw-seed/openclaw.json

# Copy entrypoint script
COPY --chmod=755 scripts/start.sh /usr/local/bin/start.sh

# Set working directory to workspace
WORKDIR /workspace

# Healthcheck: verify OpenClaw gateway is responsive
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:18789/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/start.sh"]