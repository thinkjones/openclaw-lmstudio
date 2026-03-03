FROM ghcr.io/openclaw/openclaw:latest

# --- Optional build-time dependencies ---
# Set to "true" via docker-compose build args to include system packages.
# When false (default), no apt-get runs — zero image size impact.
ARG INSTALL_CHROMIUM=false
ARG INSTALL_FFMPEG=false
ARG INSTALL_HOMEBREW=false

USER root
RUN set -eux; \
    PACKAGES=""; \
    if [ "${INSTALL_CHROMIUM}" = "true" ]; then \
      PACKAGES="${PACKAGES} chromium fonts-liberation libatk-bridge2.0-0 \
        libatk1.0-0 libcups2 libdbus-1-3 libdrm2 libgbm1 libnspr4 libnss3 \
        libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 xdg-utils"; \
    fi; \
    if [ "${INSTALL_FFMPEG}" = "true" ]; then \
      PACKAGES="${PACKAGES} ffmpeg"; \
    fi; \
    if [ "${INSTALL_HOMEBREW}" = "true" ]; then \
      PACKAGES="${PACKAGES} build-essential procps curl file git"; \
    fi; \
    if [ -n "${PACKAGES}" ]; then \
      apt-get update && \
      apt-get install -y --no-install-recommends ${PACKAGES} && \
      rm -rf /var/lib/apt/lists/*; \
    fi
# --- Homebrew + OpenClaw tap ---
# Homebrew must be installed as root (creates /home/linuxbrew/.linuxbrew),
# then ownership is transferred to node so `brew install` works unprivileged.
RUN if [ "${INSTALL_HOMEBREW}" = "true" ]; then \
      mkdir -p /home/linuxbrew/.linuxbrew && \
      chown -R node:node /home/linuxbrew; \
    fi
USER node
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"
RUN if [ "${INSTALL_HOMEBREW}" = "true" ]; then \
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
      brew tap steipete/tap && \
      brew install steipete/tap/gogcli gh; \
    fi

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
