# openclaw-lmstudio

Run [OpenClaw](https://docs.openclaw.ai) (AI coding agent) inside a Docker Sandbox with [LM Studio](https://lmstudio.ai) as the local LLM backend. No cloud APIs, no costs, full privacy.

Inspired by [Run OpenClaw Securely in Docker Sandboxes](https://www.docker.com/blog/run-openclaw-securely-in-docker-sandboxes/).

## Prerequisites

- **Docker Desktop** (macOS/Windows) or Docker Engine + Compose v2 (Linux)
- **LM Studio** installed with a model downloaded and server running
- **8GB+ RAM** recommended (for local model inference)
- **GPU** recommended (CPU inference works but is slow)

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USER/openclaw-lmstudio.git
cd openclaw-lmstudio

# 2. Configure
cp .env.example .env
# Edit .env — set LMSTUDIO_MODEL_ID to match your loaded model

# 3. Run
chmod +x scripts/setup.sh scripts/start.sh
./scripts/setup.sh
```

That's it. OpenClaw is now running at `http://127.0.0.1:18789`, connected to your local LM Studio model.

## How It Works

```
┌─────────────────────────────────────────────────┐
│  Your Machine (Host)                            │
│                                                 │
│  ┌─────────────┐     ┌──────────────────────┐  │
│  │  LM Studio  │◄────│  Docker Container     │  │
│  │  :1234/v1   │     │  ┌──────────────────┐ │  │
│  │  (GPU/CPU)  │     │  │    OpenClaw       │ │  │
│  └─────────────┘     │  │    Agent          │ │  │
│                      │  └──────────────────┘ │  │
│  ┌─────────────┐     │         │             │  │
│  │  Workspace  │◄────│────── /workspace      │  │
│  │  (your code)│     │  (bind mount, rw)     │  │
│  └─────────────┘     └──────────────────────┘  │
└─────────────────────────────────────────────────┘
```

- **LM Studio** runs on your host, serving a local model via OpenAI-compatible API
- **OpenClaw** runs inside a hardened Docker container, connected via `host.docker.internal`
- **Your workspace** is bind-mounted so OpenClaw reads/writes your actual project files

## Configuration

Edit `.env` to customize:

| Variable | Default | Description |
|----------|---------|-------------|
| `LMSTUDIO_MODEL_ID` | `qwen3-8b` | Model ID as shown in LM Studio |
| `LMSTUDIO_MODEL_NAME` | `Qwen3 8B` | Display name in OpenClaw UI |
| `LMSTUDIO_PORT` | `1234` | LM Studio server port |
| `LMSTUDIO_CONTEXT_WINDOW` | `32768` | Context window size |
| `LMSTUDIO_MAX_TOKENS` | `4096` | Max output tokens |
| `WORKSPACE_PATH` | `./workspace` | Host directory to mount |
After changing `.env`, regenerate config and restart:

```bash
docker compose down
./scripts/setup.sh
rm -rf .openclaw-data/*
docker compose build && docker compose up -d
```

The rebuild is needed because the config is baked into the Docker image and seeded into `.openclaw-data/` on first run. Clearing `.openclaw-data/` ensures the new config takes effect.

## Commands

```bash
# View logs
docker compose logs -f

# Stop
docker compose down

# Restart
docker compose restart

# Open the OpenClaw TUI (terminal UI)
docker compose exec -it openclaw node /app/dist/index.js tui

# Send a message via CLI
docker compose exec openclaw node /app/dist/index.js agent --message "Hello"

# Check gateway status
docker compose exec openclaw node /app/dist/index.js status

# Rebuild after Dockerfile changes
docker compose build --no-cache
docker compose up -d
```

## Mounting Your Existing Workspace

To work on an existing project, set `WORKSPACE_PATH` in `.env`:

```bash
WORKSPACE_PATH=/Users/you/projects/my-app
```

Then re-run `./scripts/setup.sh`. OpenClaw will see your project files at `/workspace` inside the container.

## Changing Models

1. Edit `.env` with the new model ID and name
2. Rebuild and restart:
   ```bash
   docker compose down
   ./scripts/setup.sh
   rm -rf .openclaw-data/*
   docker compose build && docker compose up -d
   ```

**Important:** In LM Studio, set the model's **Context Length** to at least **8192** (ideally 16384+). OpenClaw's system prompts are large and will fail with small context windows.

## Security

The container runs with:

- All Linux capabilities dropped, `NET_BIND_SERVICE` added back (`cap_drop: ALL` + `cap_add: NET_BIND_SERVICE`)
- No privilege escalation (`no-new-privileges`)
- Resource limits (2GB RAM, 2 CPUs, 512 PIDs)
- Non-root user (`node`, uid 1000)
- Sandbox mode for non-main agent sessions
- Gateway port published only to `127.0.0.1` (loopback)

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

**Quick fixes:**

- **"Cannot reach LM Studio"** — Start the server in LM Studio's Local Server tab and load a model
- **"tokens to keep from initial prompt is greater than context length"** — Increase Context Length in LM Studio to 8192+
- **Linux users** — Set `LMSTUDIO_HOST` to your LAN IP if `host.docker.internal` doesn't resolve
- **Permission errors** — Ensure your workspace directory is owned by your user (uid 1000)
- **Changed model in .env but not taking effect** — Run `rm -rf .openclaw-data/*` then rebuild

## Recommended Models

See [docs/MODELS.md](docs/MODELS.md) for GPU-tier recommendations.

## License

MIT
