FROM ubuntu:24.04

LABEL maintainer="shmayro"
LABEL org.opencontainers.image.source="https://github.com/shmayro/nemoclaw"
LABEL org.opencontainers.image.description="Plug-and-play NemoClaw (NVIDIA AI Agent) in Docker"

ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ──
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    supervisor \
    python3 \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# ── Docker CLI only (uses host Docker via mounted socket) ──
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
       https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 22.x ──
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── ttyd (web terminal) ──
ARG TTYD_VERSION=1.7.7
RUN curl -fsSL -o /usr/bin/ttyd \
    "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    && chmod +x /usr/bin/ttyd

# ── NemoClaw ──
# NOTE: Pin to a specific version tag when NemoClaw releases stable versions.
# For now, using latest as NemoClaw is in early preview (alpha, March 2026).
RUN curl -fsSL https://www.nvidia.com/nemoclaw.sh -o /tmp/nemoclaw-install.sh \
    && sed -i 's/^ *run_onboard$/# run_onboard (skipped - will run at container start)/' /tmp/nemoclaw-install.sh \
    && bash /tmp/nemoclaw-install.sh \
    && rm /tmp/nemoclaw-install.sh

# ── Preserve NemoClaw install for volume persistence ──
# The install script puts source in ~/.nemoclaw/source and npm-links it.
# We copy the install to /opt/nemoclaw-initial so the entrypoint can
# seed the persistent volume on first run.
RUN cp -a /root/.nemoclaw /opt/nemoclaw-initial

# ── Configuration ──
RUN mkdir -p /nemoclaw-data /var/log/supervisor

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ttyd-wrapper.sh /usr/bin/ttyd-wrapper.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh /usr/bin/ttyd-wrapper.sh

EXPOSE 7681

VOLUME ["/nemoclaw-data"]

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:7681 || exit 1

STOPSIGNAL SIGTERM

ENTRYPOINT ["/entrypoint.sh"]
