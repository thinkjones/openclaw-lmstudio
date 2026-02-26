# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0]
- Initial README documentation for quick start and local building instructions.
- `start-openclaw.sh` to initialize OpenClaw and configure the current model.
- `model-runner-bridge.ts` using Bun for forwarding OpenClaw requests to LM Studio natively on the host.
- GitHub Actions workflow (`build-push.yml`) for automated GHCR tagging and publishing.
