#!/usr/bin/env bash
set -euo pipefail

# Nutzung: OPENAI_API_KEY=<API-KEY> ./02-create-namespace-and-secret.sh
: "${OPENAI_API_KEY:?OPENAI_API_KEY muss gesetzt sein}"

kubectl create namespace holmes

kubectl create secret generic holmes-secrets \
  --from-literal=OPENAI_API_KEY="${OPENAI_API_KEY}" \
  --namespace holmes
