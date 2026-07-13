#!/usr/bin/env bash
set -euo pipefail

# Aus dem Verzeichnis code/helm ausführen, oder VALUES_FILE anpassen.
VALUES_FILE="${VALUES_FILE:-../helm/values-basic.yaml}"

helm install holmesgpt robusta/holmes \
  --namespace holmes \
  --values "${VALUES_FILE}"
