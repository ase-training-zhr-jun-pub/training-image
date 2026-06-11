# training-image

Eigenes Crucible-Trainings-Image — unabhängig vom bisherigen
`gitlabregistry.innoq.com/christopher/...`-Image.

**Inhalt:** code-server (Basis: `codercom/code-server`), Node.js 22,
Docker-in-Docker, Claude Code (CLI + Extension), Prettier/Markdownlint/
Mermaid/Kroki-Extensions, `training-init.sh` für das automatische
Clonen des Teilnehmer-Repos.

## Setup (einmalig)

1. Dieses Verzeichnis als Repo `training-image` in die Trainings-Org pushen
   (die Datei `training-init.sh` aus dem Provisioning-Ordner dazulegen).
2. Der Actions-Workflow baut bei jedem Push auf `main` und veröffentlicht nach
   `ghcr.io/ase-training-zhr-jun-pub/training-image:latest`.
3. **Einmalig nach dem ersten Build:** Das Package auf public stellen, damit
   Crucible ohne Registry-Credentials pullen kann:
   Org → Packages → `training-image` → Package settings → Danger Zone →
   Change visibility → Public.

## Verwendung in Crucible

| Feld | Wert |
|---|---|
| Image Tag | `ghcr.io/ase-training-zhr-jun-pub/training-image:latest` |
| Command | `sh` / `-c` (unverändert) |
| Args | `. /etc/crucible/env && /usr/local/bin/training-init.sh \|\| true; sudo /usr/local/share/docker-init.sh \|\| true; exec code-server --auth=none --bind-addr 0.0.0.0:8080 /home/coder/workspace` |
| Privileged Mode | an (für Docker-in-Docker) |

Pinne für laufende Trainings besser den SHA-Tag statt `latest`
(`ghcr.io/...:<commit-sha>`), damit ein Rebuild mitten im Training
nicht unbemerkt das Image wechselt.

## Lokal testen

```bash
docker build -t training-image:dev .
docker run --rm -it -p 8080:8080 --privileged \
  -e STUDENT_HASH=test -e TRAINING_CONFIG_URL=... -e TRAINING_CONFIG_TOKEN=... \
  training-image:dev \
  sh -c '/usr/local/bin/training-init.sh || true; exec code-server --auth=none --bind-addr 0.0.0.0:8080 /home/coder/workspace'
```

## Hinweise

* **Claude-Code-Extension:** code-server installiert Extensions aus Open VSX,
  nicht aus dem Microsoft Marketplace. Falls `anthropic.claude-code` dort
  (noch) nicht verfügbar ist, schlägt der Build NICHT fehl — die CLI
  (`claude`) ist in jedem Fall installiert. Alternativ die VSIX-Datei ins
  Repo legen und per `code-server --install-extension ./claude-code.vsix`
  installieren.
* **Devcontainer im Template:** Die `.devcontainer/devcontainer.json` im
  Trainingsrepo bleibt für lokale Nutzung der Teilnehmer bestehen; dieses
  Image ist das Pendant für die Crucible-VMs. Wenn sich die Extension-Liste
  ändert, beide Stellen pflegen.
