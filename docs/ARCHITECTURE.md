# Architecture

## Overview

`openclaw-lmstudio` connects two components:

1. **LM Studio** (host) — Local LLM inference server exposing an OpenAI-compatible API
2. **OpenClaw** (container) — AI coding agent running in a hardened Docker sandbox

## Component Diagram

```
Host Machine
├── LM Studio (localhost:1234)
│   ├── OpenAI-compatible /v1/chat/completions endpoint
│   ├── GPU/CPU inference
│   └── Model management UI
│
├── Docker Engine
│   └── openclaw-lmstudio container
│       ├── OpenClaw agent (Node.js)
│       ├── openclaw.json (LM Studio provider config)
│       ├── /workspace (bind mount → host project)
│       └── /home/node/.openclaw (config persistence)
│
└── Workspace Directory (your code)
    └── Bind-mounted read-write into container
```

## Networking

The container reaches LM Studio on the host via `host.docker.internal`, which Docker Desktop resolves automatically. On Linux, the `extra_hosts` directive in `docker-compose.yml` maps it to the host gateway.

```
Container → host.docker.internal:1234 → LM Studio API
```

The OpenClaw gateway is exposed only on `127.0.0.1:18789` (loopback), not on all interfaces.

## Security Layers

| Layer | Mechanism |
|-------|-----------|
| Capabilities | All dropped, `NET_BIND_SERVICE` added back |
| Privileges | `no-new-privileges: true` |
| Resources | 2GB RAM, 2 CPUs, 512 PIDs max |
| User | Non-root `node` (uid 1000) |
| Network | Gateway port published only to `127.0.0.1`; agent sandboxes have `network: none` |
| Workspace | Bind mount with explicit `rw` — container cannot access other host directories |

## Configuration Flow

```
.env (user settings)
  ↓
scripts/setup.sh (reads .env, generates openclaw.json)
  ↓
openclaw.json (LM Studio provider + gateway config)
  ↓
Dockerfile (bakes openclaw.json into image at /opt/openclaw-seed/)
  ↓
scripts/start.sh (seeds config into .openclaw-data/ on first run,
                   validates LM Studio, launches OpenClaw gateway)
```

Config is seeded from the image into `.openclaw-data/` on first run. The gateway then
manages its own runtime config (auth tokens, etc.) in that directory. To apply config
changes, clear `.openclaw-data/` and rebuild the image.

## File Descriptions

| File | Purpose |
|------|---------|
| `Dockerfile` | Extends official OpenClaw image with LM Studio config and entrypoint |
| `docker-compose.yml` | Orchestration with volumes, networking, security, and resource limits |
| `openclaw.json` | OpenClaw provider config pointing to LM Studio |
| `.env` / `.env.example` | User-configurable settings (model ID, port, workspace path) |
| `scripts/setup.sh` | One-command setup: generates config, builds image, starts container |
| `scripts/start.sh` | Container entrypoint: validates LM Studio connectivity, launches OpenClaw |
