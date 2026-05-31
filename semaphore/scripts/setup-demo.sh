#!/usr/bin/env bash
# setup-demo.sh — Richtet das Demo-Projekt in Semaphore via REST API ein.
# Je ein Template für Ansible, Terraform und PowerShell.
#
# Verwendung A – lokal (Docker Compose mit Volume-Mounts):
#   bash scripts/setup-demo.sh
#
# Verwendung B – GitHub (ein Repo, alle Tools drin):
#   GITHUB_REPO=https://github.com/philiplorenz-code/heinemann \
#   REPO_BRANCH=main \
#   bash scripts/setup-demo.sh
#
# Verwendung B via curl (kein lokaler Clone nötig):
#   GITHUB_REPO=https://github.com/philiplorenz-code/heinemann \
#   bash <(curl -fsSL https://raw.githubusercontent.com/philiplorenz-code/heinemann/main/semaphore/scripts/setup-demo.sh)
set -euo pipefail

SEMAPHORE_URL="${SEMAPHORE_URL:-http://localhost:3000}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-Admin1234!}"

# Wenn GITHUB_REPO gesetzt → alle 3 Tools aus demselben Repo, mit Pfad-Prefix
GITHUB_REPO="${GITHUB_REPO:-}"
REPO_BRANCH="${REPO_BRANCH:-main}"

if [ -n "$GITHUB_REPO" ]; then
    # GitHub-Modus: ein Repo, Tools in Unterverzeichnissen
    ANSIBLE_REPO="$GITHUB_REPO"
    TERRAFORM_REPO="$GITHUB_REPO"
    POWERSHELL_REPO="$GITHUB_REPO"
    ANSIBLE_PLAYBOOK="semaphore/ansible/playbooks/hello-world.yml"
    TERRAFORM_DIR="semaphore/terraform"
    POWERSHELL_PLAYBOOK="semaphore/powershell/run-inventory-report.sh"
else
    # Lokaler Modus: separate Volume-Mounts per Tool
    ANSIBLE_REPO="${ANSIBLE_REPO:-file:///opt/ansible}"
    TERRAFORM_REPO="${TERRAFORM_REPO:-file:///opt/terraform}"
    POWERSHELL_REPO="${POWERSHELL_REPO:-file:///opt/powershell}"
    ANSIBLE_PLAYBOOK="playbooks/hello-world.yml"
    TERRAFORM_DIR=""
    POWERSHELL_PLAYBOOK="run-inventory-report.sh"
fi

COOKIE_JAR=$(mktemp)
trap 'rm -f "$COOKIE_JAR"' EXIT

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
log()     { echo -e "${GREEN}[OK]${NC}    $*"; }
info()    { echo -e "${CYAN}[...]${NC}   $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
section() { echo -e "\n${CYAN}══ $* ══${NC}"; }
api()     { curl -sf --cookie "$COOKIE_JAR" --cookie-jar "$COOKIE_JAR" "$@"; }
json_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['id'])"; }

# ── Lokale Git-Repos initialisieren (nur bei file://-URLs nötig) ──────────────
init_local_repos() {
    [ -n "$GITHUB_REPO" ] && return  # GitHub-Modus: nichts zu tun

    local base
    base="$(cd "$(dirname "$0")/.." && pwd)"

    for dir in ansible terraform powershell; do
        local path="$base/$dir"
        if [ ! -d "$path/.git" ]; then
            info "git init: $dir"
            git -C "$path" init -q -b main
            git -C "$path" config user.email "semaphore@demo.local"
            git -C "$path" config user.name "Semaphore Demo"
            git -C "$path" add .
            git -C "$path" commit -q -m "Initial commit"
            log "Git-Repo bereit: $dir"
        else
            git -C "$path" add . && git -C "$path" commit -q -m "Update" 2>/dev/null || true
            log "Git-Repo aktuell: $dir"
        fi
    done
}

wait_for_semaphore() {
    info "Warte auf Semaphore ($SEMAPHORE_URL) ..."
    for _ in $(seq 1 30); do
        curl -sf "$SEMAPHORE_URL/api/ping" > /dev/null 2>&1 && log "Semaphore bereit." && return
        sleep 2
    done
    err "Semaphore nicht erreichbar nach 60s"
}

login() {
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" --cookie-jar "$COOKIE_JAR" \
        -X POST "$SEMAPHORE_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"auth\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}")
    [ "$status" = "204" ] || err "Login fehlgeschlagen (HTTP $status)"
    log "Login erfolgreich."
}

json_id() { python3 -c "import sys,json; print(json.load(sys.stdin)['id'])"; }

create_project() {
    api -X POST "$SEMAPHORE_URL/api/projects" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$1\",\"alert\":false,\"alert_chat\":\"\"}" | json_id
}

get_none_key_id() {
    api "$SEMAPHORE_URL/api/project/$1/keys" | python3 -c "
import sys,json; keys=json.load(sys.stdin)
print(next(k['id'] for k in keys if k['type']=='none'))"
}

create_repository() {
    local pid="$1" name="$2" url="$3" key_id="$4"
    api -X POST "$SEMAPHORE_URL/api/project/$pid/repositories" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$name\",\"project_id\":$pid,\"git_url\":\"$url\",\"git_branch\":\"$REPO_BRANCH\",\"ssh_key_id\":$key_id}" \
    | json_id
}

create_inventory() {
    local pid="$1" key_id="$2" name="$3" content="$4"
    api -X POST "$SEMAPHORE_URL/api/project/$pid/inventory" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"$name\",\"project_id\":$pid,\"inventory\":\"$content\",\"ssh_key_id\":$key_id,\"type\":\"static\"}" \
    | json_id
}

create_environment() {
    local pid="$1" name="$2" json="$3"
    local payload
    payload=$(python3 -c "import json,sys; print(json.dumps({'name':sys.argv[1],'project_id':int(sys.argv[2]),'json':sys.argv[3]}))" \
        "$name" "$pid" "$json")
    api -X POST "$SEMAPHORE_URL/api/project/$pid/environment" \
        -H "Content-Type: application/json" -d "$payload" | json_id
}

create_template() {
    local pid="$1" name="$2" app="$3" playbook="$4" repo_id="$5" inv_id="$6" env_id="$7" desc="${8:-}"
    api -X POST "$SEMAPHORE_URL/api/project/$pid/templates" \
        -H "Content-Type: application/json" \
        -d "{\"project_id\":$pid,\"inventory_id\":$inv_id,\"repository_id\":$repo_id,
             \"environment_id\":$env_id,\"name\":\"$name\",\"playbook\":\"$playbook\",
             \"description\":\"$desc\",\"app\":\"$app\",
             \"allow_override_args_in_task\":true,\"suppress_success_alerts\":false}" \
    | json_id
}

# ── Hauptprogramm ─────────────────────────────────────────────────────────────

section "Repos vorbereiten"
init_local_repos

section "Semaphore"
wait_for_semaphore
login

section "Projekt"
PID=$(create_project "Semaphore Demo")
KEY=$(get_none_key_id "$PID")
log "Projekt-ID: $PID | None-Key: $KEY"

section "Repositories"
if [ -n "$GITHUB_REPO" ]; then
    # GitHub-Modus: ein Repo für alle Tools
    REPO_ALL=$(create_repository "$PID" "heinemann (GitHub)" "$GITHUB_REPO" "$KEY")
    REPO_A=$REPO_ALL; REPO_T=$REPO_ALL; REPO_P=$REPO_ALL
    log "GitHub Repo: $REPO_ALL ($GITHUB_REPO @ $REPO_BRANCH)"
else
    REPO_A=$(create_repository "$PID" "Ansible"    "$ANSIBLE_REPO"    "$KEY"); log "Ansible:    $REPO_A"
    REPO_T=$(create_repository "$PID" "Terraform"  "$TERRAFORM_REPO"  "$KEY"); log "Terraform:  $REPO_T"
    REPO_P=$(create_repository "$PID" "PowerShell" "$POWERSHELL_REPO" "$KEY"); log "PowerShell: $REPO_P"
fi

section "Inventories"
INV_LOCAL=$(create_inventory "$PID" "$KEY" "Localhost" \
    "localhost ansible_connection=local ansible_python_interpreter=/usr/bin/python3")
log "Localhost: $INV_LOCAL"

INV_TF=$(create_inventory "$PID" "$KEY" "Terraform Workspace: dev" "dev")
log "Terraform (dev): $INV_TF"

section "Variable Groups"
ENV_DEMO=$(create_environment "$PID" "Demo" \
    '{"env":{"ANSIBLE_STDOUT_CALLBACK":"yaml","ANSIBLE_HOST_KEY_CHECKING":"False"},"extra_vars":{"demo_message":"Hello from Semaphore UI!","app_version":"1.0.0","deploy_env":"demo"}}')
log "Demo: $ENV_DEMO"

ENV_TF=$(create_environment "$PID" "Terraform" '{}')
log "Terraform: $ENV_TF"

section "Task Templates"
TMPL_A=$(create_template "$PID" "Hello World (Ansible)" "ansible" \
    "$ANSIBLE_PLAYBOOK" "$REPO_A" "$INV_LOCAL" "$ENV_DEMO" \
    "Ansible Demo – läuft lokal, kein SSH nötig")
log "Ansible Template: $TMPL_A"

TMPL_T=$(create_template "$PID" "Server Provisioning (Terraform)" "terraform" \
    "$TERRAFORM_DIR" "$REPO_T" "$INV_TF" "$ENV_TF" \
    "Terraform Demo – random+local Provider, kein Cloud-Account nötig")
log "Terraform Template: $TMPL_T"

TMPL_P=$(create_template "$PID" "Inventory Report (PowerShell)" "bash" \
    "$POWERSHELL_PLAYBOOK" "$REPO_P" "$INV_LOCAL" "$ENV_DEMO" \
    "PowerShell 7 Demo – System-Info cross-platform")
log "PowerShell Template: $TMPL_P"

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
log "Setup abgeschlossen!"
echo ""
echo -e "  ${CYAN}$SEMAPHORE_URL${NC}  →  $ADMIN_USER / $ADMIN_PASS"
if [ -n "$GITHUB_REPO" ]; then
echo -e "  Quelle: ${CYAN}$GITHUB_REPO${NC} @ $REPO_BRANCH"
fi
echo ""
echo -e "  [Ansible]    Hello World             → jetzt ausführbar"
echo -e "  [Terraform]  Server Provisioning     → plan + apply (random+local)"
echo -e "  [PowerShell] Inventory Report        → System-Info via pwsh"
echo -e "${GREEN}══════════════════════════════════════════════════${NC}"
