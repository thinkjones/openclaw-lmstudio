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

Requires [mise](https://mise.jdx.dev/) and Docker Desktop.

### Building the Image

```bash
mise run build           # Build the Docker image
mise run push            # Push to GHCR
mise run release         # Build + push
```

Or without mise:

```bash
docker build -t ghcr.io/thinkjones/openclaw-lmstudio:latest .
docker push ghcr.io/thinkjones/openclaw-lmstudio:latest
```

### Sandbox Management

```bash
mise run sandbox-create  # Create a sandbox from the image
mise run sandbox-run     # Run OpenClaw in the sandbox
mise run sandbox-run:list # List available models
mise run sandbox-destroy # Remove the sandbox
```

### Creating a Release

1. Update `CHANGELOG.md`
2. Commit and push to `main`
3. Tag with semver: `git tag v0.1.0 && git push --tags`
4. GitHub Actions will automatically tag and push the image with `latest`, semver, and SHA tags

### CI/CD

The GitHub Actions workflow (`.github/workflows/build-push.yml`) builds the image from the Dockerfile and pushes to GHCR with auto-generated tags (`latest`, semver, SHA).
