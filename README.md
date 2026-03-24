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

There are two ways to get started — choose the one that fits your situation:

### Path A: Fresh Install (no existing OpenClaw)

Use this if you've never installed OpenClaw before, or want to start from a clean config.

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

`setup.sh` generates a fresh `openclaw.json` from your `.env`, creates the `.openclaw-files/` directory structure, builds the Docker image, and starts the container.

### Path B: Migrate Existing Config (recommended if you have `~/.openclaw`)

Use this if you already have OpenClaw installed at `~/.openclaw` with auth profiles, API keys, and settings configured.

```bash
# 1. Clone the repo
git clone https://github.com/thinkjones/openclaw-lmstudio.git
cd openclaw-lmstudio

# 2. Copy your existing config
chmod +x scripts/copy-config.sh scripts/start.sh
./scripts/copy-config.sh

# 3. Build and run
docker compose build
docker compose up -d
```

`copy-config.sh` copies your auth profiles, credentials, agent configs, and settings into `.openclaw-files/.openclaw/`. It patches `gateway.bind` to `"lan"` for Docker networking and removes host-specific paths. The script only runs once — run with `--force` to overwrite.

---

## Using OpenClaw

### Opening the UI

Go to **http://127.0.0.1:18789** in your browser. This is the main way to interact with OpenClaw — it provides a chat interface where you can give the agent tasks, review its work, and manage sessions.

### Authenticating with Claude (device auth)

When using `PROVIDER=claude`, OpenClaw may prompt you to authenticate via Anthropic's device auth flow. You'll see a URL in the logs — open it in your browser, sign in to your Anthropic account, and authorize the connection. Your auth token is stored in `.openclaw-files/.openclaw/` and persists across container restarts.

**API key types:**

- `sk-ant-api03-*` — Direct API key. Billed per token, no device auth needed. Set this in `.env` as `ANTHROPIC_API_KEY`.
- `sk-ant-oat01-*` — OAuth/setup token. Used with the device auth flow described above. You don't set this manually — it's created automatically when you complete device auth.

### CLI Access

You can also interact with OpenClaw from your terminal:

```bash
# Open a shell inside the container
docker compose exec -it openclaw bash

# Open the OpenClaw TUI (terminal interface)
docker compose exec -it openclaw node /app/dist/index.js tui

# Send a one-off message
docker compose exec openclaw node /app/dist/index.js agent --message "Hello"

# Check gateway status
docker compose exec openclaw node /app/dist/index.js status
```

### Checking Logs

```bash
# Follow logs in real time
docker compose logs -f
```

### Tools Installed at Runtime

OpenClaw may install tools like `gh` (GitHub CLI) and `mise` inside the container as needed. These persist in `.openclaw-files/.local/` across restarts — no need to reinstall after stopping and starting the container.

For skill-specific tools (Go, uv, Chromium, ffmpeg, etc.), enable the corresponding `INSTALL_*` flags in `.env`. See [Optional Dependencies](#optional-dependencies).

### Common Operations

```bash
# Stop the container
docker compose down

# Restart
docker compose restart

# Rebuild after Dockerfile changes (preserves skills, auth, config)
docker compose down
docker compose build --no-cache
docker compose up -d

# Verify included tools are working
docker compose exec openclaw jq --version
docker compose exec openclaw brew --version
docker compose exec openclaw gh --version
```

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

### Included Tools

The image always includes: `jq`, Homebrew, `gogcli`, and `gh`. These are available without any flags.

### Optional Dependencies

These flags install additional tools needed by specific OpenClaw skills. All default to `false`.

| Variable | Default | Rebuild? | Description |
|----------|---------|----------|-------------|
| `INSTALL_CHROMIUM` | `false` | Yes | Chromium + X11/font libs (~400 MB) for web browsing skills |
| `INSTALL_FFMPEG` | `false` | Yes | ffmpeg (~80 MB) for summarize, video-frames skills |
| `INSTALL_GO` | `false` | No | Go runtime (~150 MB) for blogwatcher skill |
| `INSTALL_UV` | `false` | No | uv Python package manager (~30 MB) for mcporter skill |
| `INSTALL_NPM_GLOBALS` | `false` | No | npm globals: clawhub, gifgrep |

**Build-time deps** (Chromium, ffmpeg) are baked into the Docker image — changing them requires `docker compose build --no-cache`.

**Runtime deps** (Go, uv, npm globals) are installed on container start and persist on the `.local` volume.

After changing optional dependency flags in `.env`, rebuild the image:

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

> **Note:** Only run `rm -rf .openclaw-files/.openclaw/*` when switching providers or resetting config. This erases skills, auth tokens, and all runtime config.

### Support OPEN ROUTER
```
openclaw onboard --auth-choice apiKey --token-provider openrouter --token "$OPENROUTER_API_KEY"

docker compose exec openclaw openclaw onboard --auth-choice apiKey --token-provider openrouter --token "$OPENROUTER_API_KEY"
```

## Mounting Your Existing Workspace

To work on an existing project, set `WORKSPACE_PATH` in `.env`:

```bash
WORKSPACE_PATH=/Users/you/projects/my-app
```

Then re-run `./scripts/setup.sh`. OpenClaw will see your project files at `/workspace` inside the container.

## Volume Structure

All persistent data lives under a single `.openclaw-files/` directory, which is gitignored. Both `setup.sh` and `copy-config.sh` create this structure:

```
.openclaw-files/
  .openclaw/    → /home/node/.openclaw   (config, auth, agents, settings)
  .local/       → /home/node/.local      (runtime binaries: gh, gog, mise, etc.)
  .config/      → /home/node/.config     (runtime config: gh, git, mise, etc.)
```

| Subdirectory | Populated by | Contents |
|---|---|---|
| `.openclaw/` | `setup.sh` (generated) or `copy-config.sh` (copied from `~/.openclaw`) | `openclaw.json`, auth profiles, agent configs, credentials |
| `.local/` | OpenClaw at runtime (e.g. `gh auth login`, tool installs) | Binaries in `.local/bin/` — persists across container restarts |
| `.config/` | OpenClaw at runtime | App config dirs (gh, git, mise) — persists across container restarts |

## Switching Providers

To switch between LM Studio and Claude:

1. Edit `PROVIDER` in `.env` (and fill in the required variables)
2. Clear config and rebuild:
   ```bash
   docker compose down
   rm -rf .openclaw-files/.openclaw/*
   ./scripts/setup.sh
   ```

> **Warning:** Clearing `.openclaw-files/.openclaw/*` removes all skills, auth tokens, and runtime config. This is necessary when switching providers because the config structure differs.

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
- **Config changes not taking effect** — For Dockerfile changes, run `docker compose build --no-cache && docker compose up -d`. Only run `rm -rf .openclaw-files/.openclaw/*` when switching providers (this erases skills and auth)

## Recommended Models

See [docs/MODELS.md](docs/MODELS.md) for local model recommendations by GPU tier.

## License

MIT
