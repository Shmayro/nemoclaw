#!/bin/bash
set -e

NEMOCLAW_DATA="/nemoclaw-data"
NEMOCLAW_CONFIG_DIR="${NEMOCLAW_DATA}/.nemoclaw"
ONBOARDED_FLAG="${NEMOCLAW_DATA}/.onboarded"

# ── Ensure persistent data directory structure ──
mkdir -p "${NEMOCLAW_CONFIG_DIR}"

# Seed volume with NemoClaw install on first run
if [ ! -d "${NEMOCLAW_CONFIG_DIR}/source" ] && [ -d /opt/nemoclaw-initial/source ]; then
  echo "First run: seeding NemoClaw installation into persistent volume..."
  cp -a /opt/nemoclaw-initial/* "${NEMOCLAW_CONFIG_DIR}/"
fi

# Symlink ~/.nemoclaw to persistent volume
if [ ! -L "$HOME/.nemoclaw" ] || [ "$(readlink "$HOME/.nemoclaw")" != "${NEMOCLAW_CONFIG_DIR}" ]; then
  rm -rf "$HOME/.nemoclaw"
  ln -s "${NEMOCLAW_CONFIG_DIR}" "$HOME/.nemoclaw"
fi

# Fix npm global link to point to volume
if [ -d "${NEMOCLAW_CONFIG_DIR}/source" ]; then
  ln -sfn "${NEMOCLAW_CONFIG_DIR}/source" /usr/lib/node_modules/nemoclaw
fi

# ── Write ttyd wrapper script (handles optional auth) ──
cat > /usr/bin/ttyd-wrapper.sh << 'WRAPPER'
#!/bin/bash
TTYD_ARGS=("-p" "7681")
if [ -n "${TTYD_USER}" ] && [ -n "${TTYD_PASS}" ]; then
  TTYD_ARGS+=("-c" "${TTYD_USER}:${TTYD_PASS}")
fi
exec /usr/bin/ttyd "${TTYD_ARGS[@]}" /bin/bash -l
WRAPPER
chmod +x /usr/bin/ttyd-wrapper.sh

# ── Start supervisord (manages dockerd + ttyd) ──
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &
SUPERVISOR_PID=$!

# ── Graceful shutdown: forward SIGTERM to supervisord ──
trap "kill $SUPERVISOR_PID; wait $SUPERVISOR_PID; exit 0" SIGTERM SIGINT

# ── Wait for Docker daemon ──
echo "Waiting for Docker daemon to start..."
TIMEOUT=30
ELAPSED=0
while [ ! -S /var/run/docker.sock ] && [ $ELAPSED -lt $TIMEOUT ]; do
  sleep 1
  ELAPSED=$((ELAPSED + 1))
done

if [ ! -S /var/run/docker.sock ]; then
  echo "============================================"
  echo "ERROR: Docker daemon failed to start."
  echo "Did you forget --privileged?"
  echo ""
  echo "Usage:"
  echo "  docker run -d --privileged -p 7681:7681 shmayro/nemoclaw"
  echo "============================================"
  exit 1
fi
echo "Docker daemon is ready."

# ── Write API keys to NemoClaw config if provided ──
if [ -n "${NVIDIA_API_KEY}" ] || [ -n "${OPENROUTER_API_KEY}" ] || [ -n "${OPENAI_API_KEY}" ]; then
  echo "API key(s) detected, writing to NemoClaw config..."
  mkdir -p "${NEMOCLAW_CONFIG_DIR}"
  CONFIG_FILE="${NEMOCLAW_CONFIG_DIR}/config.json"
  # Build config JSON with provided keys
  # NOTE: This key structure is assumed. Verify against NemoClaw's actual
  # config schema at runtime. The onboarding wizard may overwrite this file.
  python3 -c "
import json, os
config = {}
config_path = '${CONFIG_FILE}'
if os.path.exists(config_path):
    try:
        config = json.load(open(config_path))
    except:
        config = {}
keys = {}
if os.environ.get('NVIDIA_API_KEY'):
    keys['nvidia'] = os.environ['NVIDIA_API_KEY']
if os.environ.get('OPENROUTER_API_KEY'):
    keys['openrouter'] = os.environ['OPENROUTER_API_KEY']
if os.environ.get('OPENAI_API_KEY'):
    keys['openai'] = os.environ['OPENAI_API_KEY']
config['api_keys'] = {**config.get('api_keys', {}), **keys}
json.dump(config, open(config_path, 'w'), indent=2)
"
  echo "API keys configured."
else
  echo "============================================"
  echo "No API key provided."
  echo ""
  echo "To use NemoClaw, you need an inference API key."
  echo "Options:"
  echo "  1. NVIDIA API (free): Get a key at https://build.nvidia.com"
  echo "     docker run -e NVIDIA_API_KEY=nvapi-xxx ..."
  echo ""
  echo "  2. OpenRouter (free tier): https://openrouter.ai"
  echo "     docker run -e OPENROUTER_API_KEY=sk-or-xxx ..."
  echo ""
  echo "  3. OpenAI: https://platform.openai.com"
  echo "     docker run -e OPENAI_API_KEY=sk-xxx ..."
  echo ""
  echo "You can also configure keys during onboarding."
  echo "============================================"
fi

# ── Onboarding status ──
if [ -f "${ONBOARDED_FLAG}" ]; then
  echo "============================================"
  echo "NemoClaw is ready!"
  echo ""
  echo "Connect via browser: http://localhost:7681"
  echo "Or: docker exec -it nemoclaw bash"
  echo ""
  echo "Commands:"
  echo "  nemoclaw my-assistant connect  # Open sandbox"
  echo "  openclaw tui                   # Chat interface"
  echo "============================================"
elif [ "${SKIP_ONBOARD}" = "1" ]; then
  echo "============================================"
  echo "Onboarding skipped (SKIP_ONBOARD=1)."
  echo ""
  echo "Run 'nemoclaw onboard' when ready."
  echo "============================================"
else
  echo "============================================"
  echo "NemoClaw needs initial setup."
  echo ""
  echo "Connect to http://localhost:7681 and run:"
  echo "  nemoclaw onboard"
  echo ""
  echo "This will create a sandbox and configure inference."
  echo "============================================"
fi

# ── Keep container alive ──
wait $SUPERVISOR_PID
