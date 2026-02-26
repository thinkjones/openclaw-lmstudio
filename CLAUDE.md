# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **configuration and documentation repository** (not a buildable software project) for running OpenClaw inside a Docker Sandbox with LM Studio as the local model backend.

**No package.json, build system, or test framework exists.** The Docker image is built manually via `docker sandbox create/save`, not via a Dockerfile.

## Architecture

```
User → OpenClaw (inside Docker Sandbox)
      → Bridge (localhost:54321, model-runner-bridge.ts via Bun)
      → LM Studio (host.docker.internal:1234 on host machine)
```

- `sandbox/model-runner-bridge.ts` — Bun HTTP proxy that forwards OpenClaw requests to LM Studio on the host
- `sandbox/start-openclaw.sh` — Entry point: configures OpenClaw JSON, starts bridge, launches OpenClaw, cleans up on exit
- `.github/workflows/build-push.yml` — CI tags and pushes pre-built images to GHCR (`ghcr.io/thinkjones/openclaw-lmstudio`)

## Running the Sandbox

```bash
# Pull and create sandbox
docker pull ghcr.io/thinkjones/openclaw-lmstudio:latest
docker sandbox create --name openclaw-dev ghcr.io/thinkjones/openclaw-lmstudio:latest

# Run (inside sandbox)
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh         # default model
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh list    # list models
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh "model-name"
```

## Building the Docker Image (manual)

The image is built manually — CI only tags/pushes already-built images:

```bash
docker sandbox create --name env-openclaw shell .
# Inside: install Node 22, Bun, OpenClaw
docker sandbox save env-openclaw openclaw-lmstudio:latest
docker tag openclaw-lmstudio:latest ghcr.io/thinkjones/openclaw-lmstudio:latest
docker push ghcr.io/thinkjones/openclaw-lmstudio:latest
```

## CI/CD

Pushing to `main` or tagging with `v*` triggers GitHub Actions to tag the image with `latest`, semver, and git SHA, then push to GHCR using `GITHUB_TOKEN`.

## Prerequisites

- Docker Desktop with Docker Sandboxes enabled
- LM Studio running on host with "Serve on Local Network" enabled (port 1234)
