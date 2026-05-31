# Semaphore UI — Demo-Setup

Begleitmaterial zum Artikel **„Semaphore UI: Das Open-Source-Webinterface für Ansible, Terraform und OpenTofu im Praxistest"**.

Produktionsnahes Docker-Compose-Setup mit PostgreSQL, automatischer Demo-Projektkonfiguration und Beispielen für alle drei Automatisierungstools aus dem Artikel.

## Schnellstart

```bash
cp .env.example .env
docker compose up -d
bash scripts/setup-demo.sh
```

Semaphore öffnen: **http://localhost:3000** — Login: `admin` / `Admin1234!`

Das Setup-Skript legt automatisch an:
- 3 Repositories (Ansible, Terraform, PowerShell)
- 3 Variable Groups (Demo, Production, Terraform AWS)
- 6 Task Templates (Ansible ×3, Terraform ×1, PowerShell ×2)

---

## Voraussetzungen

- Docker + Docker Compose v2
- `curl`, `python3` (für das Setup-Skript)

---

## Konfiguration

```bash
cp .env.example .env
```

`.env` enthält drei Werte:

| Variable | Bedeutung |
|---|---|
| `DB_PASSWORD` | PostgreSQL-Passwort |
| `ADMIN_PASSWORD` | Semaphore Admin-Passwort (mind. 8 Zeichen, Groß/Klein/Zahl) |
| `ENCRYPTION_KEY` | 32-Byte-Base64-Key für den Key Store |

> **Wichtig:** `ENCRYPTION_KEY` nach dem ersten Start **nicht mehr ändern**.  
> Alle gespeicherten SSH-Keys und Passwörter sind damit verschlüsselt.  
> Neuen Key generieren: `head -c32 /dev/urandom | base64`

---

## Templates aus dem Artikel

### Ansible

| Template | Playbook | Scheduling |
|---|---|---|
| Hello World Demo | `playbooks/hello-world.yml` | manuell |
| Security Updates | `playbooks/security-updates.yml` | `0 2 * * *` (nightly) |
| Deploy Dry-Run | `playbooks/dry-run-check.yml` | manuell (vor Prod-Deploy) |

**Variable Groups Format** (aus dem Artikel, JSON im `env`/`extra_vars`-Schema):

```json
{
  "env": {
    "ANSIBLE_STDOUT_CALLBACK": "yaml",
    "ANSIBLE_HOST_KEY_CHECKING": "False"
  },
  "extra_vars": {
    "deploy_env": "production",
    "app_version": "2.4.1",
    "notify_slack": true
  }
}
```

Fertige Beispiele: `variable-groups/`

### Terraform

| Template | Aktion | Hinweis |
|---|---|---|
| VPC Plan (dev) | `terraform init` + `terraform plan` | Ohne AWS-Credentials: init + plan schlägt bei plan fehl, init läuft |

Für echten Apply: im Template-Dialog **Override CLI args** → `-auto-approve`

State-Backend-Optionen: `terraform/backend.tf`

### PowerShell

| Template | Skript | Plattform |
|---|---|---|
| Inventory Report | `Get-InventoryReport.ps1` | Linux/macOS/Windows |
| Windows Patching | `Invoke-WindowsPatching.ps1` | Windows produktiv, Linux Demo-Modus |

> PowerShell 7 ist im Container-Image enthalten (`semaphore-demo:local`).  
> Wrapper-Skripte (`run-*.sh`) leiten von Bash an `pwsh` weiter —  
> Semaphore's Bash-App-Typ ignoriert `#!/usr/bin/env pwsh` Shebangs.

---

## Scheduling

Cron-Expressions aus dem Artikel direkt in Templates hinterlegbar:

```
0 2 * * *     # Jede Nacht 02:00 – Security-Updates
0 9 * * 1     # Jeden Montag 09:00 – Wochenreport
*/30 * * * *  # Alle 30 Minuten – Health-Checks
0 0 1 * *     # Erster des Monats – Zertifikatsprüfung
```

`Task Templates` → Template bearbeiten → **Schedule** Tab

---

## REST API

```bash
# Login (Cookie-Session)
curl -c /tmp/sem.cookie -X POST http://localhost:3000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"auth":"admin","password":"Admin1234!"}'

# Task starten
curl -b /tmp/sem.cookie -X POST http://localhost:3000/api/project/1/tasks \
    -H "Content-Type: application/json" \
    -d '{"template_id": 1, "message": "via API"}'

# Status abfragen
curl -b /tmp/sem.cookie http://localhost:3000/api/project/1/tasks/1
```

Vollständige Beispiele inkl. GitHub Actions Integration: `scripts/api-examples.sh`  
OpenAPI-Dokumentation: http://localhost:3000/api/docs

---

## High Availability (Enterprise)

```bash
docker compose -f docker-compose.ha.yml up -d
```

Erfordert Semaphore Enterprise License. Architektur: 2× Semaphore Nodes + Redis (Koordination) + PostgreSQL + nginx Load Balancer.

---

## Artikel-Korrekturen

Folgende Punkte weichen im Artikel vom tatsächlichen Verhalten ab:

| Stelle im Artikel | Problem | Korrekt |
|---|---|---|
| docker-compose.yml | `SEMAPHORE_DB: semaphore` | `SEMAPHORE_DB_NAME: semaphore` |
| Variable Groups JSON | `env`/`extra_vars` wird von Semaphore gespeichert, aber `env`-Keys werden **nicht automatisch** als Umgebungsvariablen gesetzt — Semaphore übergibt `extra_vars` als `--extra-vars`, `env`-Keys als Shell-Env | Verhält sich wie beschrieben, aber im UI als "Variable Group" nicht als "Environment" |
| PowerShell App-Typ | Es gibt keinen nativen PowerShell App-Typ | Bash App-Typ + Wrapper-Skript das `pwsh` aufruft |

---

## Stack stoppen

```bash
# Stoppen (Daten bleiben)
docker compose down

# Stoppen + Daten löschen
docker compose down -v
```
