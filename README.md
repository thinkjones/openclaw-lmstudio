# openclaw-lmstudio

Run [OpenClaw](https://docs.openclaw.ai) (AI coding agent) inside a Docker Sandbox with your choice of LLM backend:

- **LM Studio** — Local inference, free, full privacy
- **Claude** — Anthropic API, best-in-class reasoning

Inspired by [Run OpenClaw Securely in Docker Sandboxes](https://www.docker.com/blog/run-openclaw-securely-in-docker-sandboxes/).

## Prerequisites

- **Docker Desktop** (macOS/Windows) or Docker Engine + Compose v2 (Linux)
- **LM Studio** (if using local models) — installed with a model downloaded and server running
- **Anthropic API key** (if using Claude) — from [console.anthropic.com](https://console.anthropic.com/settings/keys)

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/thinkjones/openclaw-lmstudio.git
cd openclaw-lmstudio

# 2. Configure
cp .env.example .env
# Edit .env — choose your provider and fill in the required variables

# 3. Run
chmod +x scripts/setup.sh scripts/start.sh
./scripts/setup.sh
```

OpenClaw is now running at `http://127.0.0.1:18789`.

## Provider Setup

### Option A: LM Studio (Local, Free)

Set these in `.env`:

```bash
PROVIDER=lmstudio
LMSTUDIO_MODEL_ID=qwen3-8b        # Must match your loaded model in LM Studio
LMSTUDIO_MODEL_NAME=Qwen3 8B      # Display name
LMSTUDIO_PORT=1234                 # LM Studio server port
LMSTUDIO_CONTEXT_WINDOW=32768     # Match your model's context window
LMSTUDIO_MAX_TOKENS=4096          # Max output tokens
```

**Requirements:** LM Studio running on your host with a model loaded and server started. Set Context Length to at least **8192** in LM Studio.

### Option B: Claude (Anthropic API)

Set these in `.env`:

```bash
PROVIDER=claude
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here
CLAUDE_MODEL=anthropic/claude-sonnet-4-5    # or anthropic/claude-opus-4-5
```

**Requirements:** A valid Anthropic API key. Usage is billed per token.

## How It Works

```
┌─────────────────────────────────────────────────────┐
│  Your Machine (Host)                                │
│                                                     │
│  ┌──────────────────┐   ┌──────────────────────┐   │
│  │  LM Studio       │   │  Docker Container     │   │
│  │  :1234/v1        │◄──│  ┌──────────────────┐ │   │
│  │  (local models)  │   │  │    OpenClaw       │ │   │
│  └──────────────────┘   │  │    Agent          │ │   │
│         — or —          │  └──────────────────┘ │   │
│  ┌──────────────────┐   │         │             │   │
│  │  Anthropic API   │◄──│         │             │   │
│  │  (Claude)        │   │         │             │   │
│  └──────────────────┘   │         │             │   │
│                         │         │             │   │
│  ┌──────────────────┐   │         │             │   │
│  │  Workspace       │◄──│────── /workspace      │   │
│  │  (your code)     │   │  (bind mount, rw)     │   │
│  └──────────────────┘   └──────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

## Configuration

| Variable | Default | Provider | Description |
|----------|---------|----------|-------------|
| `PROVIDER` | `lmstudio` | Both | `lmstudio` or `claude` |
| `LMSTUDIO_MODEL_ID` | `qwen3-8b` | LM Studio | Model ID as shown in LM Studio |
| `LMSTUDIO_MODEL_NAME` | `Qwen3 8B` | LM Studio | Display name in OpenClaw UI |
| `LMSTUDIO_PORT` | `1234` | LM Studio | LM Studio server port |
| `LMSTUDIO_CONTEXT_WINDOW` | `32768` | LM Studio | Context window size |
| `LMSTUDIO_MAX_TOKENS` | `4096` | LM Studio | Max output tokens |
| `ANTHROPIC_API_KEY` | — | Claude | Your Anthropic API key |
| `CLAUDE_MODEL` | `anthropic/claude-sonnet-4-5` | Claude | Claude model to use |
| `WORKSPACE_PATH` | `./workspace` | Both | Host directory to mount |

After changing `.env`, regenerate config and restart:

```bash
docker compose down
rm -rf .openclaw-data/*
./scripts/setup.sh
```

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

## Switching Providers

To switch between LM Studio and Claude:

1. Edit `PROVIDER` in `.env` (and fill in the required variables)
2. Clear config and rebuild:
   ```bash
   docker compose down
   rm -rf .openclaw-data/*
   ./scripts/setup.sh
   ```

## Security

The container runs with:

- All Linux capabilities dropped, `NET_BIND_SERVICE` added back
- No privilege escalation (`no-new-privileges`)
- Resource limits (2GB RAM, 2 CPUs, 512 PIDs)
- Non-root user (`node`, uid 1000)
- Sandbox mode for non-main agent sessions
- Gateway port published only to `127.0.0.1` (loopback)
- Anthropic API key is stored in `openclaw.json` inside the container, not exposed in logs

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

**Quick fixes:**

- **"Cannot reach LM Studio"** — Start the server in LM Studio's Local Server tab and load a model
- **"tokens to keep from initial prompt is greater than context length"** — Increase Context Length in LM Studio to 8192+
- **"ANTHROPIC_API_KEY is required"** — Set your API key in `.env`
- **"Invalid API key"** — Verify your key starts with `sk-ant-api03-` and hasn't expired
- **Linux users** — Set `LMSTUDIO_HOST` to your LAN IP if `host.docker.internal` doesn't resolve
- **Permission errors** — Ensure your workspace directory is owned by your user (uid 1000)
- **Config changes not taking effect** — Run `rm -rf .openclaw-data/*` then rebuild

## Recommended Models

See [docs/MODELS.md](docs/MODELS.md) for local model recommendations by GPU tier.

## License

MIT
