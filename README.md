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
docker compose --env-file configs/gemma4-e4b-q5-bartowski-opencode.env up -d --build

# Check status
curl http://127.0.0.1:8080/health

# View logs
docker compose logs -f
```

## Configuration

```bash
# Start with a specific config
docker compose --env-file configs/gemma4-e4b-q5-bartowski-opencode.env up -d

# Or copy to .env
cp configs/gemma4-e4b-q5-bartowski-opencode.env .env
docker compose up -d
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `MODEL` | HuggingFace repo:quant | `bartowski/google_gemma-4-E4B-it-GGUF:Q5_K_M` |
| `PORT` | Server port | `8080` |
| `HOST` | Listen address | `0.0.0.0` |
| `CTX` | Context size | `131072` |
| `NGLAYERS` | GPU layers (999=all, 0=CPU) | `999` |
| `CPUMOE` | MoE experts on CPU | `exps=CPU` |
| `FLASHATTN` | Flash Attention | `on`, `off` |
| `BATCH` | Batch size | `1024` |
| `UBATCH` | Physical batch | `512` |
| `THREADS` | CPU threads | `20` |
| `THREADS_BATCH` | Batch CPU threads | `20` |
| `PARALLEL` | Parallel request slots | `1` |
| `CACHE_TYPE_K` | KV cache type (K) | `q4_0` |
| `CACHE_TYPE_V` | KV cache type (V) | `q4_0` |
| `CHAT_TEMPLATE_KWARGS` | Jinja template kwargs | `{"enable_thinking": false}` |
| `HF_TOKEN` | HuggingFace token for gated models | `hf_...` |

## Parameters Explained

| Parameter | Description |
|-----------|-------------|
| `-hf` | Load model from HuggingFace |
| `--jinja` | Enable Jinja chat template |
| `-c` | Context size (tokens) |
| `-ngl` | Layers offloaded to GPU |
| `-ot exps=CPU` | Keep MoE experts on CPU (saves VRAM) |
| `-fa` | Flash Attention |
| `-b` / `-ub` | Batch sizes |
| `-t` / `-tb` | CPU threads / batch threads |
| `--parallel` | Parallel request slots |
| `-ctk` / `-ctv` | KV cache quantization type |
| `--mlock` | Lock model in RAM |
| `--no-mmap` | Disable memory-mapped I/O |
| `--fit off` | Disable auto-fit to VRAM |
| `--hf-token` | HuggingFace token for gated models |
| `--chat-template-kwargs` | Pass JSON kwargs to Jinja chat template |

## Available Configs

### configs/gemma4-26b-unsloth.env
- Model: unsloth/gemma-4-26B-A4B-it-GGUF:Q4_K_M (MoE)
- Context: 128K
- GPU layers: all (backbone ~5-6GB on GPU, experts ~9GB RAM)
- VRAM: ~5GB + ~9GB RAM

### configs/gemma4-e4b-q5-bartowski-opencode.env
- Model: bartowski/google_gemma-4-E4B-it-GGUF:Q5_K_M
- Context: 128K (cheap — only 4 global attention layers scale with context due to SWA)
- GPU layers: 42 (all transformer layers)
- VRAM: ~5.7GB
- Speed: ~24 t/s
- Recommended for opencode

### configs/qwen3coder-30b-a3b-q6-unsloth.env
- Model: unsloth/Qwen3-Coder-30B-A3B-Instruct-GGUF:Q6_K (MoE)
- Context: 128K
- GPU layers: all (~3-4GB backbone on GPU, ~25GB experts in RAM)
- Dedicated coding model — Hermes tool call format, opencode-compatible
- Thinking mode disabled for faster responses
- Speed: ~15-20 t/s

### configs/qwen35-35b-a3b-q4-unsloth.env
- Model: unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q4_K_XL (MoE + SSM hybrid)
- Context: 131K (native 262K; cheap — only 10 attention layers have KV cache)
- GPU layers: all (~2GB backbone on GPU, ~19GB experts in RAM)
- Multimodal: vision encoder included
- Speed: ~15-20 t/s

## OpenWebUI Configuration

```json
{
  "llama": {
    "npm": "@ai-sdk/openai-compatible",
    "name": "llama.cpp",
    "options": {
      "baseURL": "http://127.0.0.1:8080/v1",
      "toolParser": [
        { "type": "hermes" },
        { "type": "raw-function-call" },
        { "type": "json" }
      ]
    },
    "models": {
      "gemma4:26b": {
        "name": "Gemma 4 26B",
        "tool_call": true,
        "limit": { "context": 131072, "output": 8192 },
        "modalities": { "input": ["text", "image"], "output": ["text"] }
      },
      "gemma4:e4b-q5": {
        "name": "Gemma 4 E4B (Q5_K_M)",
        "tool_call": true,
        "limit": { "context": 131072, "output": 8192 },
        "modalities": { "input": ["text", "image"], "output": ["text"] }
      },
      "qwen3coder:30b": {
        "name": "Qwen3-Coder 30B-A3B",
        "tool_call": true,
        "limit": { "context": 131072, "output": 8192 }
      },
      "qwen35:35b": {
        "name": "Qwen3.5 35B-A3B",
        "tool_call": true,
        "limit": { "context": 131072, "output": 8192 },
        "modalities": { "input": ["text", "image"], "output": ["text"] }
      }
    }
  }
}
```

## Sync Tool

Use `sync.sh` to manage the remote server:

```bash
./sync.sh push      # Sync local files to server
./sync.sh deploy    # Sync + restart container
./sync.sh rebuild   # Sync + full rebuild + restart
./sync.sh stop      # Stop container
./sync.sh start     # Start container
./sync.sh restart   # Restart container
./sync.sh status    # Container and GPU status
./sync.sh health    # Health check
./sync.sh logs      # Container logs
./sync.sh ssh       # SSH to server
./sync.sh config    # Show current config
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

- **WebUI:** http://127.0.0.1:8080
- **Health:** http://127.0.0.1:8080/health
- **OpenAI API:** http://127.0.0.1:8080/v1/chat/completions

### Example API call
```bash
curl http://127.0.0.1:8080/v1/chat/completions \
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
