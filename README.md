# Llama.cpp Server with Docker

Docker Compose setup for llama.cpp with CUDA support, optimized for running LLM models on GPU.

## Hardware

- **System:** Linux (Arch) — local server
- **GPU:** NVIDIA RTX 3060 12GB
- **RAM:** 128GB
- **CPU:** Intel Xeon E5-2697 v3 (14 cores / 28 threads)

## Quick Start

```bash
# Build and start
docker compose up -d --build

# Check status
curl http://127.0.0.1:8089/health

# View logs
docker compose logs -f
```

## Configuration

### Using .env files

```bash
# Use Gemma 4 (default)
cp configs/gemma4-e4b-q4-unsloth.env .env
docker compose up -d

# Switch to Gemma 4 26B (MoE - partial offload)
cp configs/gemma4-26b-unsloth.env .env
docker compose up -d

# Or use --env-file directly
docker compose --env-file configs/gemma4-26b-unsloth.env up -d
```

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MODEL` | HuggingFace repo:quant | `ggml-org/gemma-4-E4B-it-GGUF:Q4_K_M` |
| `PORT` | Server port | `8089` |
| `HOST` | Listen address | `0.0.0.0` |
| `CTX` | Context size | `32768` |
| `NGLAYERS` | GPU layers (999=all, 0=CPU) | `50` |
| `CPUMOE` | MoE experts on CPU | `exps=CPU` or empty |
| `FLASHATTN` | Flash Attention | `on`, `off`, `auto` |
| `BATCH` | Batch size | `256` |
| `UBATCH` | Physical batch | `256` |
| `THREADS` | CPU threads | `20` |
| `THREADS_BATCH` | Batch CPU threads | `20` |
| `PARALLEL` | Parallel request slots | `1` |
| `CACHE_TYPE_K` | KV cache type (K) | `q4_0` |
| `CACHE_TYPE_V` | KV cache type (V) | `q4_0` |

## Parameters Explained

| Parameter | Description |
|-----------|-------------|
| `-hf` | Load model from HuggingFace |
| `--jinja` | Enable Jinja chat template (required for Gemma) |
| `-c` | Context size (tokens) |
| `-ngl` | Layers offloaded to GPU |
| `-ot exps=CPU` | Keep MoE experts in CPU (saves VRAM) |
| `-fa` | Flash Attention |
| `-b` / `-ub` | Batch sizes |
| `-t` | CPU threads |
| `-tb` | Batch CPU threads |
| `--parallel` | Parallel request slots |
| `-ctk` / `-ctv` | KV cache quantization type |
| `--mlock` | Lock model in RAM |
| `--no-mmap` | Disable memory-mapped I/O |
| `--fit off` | Disable auto-fit to VRAM |

## Available Configs

### configs/qwen35-35b-a3b-q4-unsloth.env
- Model: unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL (MoE + SSM hybrid)
- Context: 131K (native 262K; cheap — only 10 attention layers have KV cache, SSM layers don't)
- GPU layers: all (~2GB backbone on GPU, ~19GB experts in RAM)
- Multimodal: vision encoder included (images supported)
- Speed: ~15-20 t/s

### configs/qwen3coder-30b-a3b-q6-unsloth.env
- Model: unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q6_K (MoE)
- Context: 131K (native)
- GPU layers: all (~3-4GB backbone on GPU, ~25GB experts in RAM)
- Dedicated coding model — Hermes tool call format, opencode-compatible
- Speed: ~15-20 t/s

### configs/gemma4-e4b-q5-bartowski-opencode.env
- Model: bartowski/google_gemma-4-E4B-it-GGUF:Q5_K_M
- Context: 128K
- GPU layers: 42 (all transformer layers)
- Flash Attention: on
- Parallel slots: 1 (single-user, dedicated context)
- VRAM: ~5.7GB
- Faster alternative (~24 t/s vs ~22 t/s for Q6)

### configs/gemma4-26b-unsloth.env
- Model: unsloth/gemma-4-26B-A4B-it-GGUF:Q4_K_M (MoE)
- Context: 32K
- GPU layers: 30 (partial offload)
- VRAM: ~5GB / RAM: ~12GB

## OpenWebUI Configuration

Konfiguracja dla OpenWebUI / Open AI:

```json
{
  "llama": {
    "npm": "@ai-sdk/openai-compatible",
    "name": "llama.cpp (remote pve2)",
    "options": {
      "baseURL": "http://127.0.0.1:8089/v1",
      "toolParser": [
        { "type": "raw-function-call" },
        { "type": "json" }
      ]
    },
    "models": {
      "gemma4:e4b": {
        "name": "Gemma 4 E4B",
        "tool_call": true,
        "limit": {
          "context": 65536,
          "output": 8192
        },
        "modalities": {
          "input": ["text","image"],
          "output": ["text"]
        }
      },
      "gemma4:26b": {
        "name": "Gemma 4 26B",
        "tool_call": true,
        "limit": {
          "context": 32768,
          "output": 8192
        }
      }
    }
  }
}
```

## Sync Tool

Użyj `sync.sh` do zarządzania serwerem zdalnym:

```bash
# Sync lokalne pliki -> serwer
./sync.sh push

# Sync + restart kontenera
./sync.sh deploy

# Sync + rebuild + restart
./sync.sh rebuild

# Zatrzymaj kontener
./sync.sh stop

# Uruchom kontener
./sync.sh start

# Restart kontenera
./sync.sh restart

# Status kontenera i GPU
./sync.sh status

# Sprawdź health
./sync.sh health

# Logi kontenera
./sync.sh logs

# SSH do serwera
./sync.sh ssh

# Pokaż aktualną konfigurację
./sync.sh config
```

## Troubleshooting

### Check GPU usage
```bash
nvidia-smi --query-compute-apps=pid,name,used_memory --format=csv
```

### Check container logs
```bash
docker compose logs --tail=50
```

### Rebuild
```bash
docker compose build --no-cache
docker compose up -d
```

## API Endpoints

- **WebUI:** http://127.0.0.1:8089
- **Health:** http://127.0.0.1:8089/health
- **OpenAI API:** http://127.0.0.1:8089/v1/chat/completions

### Example API call
```bash
curl http://127.0.0.1:8089/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello!"}],
    "model": "gemma-4"
  }'
```

## Build Info

- **llama.cpp:** PR #21343 + PR #20050 patch (KV cache retry fix)
- **CUDA:** 12.4
- **Base image:** nvidia/cuda:12.4.0-devel-ubuntu22.04 (builder), ubuntu:24.04 (runtime)
