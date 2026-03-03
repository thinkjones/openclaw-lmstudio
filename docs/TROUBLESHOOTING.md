# Troubleshooting

## "Cannot reach LM Studio"

The container cannot connect to LM Studio on your host machine.

**Fixes:**

1. **Is LM Studio running?** Open LM Studio and go to the Local Server tab.
2. **Is the server started?** Click "Start Server" in LM Studio.
3. **Is a model loaded?** Select and load a model in the Models tab.
4. **Check the port.** Default is 1234. If you changed it, update `LMSTUDIO_PORT` in `.env`.

### Linux-Specific

`host.docker.internal` may not resolve on some Linux setups even with the `extra_hosts` directive. Try:

```bash
# Find your LAN IP
ip addr show | grep "inet " | grep -v 127.0.0.1

# Use it directly in .env (not LMSTUDIO_PORT, override the full URL)
# Edit docker-compose.yml: change host.docker.internal to your LAN IP
```

## Permission Errors on Workspace

```
Error: EACCES: permission denied, open '/workspace/...'
```

The container runs as user `node` (uid 1000). If your host files are owned by a different UID:

```bash
# Option 1: Match ownership
sudo chown -R 1000:1000 /path/to/your/workspace

# Option 2: Use more permissive permissions
chmod -R a+rw /path/to/your/workspace
```

## Container Exits Immediately

Check the logs:

```bash
docker compose logs openclaw
```

Common causes:
- LM Studio not reachable (see above)
- Invalid `openclaw.json` — re-run `./scripts/setup.sh` to regenerate
- Port 18789 already in use — change it in `docker-compose.yml`

## "Model not found" in OpenClaw

The model ID in `openclaw.json` doesn't match what LM Studio is serving.

1. Check which model LM Studio is serving: look at the Local Server tab
2. The model ID must match exactly. Run:
   ```bash
   curl http://localhost:1234/v1/models
   ```
3. Copy the `id` field and set it as `LMSTUDIO_MODEL_ID` in `.env`
4. Re-run `./scripts/setup.sh`

## Slow Responses

- **CPU inference:** If you don't have a GPU, responses will be slow. This is expected.
- **Model too large:** Try a smaller model (8B instead of 33B).
- **Context window too large:** Reduce `LMSTUDIO_CONTEXT_WINDOW` in `.env`.
- **Not enough VRAM:** The model may be partially offloaded to CPU. Check LM Studio's resource monitor.

## Container Uses Too Much Memory

Adjust resource limits in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 1g  # Reduce from 2g
```

Note: This is the container's memory, not the model's VRAM. LM Studio runs on the host and manages GPU memory separately.

## "Tokens to keep from initial prompt is greater than context length"

The model's context window in LM Studio is too small for OpenClaw's system prompts.

**Fix:** In LM Studio, increase the model's **Context Length** to at least **8192** (ideally 16384 or 32768). Restart the server after changing.

## Changed Model in .env But Container Uses Old Model

The config is baked into the Docker image and seeded into `.openclaw-files/.openclaw/` on first run. You need to clear the seeded config:

```bash
docker compose down
rm -rf .openclaw-files/.openclaw/*
./scripts/setup.sh
```

## Web UI Not Accessible

If `http://127.0.0.1:18789` returns an empty reply or won't load:

- The gateway must have `"bind": "lan"` in its config (set by default in this project)
- Check logs: `docker compose logs openclaw`
- Verify the container is running: `docker compose ps`

## Rebuilding After Changes

```bash
# Full rebuild (after .env or config changes)
docker compose down
rm -rf .openclaw-files/.openclaw/*
./scripts/setup.sh

# Rebuild image only (after Dockerfile changes)
docker compose down
docker compose build --no-cache
docker compose up -d
```

## Claude: "ANTHROPIC_API_KEY is required"

You set `PROVIDER=claude` but didn't provide an API key.

1. Get your key from [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
2. Set `ANTHROPIC_API_KEY=sk-ant-api03-...` in `.env`
3. Re-run `./scripts/setup.sh`

## Claude: "Invalid API key" or 401 Errors

- Verify your key starts with `sk-ant-api03-`
- Check it hasn't expired or been revoked in the Anthropic console
- Ensure no extra whitespace around the key in `.env`
- Run `openclaw doctor --fix` inside the container:
  ```bash
  docker compose exec openclaw node /app/dist/index.js doctor --fix
  ```

## Claude: High API Costs

Claude is billed per token. To reduce costs:

- Use `anthropic/claude-sonnet-4-5` (cheaper) instead of `anthropic/claude-opus-4-5`
- Limit `maxTokens` in the config
- OpenClaw enables prompt caching automatically, which reduces repeated prompt costs

## macOS-Only Skills

The following OpenClaw skills require macOS-specific frameworks and **cannot run inside the Docker container**:

| Skill | Dependency | Why It Can't Work |
|-------|-----------|-------------------|
| camsnap | AVFoundation | macOS camera framework |
| nano-pdf | macOS PDF APIs | Native PDF rendering |
| sag | macOS frameworks | System-level access |
| xurl | macOS frameworks | System-level access |

These skills will only work when running OpenClaw natively on macOS.

## Optional Dependencies Not Working

If a skill fails with "command not found" for tools like `go`, `uv`, `ffmpeg`, or `chromium`:

1. Check that the corresponding flag is set in `.env`:
   ```bash
   grep INSTALL_ .env
   ```

2. **Build-time deps** (`INSTALL_CHROMIUM`, `INSTALL_FFMPEG`) require a rebuild:
   ```bash
   docker compose down
   docker compose build --no-cache
   docker compose up -d
   ```

3. **Runtime deps** (`INSTALL_GO`, `INSTALL_UV`, `INSTALL_NPM_GLOBALS`) are installed on container start. Check the logs for `[deps]` messages:
   ```bash
   docker compose logs openclaw | grep "\[deps\]"
   ```

4. If a runtime install failed (e.g., network issue), restart the container to retry:
   ```bash
   docker compose restart
   ```

## Getting Help

- [OpenClaw Docs](https://docs.openclaw.ai)
- [LM Studio Docs](https://lmstudio.ai/docs)
- [Anthropic API Docs](https://docs.anthropic.com)
- [Docker Desktop Docs](https://docs.docker.com/desktop/)
