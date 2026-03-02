# Recommended Models

Local model quality varies significantly. Below are recommendations by GPU VRAM tier.

## Quick Reference

| VRAM | Model | Context | Best For |
|------|-------|---------|----------|
| 6-8 GB | Qwen3 8B | 32K | General coding, fast responses |
| 8-12 GB | Llama 4 Scout 12B (Q4) | 32K | Balanced quality and speed |
| 16-24 GB | DeepSeek Coder V3 33B (Q4) | 64K | Strong code generation |
| 24-48 GB | Qwen3 32B | 128K | Large context, complex tasks |
| 48+ GB | Llama 4 Scout 109B (Q4) | 128K | Near-cloud quality |

## Configuration

After downloading a model in LM Studio, update your `.env`:

```bash
LMSTUDIO_MODEL_ID=qwen3-8b          # Must match LM Studio's model ID
LMSTUDIO_MODEL_NAME=Qwen3 8B        # Display name
LMSTUDIO_CONTEXT_WINDOW=32768       # Match your model's supported context
LMSTUDIO_MAX_TOKENS=4096            # Max output per response
```

Then re-run `./scripts/setup.sh` to regenerate the config.

## Tips

- **Start small.** A fast 8B model with 32K context is better for agentic tasks than a slow 70B model.
- **Quantization matters.** Q4_K_M is the sweet spot for most setups — good quality with reasonable VRAM usage.
- **Context window vs speed.** Larger context windows consume more VRAM. If your model is slow, try reducing `LMSTUDIO_CONTEXT_WINDOW`.
- **CPU inference.** It works but is 10-50x slower. Fine for testing, not practical for real coding sessions.
- **Set `reasoning: false`.** Most local models don't support reasoning mode. The default config has this set correctly.

## Model-Specific Notes

### Qwen3 8B
- Good all-around coding model at the 8B tier
- Supports 32K context natively
- Fast inference on modern GPUs

### DeepSeek Coder V3
- Purpose-built for code generation
- Excellent at understanding codebases
- Needs 16GB+ VRAM for usable quantizations

### Llama 4 Scout
- Strong instruction-following
- Good tool-calling support (important for OpenClaw agents)
- Available in 12B and 109B variants
