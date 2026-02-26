# CLAUDE.md

## What This Is

Config/docs repo for running OpenClaw in a Docker Sandbox with LM Studio as the backend. Uses a Dockerfile for image builds and mise for task orchestration.

## Architecture

```
OpenClaw (in sandbox) → Bridge (localhost:54321) → LM Studio (host.docker.internal:1234)
```

## Key Files

| File | Role |
|------|------|
| `Dockerfile` | Image definition: Ubuntu 24.04, Node 22, Bun, OpenClaw |
| `mise.toml` | Task runner: build, push, sandbox management |
| `sandbox/model-runner-bridge.ts` | Bun HTTP proxy forwarding requests to LM Studio on the host |
| `sandbox/start-openclaw.sh` | Entry point: configures model, starts bridge, launches OpenClaw |
| `.github/workflows/build-push.yml` | CI: tags and pushes images to GHCR |
| `docs/openclaw-lmstudio-docker-sandbox-prompt.md` | Original prompt used to scaffold this repo |

## Running

```bash
docker pull ghcr.io/thinkjones/openclaw-lmstudio:latest
docker sandbox create --name openclaw-dev ghcr.io/thinkjones/openclaw-lmstudio:latest
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh          # default model
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh list     # list models
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh "model"  # specific model
```

## Building the Image

```bash
mise run build          # docker build
mise run push           # push to GHCR
mise run release        # build + push
```

## CI/CD

Push to `main` or tag `v*` triggers GitHub Actions to build the image from the Dockerfile, tag it (`latest`, semver, git SHA), and push to GHCR via `GITHUB_TOKEN`.

## Prerequisites

- Docker Desktop with Sandboxes enabled
- LM Studio running on host with "Serve on Local Network" enabled (port 1234)
