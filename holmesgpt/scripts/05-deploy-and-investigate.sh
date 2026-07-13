#!/usr/bin/env bash
set -euo pipefail

# Fehlerhaften Workload bereitstellen und Pod-Status prüfen
kubectl apply -f ../manifests/checkout-broken.yaml
kubectl get pods -n shop

# Untersuchung über die HolmesGPT-API starten
# (setzt einen laufenden port-forward auf localhost:8080 voraus, siehe 04-verify-and-test.sh)
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "ask": "Untersuche, warum der checkout-service im Namespace shop immer wieder neu startet. Nenne die Ursache und die gefundenen Belege.",
    "model": "gpt-5.6-terra"
  }'
