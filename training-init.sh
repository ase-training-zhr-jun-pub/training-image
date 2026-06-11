#!/bin/sh
# training-init.sh — richtet das Teilnehmer-Repo in der Trainings-VM ein.
#
# Erwartet (via /etc/crucible/env bzw. Trainings-Env-Vars):
#   STUDENT_HASH          - Identität des Studenten-Slots (aus /etc/crucible/env)
#   TRAINING_CONFIG_URL   - Basis-URL zur Per-Student-Config, z. B.
#                           https://api.github.com/repos/<org>/<config-repo>/contents/<training-id>
#   TRAINING_CONFIG_TOKEN - Read-only-Token für das Config-Repo
#
# Idempotent und nicht-blockierend: Fehler beenden das Skript mit !=0,
# der Aufruf in den Crucible-Args sollte mit "|| true" abgesichert sein.

set -u

log() { echo "[training-init] $*"; }

# Env-Datei defensiv nachladen, falls das Skript mal anders aufgerufen wird
[ -f /etc/crucible/env ] && . /etc/crucible/env

: "${STUDENT_HASH:?STUDENT_HASH fehlt}"
: "${TRAINING_CONFIG_URL:?TRAINING_CONFIG_URL fehlt}"
: "${TRAINING_CONFIG_TOKEN:?TRAINING_CONFIG_TOKEN fehlt}"

HOME_DIR="${HOME:-/home/coder}"
WORKSPACE="${TRAINING_WORKSPACE:-$HOME_DIR/workspace}"
SSH_DIR="$HOME_DIR/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519_training"
CONF_FILE="/tmp/student-config.json"

# 1. Per-Student-Config holen (GitHub Contents API, raw)
log "Hole Konfiguration für $STUDENT_HASH ..."
if ! curl -fsSL \
    -H "Authorization: Bearer $TRAINING_CONFIG_TOKEN" \
    -H "Accept: application/vnd.github.raw+json" \
    "$TRAINING_CONFIG_URL/$STUDENT_HASH.json" -o "$CONF_FILE"; then
  log "FEHLER: Konfiguration nicht abrufbar — Provisioning evtl. noch nicht gelaufen."
  exit 1
fi

json() { python3 -c "import json,sys;print(json.load(open('$CONF_FILE'))[sys.argv[1]])" "$1"; }

REPO_SSH_URL="$(json repo_ssh_url)"
REPO_NAME="$(json repo_name)"
GIT_USER_NAME="$(json git_user_name)"
GIT_USER_EMAIL="$(json git_user_email)"

# 2. Deploy Key einrichten
mkdir -p "$SSH_DIR" && chmod 700 "$SSH_DIR"
python3 -c "import json;print(json.load(open('$CONF_FILE'))['deploy_key_private'],end='')" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# SSH-Config nur ergänzen, wenn noch nicht vorhanden
if ! grep -qs "id_ed25519_training" "$SSH_DIR/config" 2>/dev/null; then
  cat >> "$SSH_DIR/config" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile $KEY_FILE
  IdentitiesOnly yes
EOF
  chmod 600 "$SSH_DIR/config"
fi

# GitHub-Hostkeys pinnen (kein interaktives Bestätigen beim ersten Clone)
if ! grep -qs "github.com" "$SSH_DIR/known_hosts" 2>/dev/null; then
  cat >> "$SSH_DIR/known_hosts" <<'EOF'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
EOF
  chmod 600 "$SSH_DIR/known_hosts"
fi

# 3. Repo clonen (idempotent)
TARGET="$WORKSPACE/$REPO_NAME"
if [ -d "$TARGET/.git" ]; then
  log "Repo existiert bereits — aktualisiere Remotes."
  git -C "$TARGET" fetch --all --quiet || log "WARNUNG: fetch fehlgeschlagen."
else
  log "Clone $REPO_SSH_URL nach $TARGET ..."
  if ! git clone --quiet "$REPO_SSH_URL" "$TARGET"; then
    log "FEHLER: Clone fehlgeschlagen."
    exit 1
  fi
fi

# 4. Git-Identität setzen (nur im Repo, nicht global)
git -C "$TARGET" config user.name "$GIT_USER_NAME"
git -C "$TARGET" config user.email "$GIT_USER_EMAIL"

rm -f "$CONF_FILE"
log "Fertig: $REPO_NAME ist eingerichtet."
exit 0
