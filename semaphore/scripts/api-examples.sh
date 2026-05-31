#!/usr/bin/env bash
# api-examples.sh — Semaphore REST API Beispiele
# Verwendung: bash api-examples.sh

SEMAPHORE_URL="${SEMAPHORE_URL:-http://localhost:3000}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-Admin1234!}"
PROJECT_ID="${SEMAPHORE_PROJECT_ID:-1}"
TEMPLATE_ID="${SEMAPHORE_TEMPLATE_ID:-1}"

COOKIE_JAR=$(mktemp)
trap 'rm -f "$COOKIE_JAR"' EXIT

api() { curl -sf --cookie "$COOKIE_JAR" --cookie-jar "$COOKIE_JAR" "$@"; }

# ── 1. Login ────────────────────────────────────────────────────────────────
echo "=== 1. Login ==="
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" \
    --cookie-jar "$COOKIE_JAR" \
    -X POST "$SEMAPHORE_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"auth\": \"$ADMIN_USER\", \"password\": \"$ADMIN_PASS\"}"

# ── 2. Projekte anzeigen ─────────────────────────────────────────────────────
echo -e "\n=== 2. Projekte ==="
api "$SEMAPHORE_URL/api/projects" | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    print(f\"  ID {p['id']}: {p['name']}\")
"

# ── 3. Task starten ──────────────────────────────────────────────────────────
echo -e "\n=== 3. Task starten (Template-ID: $TEMPLATE_ID) ==="
TASK_RESPONSE=$(api -X POST "$SEMAPHORE_URL/api/project/$PROJECT_ID/tasks" \
    -H "Content-Type: application/json" \
    -d "{
        \"template_id\": $TEMPLATE_ID,
        \"message\": \"Ausgelöst via API\"
    }" 2>/dev/null || echo '{"error":"Template nicht gefunden"}')
echo "$TASK_RESPONSE" | python3 -m json.tool
TASK_ID=$(echo "$TASK_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")

# ── 4. Task-Status pollen ────────────────────────────────────────────────────
if [ -n "$TASK_ID" ]; then
    echo -e "\n=== 4. Task-Status abfragen (ID: $TASK_ID) ==="
    for i in $(seq 1 15); do
        STATUS=$(api "$SEMAPHORE_URL/api/project/$PROJECT_ID/tasks/$TASK_ID" \
            | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "error")
        echo "  [$(date +%H:%M:%S)] Status: $STATUS"
        [ "$STATUS" = "success" ] || [ "$STATUS" = "error" ] && break
        sleep 3
    done

    # ── 5. Task-Log abrufen ──────────────────────────────────────────────────
    echo -e "\n=== 5. Task-Log ==="
    api "$SEMAPHORE_URL/api/project/$PROJECT_ID/tasks/$TASK_ID/output" \
        | python3 -c "
import sys, json
for line in json.load(sys.stdin):
    print(line.get('output','').rstrip())
" 2>/dev/null | head -30
fi

# ── 6. Alle Templates eines Projekts ────────────────────────────────────────
echo -e "\n=== 6. Task Templates in Projekt $PROJECT_ID ==="
api "$SEMAPHORE_URL/api/project/$PROJECT_ID/templates" \
    | python3 -c "
import sys, json
data = json.load(sys.stdin)
if not data:
    print('  (keine Templates)')
for t in data:
    print(f\"  ID {t['id']}: [{t['app']}] {t['name']}\")
" 2>/dev/null

# ── 7. GitHub Actions Integration Beispiel ─────────────────────────────────
cat << 'GHACTIONS'

=== GitHub Actions: Semaphore nach Deploy triggern (.github/workflows/deploy.yml) ===

  - name: Semaphore Deployment
    run: |
      # Login (Cookie-basiert)
      curl -c /tmp/sem-cookie -sf -X POST "$SEMAPHORE_URL/api/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"auth\": \"$SEMAPHORE_USER\", \"password\": \"$SEMAPHORE_PASS\"}"

      # Task starten
      TASK=$(curl -b /tmp/sem-cookie -sf \
        -X POST "$SEMAPHORE_URL/api/project/1/tasks" \
        -H "Content-Type: application/json" \
        -d "{\"template_id\": 1, \"message\": \"Deploy ${{ github.sha }}\"}")
      TASK_ID=$(echo "$TASK" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

      # Warte auf Abschluss (max. 10 Minuten)
      for i in $(seq 1 60); do
        STATUS=$(curl -b /tmp/sem-cookie -sf \
          "$SEMAPHORE_URL/api/project/1/tasks/$TASK_ID" \
          | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
        [ "$STATUS" = "success" ] && exit 0
        [ "$STATUS" = "error"   ] && { echo "Semaphore Task fehlgeschlagen"; exit 1; }
        sleep 10
      done
      echo "Timeout nach 10 Minuten" && exit 1
    env:
      SEMAPHORE_URL: ${{ vars.SEMAPHORE_URL }}
      SEMAPHORE_USER: ${{ secrets.SEMAPHORE_USER }}
      SEMAPHORE_PASS: ${{ secrets.SEMAPHORE_PASS }}

GHACTIONS
