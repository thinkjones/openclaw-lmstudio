FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# OpenClaw
RUN npm install -g @anthropics/claude-code

# Sandbox scripts
COPY sandbox/model-runner-bridge.ts /sandbox/model-runner-bridge.ts
COPY sandbox/start-openclaw.sh /sandbox/start-openclaw.sh
RUN chmod +x /sandbox/start-openclaw.sh

WORKDIR /root
