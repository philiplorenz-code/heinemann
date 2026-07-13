#!/usr/bin/env bash
set -euo pipefail

# Installation prüfen
kubectl get pods -n holmes

# API lokal erreichbar machen (läuft im Vordergrund, mit Ctrl+C beenden)
kubectl port-forward -n holmes service/holmesgpt-holmes 8080:80 &
PORT_FORWARD_PID=$!
trap 'kill "${PORT_FORWARD_PID}"' EXIT
sleep 2

# Test der Funktionalität
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "ask": "Welche Pods im Cluster sind aktuell fehlerhaft?",
    "model": "gpt-5.6-terra"
  }'
