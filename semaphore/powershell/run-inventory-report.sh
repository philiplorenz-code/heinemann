#!/usr/bin/env bash
# Wrapper: ruft PowerShell-Skript via pwsh auf.
# KEIN "$@" — Semaphore übergibt extra_vars als CLI-Argumente; PowerShell
# liest seine Parameter aus Umgebungsvariablen, nicht aus CLI-Args.
set -euo pipefail
exec pwsh -NonInteractive -NoProfile -File "$(dirname "$0")/Get-InventoryReport.ps1"
