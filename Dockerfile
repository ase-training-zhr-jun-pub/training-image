# Trainings-Image für Crucible: code-server + Node.js + Docker-in-Docker
# + Claude Code + training-init (GitHub-Repo-Provisioning)
#
# Interface-Kontrakt mit Crucible (muss erhalten bleiben):
#   - code-server im PATH, lauscht via Args auf 0.0.0.0:8080
#   - User: coder, Workspace: /home/coder/workspace
#   - Args sourcen /etc/crucible/env und rufen /usr/local/bin/training-init.sh

FROM codercom/code-server:latest

USER root

# --- Basis-Tooling ---------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl wget jq python3 python3-pip openssh-client \
        ca-certificates gnupg lsb-release sudo vim less \
    && rm -rf /var/lib/apt/lists/*

# --- Node.js (LTS) ---------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- Docker-in-Docker ------------------------------------------------------
# (Pod läuft privileged; dockerd wird per docker-init.sh gestartet)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg \
       -o /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
       https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
       > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG docker coder

COPY docker-init.sh /usr/local/share/docker-init.sh
RUN chmod +x /usr/local/share/docker-init.sh \
    && echo "coder ALL=(ALL) NOPASSWD: /usr/local/share/docker-init.sh" \
       > /etc/sudoers.d/docker-init

# --- Claude Code (CLI) -----------------------------------------------------
RUN npm install -g @anthropic-ai/claude-code

# --- Trainings-Init (GitHub-Repo-Provisioning) ------------------------------
COPY training-init.sh /usr/local/bin/training-init.sh
RUN chmod +x /usr/local/bin/training-init.sh

# --- VS-Code-Extensions (aus Open VSX, vorinstalliert für alle Teilnehmer) --
USER coder
RUN code-server --install-extension esbenp.prettier-vscode \
    && code-server --install-extension DavidAnson.vscode-markdownlint \
    && code-server --install-extension bierner.markdown-mermaid \
    && code-server --install-extension pomdtr.markdown-kroki \
    && (code-server --install-extension anthropic.claude-code \
        || echo "WARN: Claude-Code-Extension nicht auf Open VSX verfügbar — CLI ist installiert")

RUN mkdir -p /home/coder/workspace
WORKDIR /home/coder/workspace
