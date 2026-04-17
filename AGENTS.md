# AGENTS.md - Llama.cpp Docker Project

## Project Overview

Docker Compose setup for llama.cpp with CUDA support for running LLMs on GPU. Single-service architecture — one model loaded at a time, swapped via env file.

- **Hardware:** NVIDIA RTX 3060 12GB, 128GB RAM, Intel Xeon E5-2697 v3 (14 cores / 28 threads)
- **System:** Linux (Arch) — local server
- **llama.cpp:** PR #21343 + PR #20050 patch (KV cache retry fix)
- **CUDA:** 12.4

## Directory Structure

```
llama/
├── AGENTS.md
├── README.md
├── Dockerfile
├── docker-compose.yml
├── sync.sh
├── .env.example
├── .gitignore
├── LICENSE
└── configs/
    ├── gemma4-26b-unsloth.env
    ├── gemma4-e4b-q5-bartowski-opencode.env
    ├── qwen3coder-30b-a3b-q6-unsloth.env
    └── qwen35-35b-a3b-q4-unsloth.env
```

## Available Configs

| File | Model | Context | VRAM | t/s |
|------|-------|---------|------|-----|
| gemma4-26b-unsloth.env | unsloth/gemma-4-26B-A4B-it-GGUF:Q4_K_M | 128K | ~5GB + ~12GB RAM | - |
| gemma4-e4b-q5-bartowski-opencode.env | bartowski/google_gemma-4-E4B-it-GGUF:Q5_K_M | 128K | ~5.7GB | ~24 |
| qwen3coder-30b-a3b-q6-unsloth.env | unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q6_K | 128K | ~3-4GB + ~25GB RAM | ~15-20 |
| qwen35-35b-a3b-q4-unsloth.env | unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL | 131K | ~2GB + ~19GB RAM | ~15-20 |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| MODEL | - | HuggingFace model (repo:quant) |
| PORT | 8089 | Server port |
| HOST | 0.0.0.0 | Listen address |
| CTX | 32768 | Context size (tokens) |
| NGLAYERS | 999 | GPU layers (999=all, 0=CPU) |
| CPUMOE | exps=CPU | MoE experts on CPU |
| FLASHATTN | off | Flash Attention |
| BATCH | 1024 | Batch size |
| UBATCH | 512 | Physical batch |
| THREADS | 20 | CPU threads |
| THREADS_BATCH | 20 | Batch CPU threads |
| PARALLEL | 1 | Parallel request slots |
| CACHE_TYPE_K | q4_0 | KV cache type (K) |
| CACHE_TYPE_V | q4_0 | KV cache type (V) |

## Server Management (sync.sh)

```bash
./sync.sh push      # Sync files to remote server
./sync.sh deploy    # Sync + restart container
./sync.sh rebuild   # Sync + full rebuild + restart
./sync.sh start     # Start container
./sync.sh stop      # Stop container
./sync.sh restart   # Restart container
./sync.sh status    # Container + GPU status
./sync.sh health    # Health check
./sync.sh logs      # Container logs
./sync.sh config    # Show current config
./sync.sh ssh       # SSH to server
```

## Starting with a Config

```bash
# Local
docker compose --env-file configs/gemma4-e4b-q5-bartowski-opencode.env up -d

# Remote
ssh ag@127.0.0.1 "cd ~/llama && docker compose --env-file configs/gemma4-e4b-q5-bartowski-opencode.env up -d"

# Health check
curl http://127.0.0.1:8089/health
```

## Build

```bash
docker compose up -d --build
```

| Build Arg | Default | Description |
|-----------|---------|-------------|
| PR_NUMBER | 21343 | llama.cpp PR to build |
| BUILD_JOBS | 20 | Parallel build jobs |
| GH_TOKEN | (empty) | GitHub token for private PRs |

## Performance Notes

- **Gemma 4 E4B (SWA):** 128K context costs same VRAM as 32K — only 4 global attention layers scale with context. Q6_K_L is the best quant that fits on 12GB; Q8 is likely OOM.
- **MoE models (Qwen3.5, Qwen3-Coder, Gemma 4 26B):** Backbone on GPU, expert weights in RAM via `exps=CPU`. Speed limited by CPU RAM bandwidth.
- **Qwen3.5-35B hybrid SSM:** Only 10 attention layers have KV cache (SSM layers don't), making 131K context very cheap (~720MB KV).
- **THREADS=20:** Utilizes Xeon E5-2697 v3 (28 threads) for CPU-side MoE expert computation.
- **Q4 KV cache:** Use `CACHE_TYPE_K/V=q4_0` to fit large contexts in 12GB VRAM.
- **NGLAYERS=999:** Auto-caps at the model's actual layer count — safe to use for all configs; no need to look up exact layer counts.
- **Model downloads:** Models are fetched from HuggingFace via `-hf` flag on first run and cached in `/root/.cache/huggingface/`. First startup is slow; subsequent startups load from cache.
- **toolParser hermes:** Kept intentionally for Qwen3 series (Qwen3-Coder, Qwen3.5) which use Hermes tool call format. Do not remove.

## Known Constraints

- **No SSL** — Server runs on HTTP (local network only)
- **One model at a time** — Single container, swap via env file + restart
- **MoE speed** — Expert weights on CPU adds latency; Gemma 4 E4B is fastest for interactive use

## opencode Integration

Config: `opencode.json` — provider `llama` at `http://127.0.0.1:8089/v1`

| opencode model ID | Config to load                       |
|-------------------|--------------------------------------|
| gemma4:26b        | gemma4-26b-unsloth.env               |
| gemma4:e4b-q5     | gemma4-e4b-q5-bartowski-opencode.env |
| qwen3coder:30b    | qwen3coder-30b-a3b-q6-unsloth.env    |
| qwen35:35b        | qwen35-35b-a3b-q4-unsloth.env        |

## Git Workflow

- Single branch: `master`, direct commits
- Conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`

## File Rules

- **Dockerfile** — Do not modify without explicit approval
- **configs/*.env** — Add new configs following naming pattern: `{model}-{variant}-{quant}-{provider}.env`
- Never commit `.env`, credentials, or tokens
