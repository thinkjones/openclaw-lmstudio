# openclaw-lmstudio

Run [OpenClaw](https://github.com/anthropics/claude-code) securely in a Docker Sandbox with [LM Studio](https://lmstudio.ai/) as the local model backend.

Based on the [Docker blog article](https://www.docker.com/blog/run-openclaw-securely-in-docker-sandboxes/).

## Architecture

```
OpenClaw (sandbox) → Bridge (localhost:54321) → LM Studio (host.docker.internal:1234)
```

A Bun/TypeScript HTTP proxy inside the sandbox forwards OpenClaw's model requests to LM Studio running on the host machine.

---

## For Users

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) with **Sandboxes** enabled
- [LM Studio](https://lmstudio.ai/) running on the host with **Serve on Local Network** enabled (port `1234`)

### Quick Start

```bash
# Pull the pre-built image
docker pull ghcr.io/thinkjones/openclaw-lmstudio:latest

# Create a sandbox
docker sandbox create --name openclaw-dev ghcr.io/thinkjones/openclaw-lmstudio:latest

# Run with default model (openai/gpt-oss-20b)
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh
```

### Usage

```bash
# List available models from LM Studio
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh list

# Run with a specific model
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh "your-model-name"

# Run with default model
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh
```

---

## For Maintainers

### Building the Image

This image is **not** built via a Dockerfile. It is created manually using Docker Sandbox save:

```bash
# 1. Create a fresh sandbox from a shell base
docker sandbox create --name env-openclaw shell .

# 2. Inside the sandbox, install dependencies
#    - Node.js 22
#    - Bun
#    - OpenClaw

# 3. Save the sandbox as an image
docker sandbox save env-openclaw openclaw-lmstudio:latest

# 4. Tag and push to GHCR
docker tag openclaw-lmstudio:latest ghcr.io/thinkjones/openclaw-lmstudio:latest
docker push ghcr.io/thinkjones/openclaw-lmstudio:latest
```

### Syncing Sandbox Scripts

Copy updated scripts into a running sandbox:

```bash
docker sandbox cp sandbox/model-runner-bridge.ts openclaw-dev:/sandbox/model-runner-bridge.ts
docker sandbox cp sandbox/start-openclaw.sh openclaw-dev:/sandbox/start-openclaw.sh
```

### Creating a Release

1. Update `CHANGELOG.md`
2. Commit and push to `main`
3. Tag with semver: `git tag v0.1.0 && git push --tags`
4. GitHub Actions will automatically tag and push the image with `latest`, semver, and SHA tags

### CI/CD

The GitHub Actions workflow (`.github/workflows/build-push.yml`) does **not** build images. It pulls the existing `latest` image from GHCR, re-tags it with metadata (semver, SHA), and pushes the new tags.
