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
- [mise](https://mise.jdx.dev/) (optional — all commands also shown as raw Docker)

### Quick Start

```bash
# Clone the repo
git clone https://github.com/thinkjones/openclaw-lmstudio.git
cd openclaw-lmstudio

# Pull and create a sandbox
mise run sandbox-create
```

Or without mise:

```bash
docker pull ghcr.io/thinkjones/openclaw-lmstudio:latest
docker sandbox create --name openclaw-lmstudio ghcr.io/thinkjones/openclaw-lmstudio:latest
```

### Usage

```bash
# Run with default model (openai/gpt-oss-20b)
mise run sandbox-run

# List available models from LM Studio
mise run sandbox-run:list

# Run with a specific model
docker sandbox exec -it openclaw-lmstudio /bin/bash /sandbox/start-openclaw.sh "your-model-name"

# Remove the sandbox when done
mise run sandbox-destroy
```

<details>
<summary>Without mise</summary>

```bash
docker sandbox exec -it openclaw-lmstudio /bin/bash /sandbox/start-openclaw.sh          # default model
docker sandbox exec -it openclaw-lmstudio /bin/bash /sandbox/start-openclaw.sh list     # list models
docker sandbox exec -it openclaw-lmstudio /bin/bash /sandbox/start-openclaw.sh "model"  # specific model
docker sandbox rm openclaw-lmstudio                                                      # remove
```

</details>

---

## For Maintainers

Requires [mise](https://mise.jdx.dev/) and Docker Desktop.

### Building the Image

The image is built from the `Dockerfile` (Ubuntu 24.04, Node 22, Bun, OpenClaw):

```bash
mise run build           # Build the Docker image locally
mise run push            # Push to GHCR
mise run release         # Build + push
```

<details>
<summary>Without mise</summary>

```bash
docker build -t ghcr.io/thinkjones/openclaw-lmstudio:latest .
docker push ghcr.io/thinkjones/openclaw-lmstudio:latest
```

</details>

### Available mise Tasks

| Task | Description |
|------|-------------|
| `mise run build` | Build the Docker image |
| `mise run push` | Push image to GHCR |
| `mise run release` | Build + push |
| `mise run sandbox-create` | Create a sandbox from the image |
| `mise run sandbox-run` | Run OpenClaw in the sandbox |
| `mise run sandbox-run:list` | List available LM Studio models |
| `mise run sandbox-destroy` | Remove the sandbox |

### Creating a Release

1. Update `CHANGELOG.md`
2. Commit and push to `main`
3. Tag with semver: `git tag v0.1.0 && git push --tags`
4. GitHub Actions builds the image and pushes with `latest`, semver, and SHA tags

### CI/CD

The GitHub Actions workflow (`.github/workflows/build-push.yml`) builds the image from the Dockerfile and pushes to GHCR with auto-generated tags (`latest`, semver, SHA) on every push to `main` or semver tag.
