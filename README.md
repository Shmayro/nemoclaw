# NemoClaw Docker

[![Docker Pulls](https://img.shields.io/docker/pulls/shmayro/nemoclaw)](https://hub.docker.com/r/shmayro/nemoclaw)
[![Docker Image Size](https://img.shields.io/docker/image-size/shmayro/nemoclaw/latest)](https://hub.docker.com/r/shmayro/nemoclaw)

Run [NVIDIA NemoClaw](https://github.com/NVIDIA/NemoClaw) with a single command. NemoClaw is an open-source AI agent framework that runs OpenClaw securely inside NVIDIA OpenShell with managed inference.

## Quick Start

```bash
docker run -d --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v nemoclaw-data:/nemoclaw-data \
  --name nemoclaw shmayro/nemoclaw
```

Open [http://localhost:7681](http://localhost:7681) in your browser, then run:

```bash
nemoclaw onboard
```

## What's Inside

| Component | Version | Purpose |
|-----------|---------|---------|
| Ubuntu | 24.04 | Base OS |
| Docker CLI | Latest | Communicates with host Docker via mounted socket |
| Node.js | 22.x LTS | NemoClaw runtime |
| NemoClaw | Latest | AI agent framework |
| ttyd | 1.7.7 | Web-based terminal |
| Supervisor | Latest | Process manager |

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `NVIDIA_API_KEY` | NVIDIA NIM API key ([free](https://build.nvidia.com)) | No* |
| `OPENROUTER_API_KEY` | OpenRouter API key ([free tier](https://openrouter.ai)) | No* |
| `OPENAI_API_KEY` | OpenAI API key | No* |
| `SKIP_ONBOARD` | Set to `1` to skip onboarding prompt | No |
| `TTYD_USER` | Username for web terminal auth | No |
| `TTYD_PASS` | Password for web terminal auth | No |

*At least one API key is needed to use NemoClaw. You can provide it at runtime or configure it during onboarding.

## Inference Providers

| Provider | Env Var | Cost | Models |
|----------|---------|------|--------|
| **NVIDIA NIM** | `NVIDIA_API_KEY` | Free | Nemotron 3 Super 120B (recommended) |
| **OpenRouter** | `OPENROUTER_API_KEY` | Free tier | Claude, GPT, Gemini, Llama, 300+ models |
| **OpenAI** | `OPENAI_API_KEY` | Paid | GPT-4, GPT-3.5 |

### Getting a Free NVIDIA API Key

1. Go to [build.nvidia.com](https://build.nvidia.com)
2. Sign in or create an account
3. Generate an API key
4. Pass it to the container: `-e NVIDIA_API_KEY=nvapi-xxx`

## Usage Examples

### With NVIDIA API (free, recommended)

```bash
docker run -d --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e NVIDIA_API_KEY=nvapi-xxx \
  -v nemoclaw-data:/nemoclaw-data \
  --name nemoclaw shmayro/nemoclaw
```

### With OpenRouter (Claude, GPT, Gemini, free models)

```bash
docker run -d --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e OPENROUTER_API_KEY=sk-or-xxx \
  -v nemoclaw-data:/nemoclaw-data \
  --name nemoclaw shmayro/nemoclaw
```

### With Web Terminal Authentication

```bash
docker run -d --network host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e NVIDIA_API_KEY=nvapi-xxx \
  -e TTYD_USER=admin -e TTYD_PASS=mysecret \
  -v nemoclaw-data:/nemoclaw-data \
  --name nemoclaw shmayro/nemoclaw
```

### Using Docker Compose

```bash
git clone https://github.com/shmayro/nemoclaw.git
cd nemoclaw
echo "NVIDIA_API_KEY=nvapi-xxx" > .env
docker compose up -d
```

## Access Methods

| Method | How | Best For |
|--------|-----|----------|
| **Web terminal** | Open `http://localhost:7681` | Everyone — zero setup |
| **Docker exec** | `docker exec -it nemoclaw bash` | Power users, scripting |

## Persistence

The `/nemoclaw-data` volume stores:
- NemoClaw configuration and API keys
- Onboarding state
- Sandbox data

Your data survives container restarts and upgrades.

## Security

- **Host networking** — The container uses `--network host` so NemoClaw's OpenShell gateway can communicate over localhost. This means ttyd is accessible on port 7681 of your host.
- **Docker socket is mounted** — The container uses the host's Docker daemon via `/var/run/docker.sock`. This gives the container access to manage Docker on the host. Only run on trusted machines.
- **Web terminal is unauthenticated by default** — Set `TTYD_USER` and `TTYD_PASS` to enable basic auth.
- **Do not expose port 7681 to the internet without authentication.**

## Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 8 GB | 16 GB |
| Disk | 25 GB | 40 GB |
| CPU | amd64 | amd64 |
| Docker | Host Docker socket | Host Docker socket |

## NemoClaw Commands

Once inside the container:

```bash
nemoclaw onboard                    # Initial setup wizard
nemoclaw my-assistant connect       # Open sandbox shell
openclaw tui                        # Interactive chat
openclaw agent --agent main -m "hello"  # CLI message
openshell term                      # Monitoring TUI
```

## Building from Source

```bash
git clone https://github.com/shmayro/nemoclaw.git
cd nemoclaw
docker build -t shmayro/nemoclaw .
```

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT
