#!/bin/sh
# docker-init.sh — startet dockerd im (privilegierten) Container.
# Aufruf aus den Crucible-Args oder vom Teilnehmer: sudo /usr/local/share/docker-init.sh
set -e

if docker info >/dev/null 2>&1; then
  echo "[docker-init] dockerd läuft bereits."
  exit 0
fi

echo "[docker-init] Starte dockerd ..."
dockerd > /var/log/dockerd.log 2>&1 &

# Auf den Daemon warten (max. 30s)
i=0
while ! docker info >/dev/null 2>&1; do
  i=$((i+1))
  [ "$i" -ge 30 ] && { echo "[docker-init] FEHLER: dockerd nicht gestartet (siehe /var/log/dockerd.log)"; exit 1; }
  sleep 1
done
echo "[docker-init] dockerd bereit."
