FROM ghcr.io/openclaw/openclaw:latest

# --- System packages ---
# Always install: jq, Homebrew prerequisites, Python/pip for skill deps
# Optionally install: Chromium, ffmpeg (large packages, opt-in via build args)
ARG INSTALL_CHROMIUM=false
ARG INSTALL_FFMPEG=false

# --- Upgrade Node.js to v24 ---
# The base image ships Node 22; overlay Node 24 for latest features/performance.
USER root
ARG NODE_VERSION=24.14.0
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "${ARCH}" in \
      amd64) NODE_ARCH="x64" ;; \
      arm64) NODE_ARCH="arm64" ;; \
      *) echo "Unsupported arch: ${ARCH}" && exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" \
      | tar -xJ --strip-components=1 -C /usr/local/; \
    node --version

# --- System packages ---
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
    brew install steipete/tap/gogcli gh

# --- Skill dependencies (brew) ---
# Space-separated list of brew formulae to install for enabled skills.
# Override via BREW_PACKAGES build arg or .env to customise.
ARG BREW_PACKAGES=""
RUN set -eux; \
    if [ -n "${BREW_PACKAGES}" ]; then \
      for pkg in ${BREW_PACKAGES}; do \
        echo "[skill-deps] brew install ${pkg}"; \
        brew install "${pkg}" || echo "[skill-deps] WARNING: failed to install ${pkg}"; \
      done; \
      brew cleanup --prune=all 2>/dev/null || true; \
    fi

# --- Skill dependencies (npm) ---
# Space-separated list of npm packages to install globally for enabled skills.
ARG NPM_PACKAGES=""
USER root
RUN set -eux; \
    if [ -n "${NPM_PACKAGES}" ]; then \
      for pkg in ${NPM_PACKAGES}; do \
        echo "[skill-deps] npm install -g ${pkg}"; \
        npm install -g "${pkg}" || echo "[skill-deps] WARNING: failed to install ${pkg}"; \
      done; \
    fi
USER node

# Copy entrypoint script
COPY --chmod=755 scripts/start.sh /usr/local/bin/start.sh

# Set working directory to workspace
WORKDIR /workspace

# Healthcheck: verify OpenClaw gateway is responsive
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:18789/healthz || exit 1

ENTRYPOINT ["/usr/local/bin/start.sh"]