# openclaw-lmstudio

OpenClaw securely running inside a Docker Sandbox, using LM Studio as the local model backend via a Bun/TypeScript bridge.

## Architecture

```text
OpenClaw → bridge (localhost:54321) → LM Studio (host.docker.internal:1234)
```

## Prerequisites

- [Docker Desktop](https://www.docker.com/) with Docker Sandboxes enabled.
- [LM Studio](https://lmstudio.ai/) with Local Server and "Serve on Local Network" enabled.

## Quick Start

1. **Pull the image:**
   ```bash
   docker pull ghcr.io/thinkjones/openclaw-lmstudio:latest
   ```

2. **Create the sandbox:**
   ```bash
   docker sandbox create --name openclaw-dev openclaw-lmstudio:latest
   ```

3. **Run OpenClaw (default model):**
   ```bash
   docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh
   ```

## Usage

**List available LM Studio models:**
```bash
docker sandbox exec openclaw-dev /bin/bash /sandbox/start-openclaw.sh list
```

**Run with default model (`openai/gpt-oss-20b`):**
```bash
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh
```

**Run with specific model:**
```bash
docker sandbox exec -it openclaw-dev /bin/bash /sandbox/start-openclaw.sh "my-model-name"
```

## How to Build Locally

This image is NOT built via a traditional Dockerfile. It is created by capturing a sandbox state.

1. Create a development sandbox:
   ```bash
   docker sandbox create --name env-openclaw shell .
   ```
2. Manually install Node 22, Bun, and OpenClaw inside the sandbox environment.
3. Save the state as a new Docker image:
   ```bash
   docker sandbox save env-openclaw openclaw-lmstudio:latest
   ```

## References

- [Run OpenClaw securely in Docker Sandboxes](https://www.docker.com/blog/run-openclaw-securely-in-docker-sandboxes/)
